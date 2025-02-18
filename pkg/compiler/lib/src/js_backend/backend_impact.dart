// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.10

library dart2js.js_helpers.impact;

import '../common/elements.dart' show CommonElements, ElementEnvironment;
import '../common/names.dart';
import '../elements/types.dart' show InterfaceType;
import '../elements/entities.dart';
import '../universe/selector.dart';
import '../universe/world_impact.dart'
    show WorldImpact, WorldImpactBuilder, WorldImpactBuilderImpl;
import '../universe/use.dart';
import '../util/enumset.dart';
import '../options.dart';

/// Backend specific features required by a backend impact.
enum BackendFeature {
  needToInitializeIsolateAffinityTag,
  needToInitializeDispatchProperty,
}

/// A set of JavaScript backend dependencies.
class BackendImpact {
  final List<FunctionEntity> staticUses;
  final List<FunctionEntity> globalUses;
  final List<Selector> dynamicUses;
  final List<InterfaceType> instantiatedTypes;
  final List<ClassEntity> instantiatedClasses;
  final List<ClassEntity> globalClasses;
  final List<BackendImpact> otherImpacts;
  final EnumSet<BackendFeature> _features;

  const BackendImpact(
      {this.staticUses = const [],
      this.globalUses = const [],
      this.dynamicUses = const [],
      this.instantiatedTypes = const [],
      this.instantiatedClasses = const [],
      this.globalClasses = const [],
      this.otherImpacts = const [],
      EnumSet<BackendFeature> features = const EnumSet.fixed(0)})
      : this._features = features;

  Iterable<BackendFeature> get features =>
      _features.iterable(BackendFeature.values);

  WorldImpact createImpact(ElementEnvironment elementEnvironment) {
    WorldImpactBuilderImpl impactBuilder = WorldImpactBuilderImpl();
    registerImpact(impactBuilder, elementEnvironment);
    return impactBuilder;
  }

  /// Register this backend impact to the [worldImpactBuilder].
  void registerImpact(WorldImpactBuilder worldImpactBuilder,
      ElementEnvironment elementEnvironment) {
    for (FunctionEntity staticUse in staticUses) {
      assert(staticUse != null);
      worldImpactBuilder.registerStaticUse(StaticUse.implicitInvoke(staticUse));
    }
    for (FunctionEntity staticUse in globalUses) {
      assert(staticUse != null);
      worldImpactBuilder.registerStaticUse(StaticUse.implicitInvoke(staticUse));
    }
    for (Selector selector in dynamicUses) {
      assert(selector != null);
      worldImpactBuilder
          .registerDynamicUse(DynamicUse(selector, null, const []));
    }
    for (InterfaceType instantiatedType in instantiatedTypes) {
      worldImpactBuilder
          .registerTypeUse(TypeUse.instantiation(instantiatedType));
    }
    for (ClassEntity cls in instantiatedClasses) {
      worldImpactBuilder.registerTypeUse(
          TypeUse.instantiation(elementEnvironment.getRawType(cls)));
    }
    for (ClassEntity cls in globalClasses) {
      worldImpactBuilder.registerTypeUse(
          TypeUse.instantiation(elementEnvironment.getRawType(cls)));
    }
    for (BackendImpact otherImpact in otherImpacts) {
      otherImpact.registerImpact(worldImpactBuilder, elementEnvironment);
    }
  }
}

/// The JavaScript backend dependencies for various features.
class BackendImpacts {
  final CommonElements _commonElements;
  final CompilerOptions _options;

  BackendImpacts(this._commonElements, this._options);

  BackendImpact _getRuntimeTypeArgument;

  BackendImpact get getRuntimeTypeArgument {
    return _getRuntimeTypeArgument ??=
        BackendImpact(globalUses: [], otherImpacts: [
      newRtiImpact,
    ]);
  }

  BackendImpact _computeSignature;

  BackendImpact get computeSignature {
    return _computeSignature ??= BackendImpact(globalUses: [
      _commonElements.setArrayType,
    ], otherImpacts: [
      listValues
    ]);
  }

  BackendImpact _mainWithArguments;

  BackendImpact get mainWithArguments {
    return _mainWithArguments ??= BackendImpact(
      globalUses: [_commonElements.convertMainArgumentList],
      instantiatedClasses: [
        _commonElements.jsArrayClass,
        _commonElements.jsStringClass
      ],
    );
  }

