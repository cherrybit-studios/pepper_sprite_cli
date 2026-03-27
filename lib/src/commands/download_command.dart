import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// {@template download_command}
///
/// `pepper_sprite_cli download`
/// A [Command] to download a file using fileId and apiKey
/// {@endtemplate}
class DownloadCommand extends Command<int> {
  /// {@macro download_command}
  DownloadCommand({required Logger logger, http.Client? httpClient})
    : _logger = logger,
      _httpClient = httpClient ?? http.Client() {
    argParser
      ..addOption(
        'file-id',
        abbr: 'f',
        help: 'The ID of the file to download',
        mandatory: true,
      )
      ..addOption(
        'api-key',
        abbr: 'k',
        help: 'The API key for authentication',
        mandatory: true,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'The output path where the file will be saved',
        mandatory: true,
      );
  }

  @override
  String get description => 'Download a file using fileId and apiKey';

  @override
  String get name => 'download';

  final Logger _logger;
  final http.Client _httpClient;

  @override
  Future<int> run() async {
    final fileId = argResults!['file-id'] as String;
    final apiKey = argResults!['api-key'] as String;
    final outputPath = argResults!['output'] as String;

    final url =
        'https://us-central1-pepper-sprite.cloudfunctions.net/downloadFileWithApiKey?fileId=$fileId&apiKey=$apiKey';

    _logger.info('Downloading file...');

    try {
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _logger
          ..err('Failed to download file: ${response.statusCode}')
          ..err(response.body);
        return ExitCode.software.code;
      }

      // Ensure the output directory exists
      final outputFile = File(outputPath);
      final directory = Directory(path.dirname(outputPath));
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      await outputFile.writeAsBytes(response.bodyBytes);

      _logger.success('File downloaded successfully to $outputPath');
      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('Error downloading file: $e');
      return ExitCode.software.code;
    }
  }
}
