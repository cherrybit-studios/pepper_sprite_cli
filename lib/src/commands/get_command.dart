import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:pepper_sprite_core/pepper_sprite_core.dart';
import 'package:yaml/yaml.dart';

/// Configuration for a single file to download and export
class FileConfig {
  /// Creates a file config
  FileConfig({required this.fileId, required this.output, this.scale});

  /// The file ID to download
  final String fileId;

  /// The output path for the exported image
  final String output;

  /// Optional scale dimensions in WIDTH,HEIGHT format (e.g. "512,512")
  final String? scale;
}

/// {@template get_command}
///
/// `pepper_sprite_cli get`
/// A [Command] to download and export files based on pepper-sprite.yaml config
/// {@endtemplate}
class GetCommand extends Command<int> {
  /// {@macro get_command}
  GetCommand({required Logger logger, http.Client? httpClient})
    : _logger = logger,
      _httpClient = httpClient ?? http.Client() {
    argParser
      ..addOption(
        'api-key',
        abbr: 'k',
        help: 'The API key for authentication',
        mandatory: true,
      )
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to the config file',
        defaultsTo: './pepper-sprite.yaml',
      );
  }

  @override
  String get description =>
      'Download and export files based on pepper-sprite.yaml config';

  @override
  String get name => 'get';

  final Logger _logger;
  final http.Client _httpClient;

  @override
  Future<int> run() async {
    final apiKey = argResults!['api-key'] as String;
    final configPath = argResults!['config'] as String;

    // Check if config file exists
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      _logger.err('Config file not found: $configPath');
      return ExitCode.usage.code;
    }

    // Parse config file
    final configs = _parseConfig(configFile);
    if (configs.isEmpty) {
      _logger.err('No files configured in $configPath');
      return ExitCode.usage.code;
    }

    _logger.info('Found ${configs.length} file(s) to process');

    var successCount = 0;
    var errorCount = 0;

    for (final config in configs) {
      final result = await _processFile(config, apiKey);
      if (result) {
        successCount++;
      } else {
        errorCount++;
      }
    }

    _logger.info('');
    if (errorCount == 0) {
      _logger.success('All $successCount file(s) processed successfully');
      return ExitCode.success.code;
    } else {
      _logger.warn(
        '$successCount file(s) succeeded, $errorCount file(s) failed',
      );
      return ExitCode.software.code;
    }
  }

  /// Parses the YAML config file and returns list of file configs
  List<FileConfig> _parseConfig(File configFile) {
    final content = configFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;

    if (yaml == null) return [];

    final filesYaml = yaml['files'] as YamlList?;
    if (filesYaml == null) return [];

    final configs = <FileConfig>[];
    for (final fileYaml in filesYaml) {
      final fileMap = fileYaml as YamlMap?;
      if (fileMap == null) continue;

      final fileId = fileMap['fileId'] as String?;
      final output = fileMap['output'] as String?;
      final scale = fileMap['scale'] as String?;

      if (fileId != null && output != null) {
        configs.add(FileConfig(fileId: fileId, output: output, scale: scale));
      }
    }

    return configs;
  }

  /// Downloads and exports a single file
  /// Returns true on success, false on failure
  Future<bool> _processFile(FileConfig config, String apiKey) async {
    _logger.info('Processing ${config.fileId}...');

    // Validate and parse scale if provided
    int? scaleWidth;
    int? scaleHeight;
    if (config.scale != null) {
      final parts = config.scale!.split(',');
      if (parts.length != 2) {
        _logger.err(
          '  scale must be in the format WIDTH,HEIGHT with positive '
          'integers, e.g. 512,512',
        );
        return false;
      }
      final w = int.tryParse(parts[0]);
      final h = int.tryParse(parts[1]);
      if (w == null || h == null || w <= 0 || h <= 0) {
        _logger.err(
          '  scale must be in the format WIDTH,HEIGHT with positive '
          'integers, e.g. 512,512',
        );
        return false;
      }
      scaleWidth = w;
      scaleHeight = h;
    }

    // Create temp file
    final tempDir = Directory.systemTemp.createTempSync('pepper_sprite_');
    final tempFile = File(path.join(tempDir.path, '${config.fileId}.psp'));

    try {
      // Download file
      final downloadSuccess = await _downloadFile(
        config.fileId,
        apiKey,
        tempFile,
      );
      if (!downloadSuccess) {
        return false;
      }

      // Export file
      await _exportFile(
        tempFile,
        config.output,
        scaleWidth: scaleWidth,
        scaleHeight: scaleHeight,
      );

      _logger.success('  Exported to ${config.output}');
      return true;
    } on Exception catch (e) {
      _logger.err('  Error: $e');
      return false;
    } finally {
      // Cleanup temp directory
      tempDir.deleteSync(recursive: true);
    }
  }

  /// Downloads a file from the cloud service
  Future<bool> _downloadFile(
    String fileId,
    String apiKey,
    File outputFile,
  ) async {
    final url =
        'https://us-central1-pepper-sprite.cloudfunctions.net/'
        'downloadFileWithApiKey?fileId=$fileId&apiKey=$apiKey';

    final response = await _httpClient.get(Uri.parse(url));

    if (response.statusCode != 200) {
      _logger.err('  Failed to download: ${response.statusCode}');
      return false;
    }

    // Ensure output directory exists
    final directory = Directory(path.dirname(outputFile.path));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    await outputFile.writeAsBytes(response.bodyBytes);
    return true;
  }

  /// Exports a PSP file to PNG
  Future<void> _exportFile(
    File sourceFile,
    String outputPath, {
    int? scaleWidth,
    int? scaleHeight,
  }) async {
    final bytes = await sourceFile.readAsBytes();

    // Deserialize
    final fileId = path.basenameWithoutExtension(sourceFile.path);
    final metadata = <String, dynamic>{
      'name': fileId,
      'userId': 'cli-user',
    };
    final file = PspFileFormat.deserialize(fileId, metadata, bytes);

    // Ensure output directory exists
    final outputDir = Directory(path.dirname(outputPath));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Export
    ImageExporter.exportToPngFile(
      file,
      outputPath,
      scaleWidth: scaleWidth,
      scaleHeight: scaleHeight,
    );
  }
}