  BackendImpact _asyncBody;

  BackendImpact get asyncBody => _asyncBody ??= BackendImpact(staticUses: [
        _commonElements.asyncHelperAwait,
        _commonElements.asyncHelperReturn,
        _commonElements.asyncHelperRethrow,
        _commonElements.streamIteratorConstructor,
        _commonElements.wrapBody,
        _commonElements.asyncHelperStartSync
      ]);

  BackendImpact _syncStarBody;

  BackendImpact get syncStarBody {
    return _syncStarBody ??= BackendImpact(staticUses: [
      _commonElements.endOfIteration,
      _commonElements.yieldStar,
      _commonElements.syncStarUncaughtError,
    ]);
  }

  BackendImpact _asyncStarBody;

  BackendImpact get asyncStarBody {
    return _asyncStarBody ??= BackendImpact(staticUses: [
      _commonElements.asyncStarHelper,
      _commonElements.streamOfController,
      _commonElements.yieldSingle,
      _commonElements.yieldStar,
      _commonElements.streamIteratorConstructor,
      _commonElements.wrapBody,
    ]);
  }

  BackendImpact _typeVariableBoundCheck;

  BackendImpact get typeVariableBoundCheck {
    return _typeVariableBoundCheck ??= BackendImpact(staticUses: [
      _commonElements.checkTypeBound,
    ]);
  }

  BackendImpact _asCheck;

  BackendImpact get asCheck {
    return _asCheck ??= BackendImpact(staticUses: [], otherImpacts: [
      newRtiImpact,
    ]);
  }

  BackendImpact _stringValues;

  BackendImpact get stringValues {
    return _stringValues ??=
        BackendImpact(instantiatedClasses: [_commonElements.jsStringClass]);
  }

  BackendImpact _numValues;

  BackendImpact get numValues {
    return _numValues ??= BackendImpact(instantiatedClasses: [
      _commonElements.jsIntClass,
      _commonElements.jsPositiveIntClass,
      _commonElements.jsUInt32Class,
      _commonElements.jsUInt31Class,
      _commonElements.jsNumberClass,
      _commonElements.jsNumNotIntClass,
    ]);
  }

  BackendImpact get intValues => numValues;

  BackendImpact get doubleValues => numValues;

  BackendImpact _boolValues;

  BackendImpact get boolValues {
    return _boolValues ??=
        BackendImpact(instantiatedClasses: [_commonElements.jsBoolClass]);
  }

  BackendImpact _nullValue;

  BackendImpact get nullValue {
    return _nullValue ??=
        BackendImpact(instantiatedClasses: [_commonElements.jsNullClass]);
  }

  BackendImpact _listValues;

  BackendImpact get listValues {
    return _listValues ??= BackendImpact(globalClasses: [
      _commonElements.jsArrayClass,
      _commonElements.jsMutableArrayClass,
      _commonElements.jsFixedArrayClass,
      _commonElements.jsExtendableArrayClass,
      _commonElements.jsUnmodifiableArrayClass
    ]);
  }

  BackendImpact _throwUnsupportedError;

  BackendImpact get throwUnsupportedError {
    return _throwUnsupportedError ??= BackendImpact(staticUses: [
      _commonElements.throwUnsupportedError
    ], otherImpacts: [
      // Also register the types of the arguments passed to this method.
      stringValues
    ]);
  }

  BackendImpact _superNoSuchMethod;

  BackendImpact get superNoSuchMethod {
    return _superNoSuchMethod ??= BackendImpact(staticUses: [
      _commonElements.createInvocationMirror,
      _commonElements.objectNoSuchMethod
    ], otherImpacts: [
      _needsInt('Needed to encode the invocation kind of super.noSuchMethod.'),
      _needsList('Needed to encode the arguments of super.noSuchMethod.'),
      _needsString('Needed to encode the name of super.noSuchMethod.')
    ]);
  }

  BackendImpact _constantMapLiteral;

  BackendImpact get constantMapLiteral {
    return _constantMapLiteral ??= BackendImpact(instantiatedClasses: [
      _commonElements.constantMapClass,
      _commonElements.constantStringMapClass,
      _commonElements.generalConstantMapClass,
    ]);
  }

  BackendImpact _constantSetLiteral;

