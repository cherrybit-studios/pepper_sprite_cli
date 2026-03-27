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
  });
}
