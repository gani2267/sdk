// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../analysis_server_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StatementCompletionTest);
  });
}

@reflectiveTest
class StatementCompletionTest extends PubPackageAnalysisServerTest {
  late SourceChange change;

  @override
  Future<void> setUp() async {
    super.setUp();
    await setRoots(included: [workspaceRootPath], excluded: []);
  }

  Future<void> test_invalidFilePathFormat_notAbsolute() async {
    var request =
        EditGetStatementCompletionParams('test.dart', 0).toRequest('0');
    var response = await handleRequest(request);
    assertResponseFailure(
      response,
      requestId: '0',
      errorCode: RequestErrorCode.INVALID_FILE_PATH_FORMAT,
    );
  }

  Future<void> test_invalidFilePathFormat_notNormalized() async {
    var request = EditGetStatementCompletionParams(
            convertPath('/foo/../bar/test.dart'), 0)
        .toRequest('0');
    var response = await handleRequest(request);
    assertResponseFailure(
      response,
      requestId: '0',
      errorCode: RequestErrorCode.INVALID_FILE_PATH_FORMAT,
    );
  }

  Future<void> test_plainEnterFromStart() async {
    addTestFile('''
main() {
  int v = 1;
}
''');
    await waitForTasksFinished();
    await _prepareCompletion('v = 1;', atStart: true);
    _assertHasChange('Insert a newline at the end of the current line', '''
main() {
  int v = 1;
  /*caret*/
}
''');
  }

  Future<void> test_plainOleEnter() async {
    addTestFile('''
main() {
  int v = 1;
}
''');
    await waitForTasksFinished();
    await _prepareCompletion('v = 1;', atEnd: true);
    _assertHasChange('Insert a newline at the end of the current line', '''
main() {
  int v = 1;
  /*caret*/
}
''');
  }

  Future<void> test_plainOleEnterWithError() async {
    addTestFile('''
main() {
  int v =
}
''');
    await waitForTasksFinished();
    var match = 'v =';
    await _prepareCompletion(match, atEnd: true);
    _assertHasChange(
        'Insert a newline at the end of the current line',
        '''
main() {
  int v =
  x
}
''',
        (s) => s.indexOf(match) + match.length); // Ensure cursor after '='.
  }

  void _assertHasChange(String message, String expectedCode,
      [int Function(String)? cmp]) {
    if (change.message == message) {
      if (change.edits.isNotEmpty) {
        var resultCode =
            SourceEdit.applySequence(testFileContent, change.edits[0].edits);
        expect(resultCode, expectedCode.replaceAll('/*caret*/', ''));
        if (cmp != null) {
          var offset = cmp(resultCode);
          expect(change.selection!.offset, offset);
        }
      } else {
        if (cmp != null) {
          var offset = cmp(testFileContent);
          expect(change.selection!.offset, offset);
        }
      }
      return;
    }
    fail('Expected to find |$message| but got: ' + change.message);
  }

  Future<void> _prepareCompletion(String search,
      {bool atStart = false, bool atEnd = false, int delta = 0}) async {
    var offset = findOffset(search);
    if (atStart) {
      delta = 0;
    } else if (atEnd) {
      delta = search.length;
    }
    await _prepareCompletionAt(offset + delta);
  }

  Future<void> _prepareCompletionAt(int offset) async {
    var request =
        EditGetStatementCompletionParams(testFile.path, offset).toRequest('0');
    var response = await handleSuccessfulRequest(request);
    var result = EditGetStatementCompletionResult.fromResponse(response);
    change = result.change;
  }
}