  BackendImpact get constantSetLiteral =>
      _constantSetLiteral ??= BackendImpact(instantiatedClasses: [
        _commonElements.constSetLiteralClass,
      ], otherImpacts: [
        constantMapLiteral
      ]);

  BackendImpact _constSymbol;

  BackendImpact get constSymbol {
    return _constSymbol ??= BackendImpact(
        instantiatedClasses: [_commonElements.symbolImplementationClass],
        staticUses: [_commonElements.symbolConstructorTarget]);
  }

  /// Helper for registering that `int` is needed.
  BackendImpact _needsInt(String reason) {
    // TODO(johnniwinther): Register [reason] for use in dump-info.
    return intValues;
  }

  /// Helper for registering that `List` is needed.
  BackendImpact _needsList(String reason) {
    // TODO(johnniwinther): Register [reason] for use in dump-info.
    return listValues;
  }

  /// Helper for registering that `String` is needed.
  BackendImpact _needsString(String reason) {
    // TODO(johnniwinther): Register [reason] for use in dump-info.
    return stringValues;
  }

  BackendImpact _assertWithoutMessage;

  BackendImpact get assertWithoutMessage {
    return _assertWithoutMessage ??=
        BackendImpact(staticUses: [_commonElements.assertHelper]);
  }

  BackendImpact _assertWithMessage;

  BackendImpact get assertWithMessage {
    return _assertWithMessage ??= BackendImpact(
        staticUses: [_commonElements.assertTest, _commonElements.assertThrow]);
  }

  BackendImpact _asyncForIn;

  BackendImpact get asyncForIn {
    return _asyncForIn ??=
        BackendImpact(staticUses: [_commonElements.streamIteratorConstructor]);
  }

  BackendImpact _stringInterpolation;

  BackendImpact get stringInterpolation {
    return _stringInterpolation ??= BackendImpact(
        dynamicUses: [Selectors.toString_],
        staticUses: [_commonElements.stringInterpolationHelper],
        otherImpacts: [_needsString('Strings are created.')]);
  }

  BackendImpact _stringJuxtaposition;

  BackendImpact get stringJuxtaposition {
    return _stringJuxtaposition ??= _needsString('String.concat is used.');
  }

  BackendImpact get nullLiteral => nullValue;

  BackendImpact get boolLiteral => boolValues;

  BackendImpact get intLiteral => intValues;

  BackendImpact get doubleLiteral => doubleValues;

  BackendImpact get stringLiteral => stringValues;

  BackendImpact _catchStatement;

  BackendImpact get catchStatement {
    return _catchStatement ??= BackendImpact(staticUses: [
      _commonElements.exceptionUnwrapper
    ], instantiatedClasses: [
      _commonElements.jsPlainJavaScriptObjectClass,
      _commonElements.jsUnknownJavaScriptObjectClass
    ]);
  }

  BackendImpact _throwExpression;

  BackendImpact get throwExpression {
    return _throwExpression ??= BackendImpact(
        // We don't know ahead of time whether we will need the throw in a
        // statement context or an expression context, so we register both
        // here, even though we may not need the throwExpression helper.
        staticUses: [
          _commonElements.wrapExceptionHelper,
          _commonElements.throwExpressionHelper
        ]);
  }

  BackendImpact _lazyField;

  BackendImpact get lazyField {
    return _lazyField ??= BackendImpact(staticUses: [
      _commonElements.cyclicThrowHelper,
      _commonElements.throwLateFieldADI,
    ]);
  }

  BackendImpact _typeLiteral;

  BackendImpact get typeLiteral {
    return _typeLiteral ??= BackendImpact(instantiatedClasses: [
      _commonElements.typeLiteralClass
    ], staticUses: [
      _commonElements.createRuntimeType,
      _commonElements.typeLiteralMaker,
    ]);
  }

  BackendImpact _stackTraceInCatch;

  BackendImpact get stackTraceInCatch {
    return _stackTraceInCatch ??= BackendImpact(
        instantiatedClasses: [_commonElements.stackTraceHelperClass],
        staticUses: [_commonElements.traceFromException]);
  }

  BackendImpact _syncForIn;

  BackendImpact get syncForIn {
    return _syncForIn ??= BackendImpact(
        // The SSA builder recognizes certain for-in loops and can generate
        // calls to throwConcurrentModificationError.
        staticUses: [_commonElements.checkConcurrentModificationError]);
  }

