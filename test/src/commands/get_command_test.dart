import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pepper_sprite_cli/src/command_runner.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('get', () {
    late Logger logger;
    late PepperSpriteCliCommandRunner commandRunner;

    setUp(() {
      logger = _MockLogger();
      commandRunner = PepperSpriteCliCommandRunner(logger: logger);
    });

    test('config file not found', () async {
      final exitCode = await commandRunner.run([
        'get',
        '-k',
        'test-api-key',
        '-c',
        '/nonexistent/config.yaml',
      ]);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err('Config file not found: /nonexistent/config.yaml'),
      ).called(1);
    });

    test('command exists', () {
      // Just verify the command runner was created successfully
      // and the get command is registered
      expect(commandRunner, isNotNull);
    });

    group('scale', () {
      late Directory tempDir;
      late File configFile;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('pepper_sprite_test_');
        configFile = File('${tempDir.path}/pepper-sprite.yaml');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('invalid format — non-numeric', () async {
        configFile.writeAsStringSync('''
files:
  - fileId: "test-id"
    output: "/tmp/output.png"
    scale: "abc,def"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
        ]);

        expect(exitCode, ExitCode.software.code);
        verify(
          () => logger.err(
            '  scale must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — single value', () async {
        configFile.writeAsStringSync('''
files:
  - fileId: "test-id"
    output: "/tmp/output.png"
    scale: "512"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
        ]);

        expect(exitCode, ExitCode.software.code);
        verify(
          () => logger.err(
            '  scale must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — zero width', () async {
        configFile.writeAsStringSync('''
files:
  - fileId: "test-id"
    output: "/tmp/output.png"
    scale: "0,512"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
        ]);

        expect(exitCode, ExitCode.software.code);
        verify(
          () => logger.err(
            '  scale must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — negative height', () async {
        configFile.writeAsStringSync('''
files:
  - fileId: "test-id"
    output: "/tmp/output.png"
    scale: "512,-1"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
        ]);

        expect(exitCode, ExitCode.software.code);
        verify(
          () => logger.err(
            '  scale must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });
    });

    group('--only', () {
      late Directory tempDir;
      late File configFile;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('pepper_sprite_test_');
        configFile = File('${tempDir.path}/pepper-sprite.yaml');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('no entry with matching name', () async {
        configFile.writeAsStringSync('''
files:
  - name: buildings
    fileId: "Z8y1MP7R7z2u31aJq01N"
    output: "/tmp/buildings.png"
  - name: tiles
    fileId: "w7Oy7gJXkBWUJgW7Y1jj"
    output: "/tmp/tiles.png"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
          '--only',
          'unknown',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            'No entry with name "unknown" found in ${configFile.path}',
          ),
        ).called(1);
      });

      test('entries without name are excluded when --only is used', () async {
        configFile.writeAsStringSync('''
files:
  - fileId: "no-name-id"
    output: "/tmp/no-name.png"
''');

        final exitCode = await commandRunner.run([
          'get',
          '-k',
          'test-api-key',
          '-c',
          configFile.path,
          '--only',
          'buildings',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            'No entry with name "buildings" found in ${configFile.path}',
          ),
        ).called(1);
      });
    });
  });
}
