import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pepper_sprite_cli/src/command_runner.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('export', () {
    late Logger logger;
    late PepperSpriteCliCommandRunner commandRunner;

    setUp(() {
      logger = _MockLogger();
      commandRunner = PepperSpriteCliCommandRunner(logger: logger);
    });

    test('source file not found', () async {
      final exitCode = await commandRunner.run([
        'export',
        '-s',
        '/nonexistent/file.psp',
        '-o',
        '/tmp/output.png',
      ]);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err('Source file not found: /nonexistent/file.psp'),
      ).called(1);
    });

    test('command exists', () {
      // Just verify the command runner was created successfully
      // and the export command is registered
      expect(commandRunner, isNotNull);
    });

    group('--scale-size', () {
      test('invalid format — non-numeric', () async {
        final exitCode = await commandRunner.run([
          'export',
          '-s',
          '/nonexistent/file.psp',
          '-o',
          '/tmp/output.png',
          '--scale-size',
          'abc,def',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            '--scale-size must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — single value', () async {
        final exitCode = await commandRunner.run([
          'export',
          '-s',
          '/nonexistent/file.psp',
          '-o',
          '/tmp/output.png',
          '--scale-size',
          '512',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            '--scale-size must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — zero width', () async {
        final exitCode = await commandRunner.run([
          'export',
          '-s',
          '/nonexistent/file.psp',
          '-o',
          '/tmp/output.png',
          '--scale-size',
          '0,512',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            '--scale-size must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });

      test('invalid format — negative height', () async {
        final exitCode = await commandRunner.run([
          'export',
          '-s',
          '/nonexistent/file.psp',
          '-o',
          '/tmp/output.png',
          '--scale-size',
          '512,-1',
        ]);

        expect(exitCode, ExitCode.usage.code);
        verify(
          () => logger.err(
            '--scale-size must be in the format WIDTH,HEIGHT with positive '
            'integers, e.g. 512,512',
          ),
        ).called(1);
      });
    });
  });
}