  BackendImpact _typeVariableExpression;

  BackendImpact get typeVariableExpression {
    return _typeVariableExpression ??= BackendImpact(staticUses: [
      _commonElements.setArrayType,
      _commonElements.createRuntimeType
    ], otherImpacts: [
      listValues,
      getRuntimeTypeArgument,
      _needsInt('Needed for accessing a type variable literal on this.')
    ]);
  }

  BackendImpact _typeCheck;

  BackendImpact get typeCheck {
    return _typeCheck ??=
        BackendImpact(otherImpacts: [boolValues, newRtiImpact]);
  }

  BackendImpact _genericTypeCheck;

  BackendImpact get genericTypeCheck {
    return _genericTypeCheck ??= BackendImpact(staticUses: [
      // TODO(johnniwinther): Investigate why this is needed.
      _commonElements.setArrayType,
    ], otherImpacts: [
      listValues,
      getRuntimeTypeArgument,
      newRtiImpact,
    ]);
  }

  BackendImpact _genericIsCheck;

  BackendImpact get genericIsCheck {
    return _genericIsCheck ??=
        BackendImpact(otherImpacts: [intValues, newRtiImpact]);
  }

  BackendImpact _typeVariableTypeCheck;

  BackendImpact get typeVariableTypeCheck {
    return _typeVariableTypeCheck ??=
        BackendImpact(staticUses: [], otherImpacts: [newRtiImpact]);
  }

  BackendImpact _functionTypeCheck;

  BackendImpact get functionTypeCheck {
    return _functionTypeCheck ??= BackendImpact(
        staticUses: [/*helpers.functionTypeTestMetaHelper*/],
        otherImpacts: [newRtiImpact]);
  }

  BackendImpact _futureOrTypeCheck;

  BackendImpact get futureOrTypeCheck {
    return _futureOrTypeCheck ??=
        BackendImpact(staticUses: [], otherImpacts: [newRtiImpact]);
  }

  BackendImpact _nativeTypeCheck;

  BackendImpact get nativeTypeCheck {
    return _nativeTypeCheck ??= BackendImpact(staticUses: [
      // We will need to add the "$is" and "$as" properties on the
      // JavaScript object prototype, so we make sure
      // [:defineProperty:] is compiled.
      _commonElements.defineProperty
    ], otherImpacts: [
      newRtiImpact
    ]);
  }

  BackendImpact _closure;

  BackendImpact get closure {
    return _closure ??=
        BackendImpact(instantiatedClasses: [_commonElements.functionClass]);
  }

  BackendImpact _interceptorUse;

  BackendImpact get interceptorUse {
    return _interceptorUse ??= BackendImpact(
        staticUses: [
          _commonElements.getNativeInterceptorMethod
        ],
        instantiatedClasses: [
          _commonElements.jsJavaScriptObjectClass,
          _commonElements.jsLegacyJavaScriptObjectClass,
          _commonElements.jsPlainJavaScriptObjectClass,
          _commonElements.jsJavaScriptFunctionClass
        ],
        features: EnumSet<BackendFeature>.fromValues([
          BackendFeature.needToInitializeDispatchProperty,
          BackendFeature.needToInitializeIsolateAffinityTag
        ], fixed: true));
  }

  BackendImpact _allowInterop;

  BackendImpact get allowInterop => _allowInterop ??= BackendImpact(
          staticUses: [
            _commonElements.jsAllowInterop1,
            _commonElements.jsAllowInterop2,
          ],
          features: EnumSet<BackendFeature>.fromValues([
            BackendFeature.needToInitializeIsolateAffinityTag,
          ], fixed: true));

  BackendImpact _numClasses;

  BackendImpact get numClasses {
    return _numClasses ??= BackendImpact(
        // The backend will try to optimize number operations and use the
        // `iae` helper directly.
        globalUses: [_commonElements.throwIllegalArgumentException]);
  }

  BackendImpact _listOrStringClasses;

  BackendImpact get listOrStringClasses {
    return _listOrStringClasses ??= BackendImpact(
        // The backend will try to optimize array and string access and use the
        // `ioore` and `iae` _commonElements directly.
        globalUses: [
          _commonElements.throwIndexOutOfRangeException,
          _commonElements.throwIllegalArgumentException
        ]);
  }

