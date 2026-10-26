import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bug 12: pubspec.yaml declares standard Dart SDK constraint compatible with Flutter 3.29', () {
    final pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist');
    final content = pubspecFile.readAsStringSync();
    
    // Must NOT contain sdk: ^3.13.5
    expect(content.contains('sdk: ^3.13.5'), isFalse,
        reason: 'Dart 3.13.5 breaks standard Flutter 3.29 toolchains');
    
    // Must specify sdk: ^3.7.0
    expect(content.contains('sdk: ^3.7.0'), isTrue,
        reason: 'pubspec.yaml environment sdk must match Flutter 3.29 (Dart 3.7.0)');
  });
}
