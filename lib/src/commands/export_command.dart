import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:pepper_sprite_core/pepper_sprite_core.dart';

/// {@template export_command}
///
/// `pepper_sprite_cli export`
/// A [Command] to export an image from a pepper sprite file
/// {@endtemplate}
class ExportCommand extends Command<int> {
  /// {@macro export_command}
  ExportCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'The path to the pepper sprite file (.psp)',
        mandatory: true,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'The output path where the image will be saved',
        mandatory: true,
      )
      ..addOption(
        'animation',
        abbr: 'a',
        help:
            'Export a specific animation (optional, exports full sprite '
            'if not specified)',
      )
      ..addOption(
        'frame',
        abbr: 'f',
        help: 'Export a specific frame of an animation (requires --animation)',
      );
  }

  @override
  String get description => 'Export an image from a pepper sprite file';

  @override
  String get name => 'export';

  final Logger _logger;

  @override
  Future<int> run() async {
    final sourcePath = argResults!['source'] as String;
    final outputPath = argResults!['output'] as String;
    final animationName = argResults!['animation'] as String?;
    final frameIndexStr = argResults!['frame'] as String?;

    // Validate source file exists
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      _logger.err('Source file not found: $sourcePath');
      return ExitCode.usage.code;
    }

    // Validate frame index if provided
    int? frameIndex;
    if (frameIndexStr != null) {
      if (animationName == null) {
        _logger.err('--frame requires --animation to be specified');
        return ExitCode.usage.code;
      }
      frameIndex = int.tryParse(frameIndexStr);
      if (frameIndex == null) {
        _logger.err('Frame index must be a valid integer: $frameIndexStr');
        return ExitCode.usage.code;
      }
    }

    _logger.info('Reading pepper sprite file...');

    try {
      // Read the file bytes
      final bytes = await sourceFile.readAsBytes();

      // Deserialize the file
      final file = _deserializeFile(sourcePath, bytes);

      _logger.info('Exporting image...');

      // Ensure output directory exists
      final outputDir = Directory(path.dirname(outputPath));
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      // Export based on options
      if (animationName != null && frameIndex != null) {
        // Export specific animation frame
        final pngBytes = ImageExporter.exportAnimationFrameToPng(
          file,
          animationName,
          frameIndex,
        );
        await File(outputPath).writeAsBytes(pngBytes);
        _logger.success(
          'Animation frame $frameIndex of "$animationName" '
          'exported to $outputPath',
        );
      } else if (animationName != null) {
        // Export all frames of an animation
        ImageExporter.exportAnimationToPngFiles(
          file,
          animationName,
          path.dirname(outputPath),
        );
        _logger.success(
          'All frames of animation "$animationName" '
          'exported to ${path.dirname(outputPath)}',
        );
      } else {
        // Export full sprite
        ImageExporter.exportToPngFile(file, outputPath);
        _logger.success('Image exported successfully to $outputPath');
      }

      return ExitCode.success.code;
    } on ExportException catch (e) {
      _logger.err('Export error: $e');
      return ExitCode.software.code;
    } on Exception catch (e) {
      _logger.err('Error processing file: $e');
      return ExitCode.software.code;
    }
  }

  /// Deserializes a PSP file from bytes
  PepperSpriteFile _deserializeFile(String filePath, Uint8List bytes) {
    // Generate a file ID from the path
    final fileId = path.basenameWithoutExtension(filePath);

    // Create minimal metadata
    final metadata = <String, dynamic>{
      'name': fileId,
      'userId': 'cli-user',
    };

    return PspFileFormat.deserialize(fileId, metadata, bytes);
  }
}