  BackendImpact _functionClass;

  BackendImpact get functionClass {
    return _functionClass ??= BackendImpact(globalClasses: [
      _commonElements.closureClass,
      _commonElements.closureClass0Args,
      _commonElements.closureClass2Args,
    ]);
  }

  BackendImpact _mapClass;

  BackendImpact get mapClass {
    return _mapClass ??= BackendImpact(
        // The backend will use a literal list to initialize the entries
        // of the map.
        globalClasses: [
          _commonElements.listClass,
          _commonElements.mapLiteralClass
        ]);
  }

  BackendImpact _setClass;

  BackendImpact get setClass => _setClass ??= BackendImpact(globalClasses: [
        // The backend will use a literal list to initialize the entries
        // of the set.
        _commonElements.listClass,
        _commonElements.setLiteralClass,
      ]);

  BackendImpact _boundClosureClass;

  BackendImpact get boundClosureClass {
    return _boundClosureClass ??=
        BackendImpact(globalClasses: [_commonElements.boundClosureClass]);
  }

  BackendImpact _nativeOrExtendsClass;

  BackendImpact get nativeOrExtendsClass {
    return _nativeOrExtendsClass ??= BackendImpact(globalUses: [
      _commonElements.getNativeInterceptorMethod
    ], globalClasses: [
      _commonElements.jsInterceptorClass,
      _commonElements.jsJavaScriptObjectClass,
      _commonElements.jsLegacyJavaScriptObjectClass,
      _commonElements.jsPlainJavaScriptObjectClass,
      _commonElements.jsJavaScriptFunctionClass
    ]);
  }

  BackendImpact _mapLiteralClass;

  BackendImpact get mapLiteralClass {
    return _mapLiteralClass ??= BackendImpact(globalUses: [
      _commonElements.mapLiteralConstructor,
      _commonElements.mapLiteralConstructorEmpty,
      _commonElements.mapLiteralUntypedMaker,
      _commonElements.mapLiteralUntypedEmptyMaker
    ]);
  }

  BackendImpact _setLiteralClass;

  BackendImpact get setLiteralClass =>
      _setLiteralClass ??= BackendImpact(globalUses: [
        _commonElements.setLiteralConstructor,
        _commonElements.setLiteralConstructorEmpty,
        _commonElements.setLiteralUntypedMaker,
        _commonElements.setLiteralUntypedEmptyMaker,
      ]);

  BackendImpact _closureClass;

  BackendImpact get closureClass {
    return _closureClass ??=
        BackendImpact(globalUses: [_commonElements.closureFromTearOff]);
  }

  BackendImpact _listClasses;

  BackendImpact get listClasses {
    return _listClasses ??= BackendImpact(
        // Literal lists can be translated into calls to these functions:
        globalUses: [
          _commonElements.jsArrayTypedConstructor,
          _commonElements.setArrayType,
        ]);
  }

  BackendImpact _jsIndexingBehavior;

  BackendImpact get jsIndexingBehavior {
    return _jsIndexingBehavior ??= BackendImpact(
        // These two _commonElements are used by the emitter and the codegen.
        // Because we cannot enqueue elements at the time of emission,
        // we make sure they are always generated.
        globalUses: [_commonElements.isJsIndexable]);
  }

  BackendImpact _traceHelper;

  BackendImpact get traceHelper {
    return _traceHelper ??=
        BackendImpact(globalUses: [_commonElements.traceHelper]);
  }

  BackendImpact _assertUnreachable;

  BackendImpact get assertUnreachable {
    return _assertUnreachable ??=
        BackendImpact(globalUses: [_commonElements.assertUnreachableMethod]);
  }

  BackendImpact _runtimeTypeSupport;

  BackendImpact get runtimeTypeSupport {
    return _runtimeTypeSupport ??= BackendImpact(globalClasses: [
      _commonElements.listClass
    ], globalUses: [
      _commonElements.setArrayType,
    ], otherImpacts: [
      getRuntimeTypeArgument,
      computeSignature
    ]);
  }

  BackendImpact _deferredLoading;

  BackendImpact get deferredLoading {
    return _deferredLoading ??=
        BackendImpact(globalUses: [_commonElements.checkDeferredIsLoaded],
            // Also register the types of the arguments passed to this method.
            globalClasses: [_commonElements.stringClass]);
  }

  BackendImpact _noSuchMethodSupport;

  BackendImpact get noSuchMethodSupport {
    return _noSuchMethodSupport ??= BackendImpact(globalUses: [
      _commonElements.createInvocationMirror,
      _commonElements.createUnmangledInvocationMirror
    ], dynamicUses: [
      Selectors.noSuchMethod_
    ]);
  }

  BackendImpact _loadLibrary;

  /// Backend impact for accessing a `loadLibrary` function on a deferred
  /// prefix.
  BackendImpact get loadLibrary {
    return _loadLibrary ??= BackendImpact(globalUses: [
      _commonElements.loadDeferredLibrary,
    ]);
  }

  BackendImpact _memberClosure;

  /// Backend impact for performing member closurization.
  BackendImpact get memberClosure {
    return _memberClosure ??=
        BackendImpact(globalClasses: [_commonElements.boundClosureClass]);
  }

  BackendImpact _staticClosure;

  /// Backend impact for performing closurization of a top-level or static
  /// function.
  BackendImpact get staticClosure {
    return _staticClosure ??=
        BackendImpact(globalClasses: [_commonElements.closureClass]);
  }

  final Map<int, BackendImpact> _genericInstantiation = {};

  BackendImpact getGenericInstantiation(int typeArgumentCount) =>
      _genericInstantiation[typeArgumentCount] ??= BackendImpact(staticUses: [
        _commonElements.getInstantiateFunction(typeArgumentCount),
        _commonElements.instantiatedGenericFunctionTypeNewRti,
        _commonElements.closureFunctionType,
      ], instantiatedClasses: [
        _commonElements.getInstantiationClass(typeArgumentCount),
      ]);

  /// Backend impact for --experiment-new-rti.
  BackendImpact _newRtiImpact;

  // TODO(sra): Split into refined impacts.
  BackendImpact get newRtiImpact =>
      _newRtiImpact ??= BackendImpact(staticUses: [
        _commonElements.findType,
        _commonElements.instanceType,
        _commonElements.arrayInstanceType,
        _commonElements.simpleInstanceType,
        _commonElements.rtiEvalMethod,
        _commonElements.rtiBindMethod,
        _commonElements.installSpecializedIsTest,
        _commonElements.generalIsTestImplementation,
        _commonElements.generalAsCheckImplementation,
        _commonElements.installSpecializedAsCheck,
        _commonElements.generalNullableIsTestImplementation,
        _commonElements.generalNullableAsCheckImplementation,
        // Specialized checks.
        _commonElements.specializedIsBool,
        _commonElements.specializedAsBool,
        _commonElements.specializedAsBoolLegacy,
        _commonElements.specializedAsBoolNullable,
        // no specializedIsDouble.
        _commonElements.specializedAsDouble,
        _commonElements.specializedAsDoubleLegacy,
        _commonElements.specializedAsDoubleNullable,
        _commonElements.specializedIsInt,
        _commonElements.specializedAsInt,
        _commonElements.specializedAsIntLegacy,
        _commonElements.specializedAsIntNullable,
        _commonElements.specializedIsNum,
        _commonElements.specializedAsNum,
        _commonElements.specializedAsNumLegacy,
        _commonElements.specializedAsNumNullable,
        _commonElements.specializedIsString,
        _commonElements.specializedAsString,
        _commonElements.specializedAsStringLegacy,
        _commonElements.specializedAsStringNullable,
        _commonElements.specializedIsTop,
        _commonElements.specializedAsTop,
        _commonElements.specializedIsObject,
        _commonElements.specializedAsObject,
      ], globalClasses: [
        _commonElements.closureClass, // instanceOrFunctionType uses this.
      ]);

  BackendImpact _rtiAddRules;

  // TODO(fishythefish): Split into refined impacts.
  BackendImpact get rtiAddRules => _rtiAddRules ??= BackendImpact(globalUses: [
        _commonElements.rtiAddRulesMethod,
        _commonElements.rtiAddErasedTypesMethod,
        if (_options.enableVariance)
          _commonElements.rtiAddTypeParameterVariancesMethod,
      ], otherImpacts: [
        _needsString('Needed to encode the new RTI ruleset.')
      ]);
}
