library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Callback for tracking progress during upscaling
typedef ProgressCallback = void Function(double progress, String message);

class FlutterUpscaler {
  OrtSession? _session;
  final int tileSize; // Tile size for processing
  final int overlap; // Overlap between tiles to prevent seams

  FlutterUpscaler({
    this.tileSize = 128, // Default tile size
    this.overlap = 8, // Default overlap
  }) : assert(overlap < tileSize, 'Overlap must be smaller than tile size');

  /// Initialize the ONNX model from assets
  Future<void> initializeModel(String modelPath) async {
    final sessionOptions = OrtSessionOptions();
    try {
      OrtEnv.instance.init();

      // Optimize for mobile devices
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setInterOpNumThreads(2);
      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final rawAssetFile = await rootBundle.load(modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();
    } catch (e) {
      throw Exception('Failed to initialize ONNX Runtime from assets: $e');
    }
  }

  /// Initialize the ONNX model from a file on the device
  Future<void> initializeModelFromFile(String filePath) async {
    final sessionOptions = OrtSessionOptions();
    try {
      OrtEnv.instance.init();

      // Optimize for mobile devices
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setInterOpNumThreads(2);
      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();
    } catch (e) {
      throw Exception('Failed to initialize ONNX Runtime from file: $e');
    }
  }

  /// Upscale an image with the specified scale factor
  Future<ui.Image?> upscaleImage(
    ui.Image sourceImage,
    int scale, {
    bool useTiling = true,
    ProgressCallback? onProgress,
  }) async {
    if (_session == null) {
      throw Exception('Model not initialized. Call initializeModel first.');
    }

    try {
      if (!useTiling ||
          (sourceImage.width <= tileSize && sourceImage.height <= tileSize)) {
        return await _processFullImage(sourceImage, scale, onProgress);
      } else {
        return await _processByTiles(sourceImage, scale, onProgress);
      }
    } catch (e) {
      throw Exception('Error processing image: $e');
    }
  }

  Future<ui.Image> _processFullImage(
    ui.Image sourceImage,
    int scale,
    ProgressCallback? onProgress,
  ) async {
    const int totalSteps = 4;
    int currentStep = 0;

    void updateProgress(String stage) {
      currentStep++;
      final progress = currentStep / totalSteps;
      onProgress?.call(
        progress,
        'Processing full image: $stage (${(progress * 100).toStringAsFixed(1)}%)',
      );
    }

    // Step 1: Prepare input
    updateProgress('Preparing input');
    final inputTensor = await _prepareInputTensor(
      sourceImage,
      sourceImage.width,
      sourceImage.height,
    );

    // Step 2: Run inference
    updateProgress('Running neural network');
    final outputs = await _runInference(inputTensor);
    inputTensor.release();

    // Step 3: Process output
    updateProgress('Processing output');
    final result = await _tensorToImage(
      outputs,
      (sourceImage.width * scale).toInt(),
      (sourceImage.height * scale).toInt(),
    );

    // Step 4: Finalizing
    updateProgress('Finalizing');

    return result;
  }

  Future<ui.Image> _processByTiles(
    ui.Image sourceImage,
    int scale,
    ProgressCallback? onProgress,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final numTilesX = (sourceImage.width / (tileSize - overlap)).ceil();
    final numTilesY = (sourceImage.height / (tileSize - overlap)).ceil();
    final totalTiles = numTilesX * numTilesY;
    int processedTiles = 0;

    // Calculate total steps for progress tracking
    const int stepsPerTile = 4; // Extract, prepare, process, draw
    final totalSteps = totalTiles * stepsPerTile;
    int currentStep = 0;

    void updateProgress(String stage) {
      currentStep++;
      final progress = currentStep / totalSteps;
      onProgress?.call(
        progress,
        'Tile ${processedTiles + 1}/$totalTiles: $stage (${(progress * 100).toStringAsFixed(1)}%)',
      );
    }

    for (int y = 0; y < numTilesY; y++) {
      for (int x = 0; x < numTilesX; x++) {
        // Calculate tile coordinates
        final tileX = x * (tileSize - overlap);
        final tileY = y * (tileSize - overlap);
        final tileWidth = math.min(tileSize, sourceImage.width - tileX);
        final tileHeight = math.min(tileSize, sourceImage.height - tileY);

        // Step 1: Extract tile
        updateProgress('Extracting tile');
        final tile = await _extractTile(
          sourceImage,
          tileX,
          tileY,
          tileWidth,
          tileHeight,
        );

        // Step 2: Prepare tensor
        updateProgress('Preparing tensor');
        final inputTensor = await _prepareInputTensor(
          tile,
          tileWidth,
          tileHeight,
        );

        // Step 3: Process tile
        updateProgress('Processing');
        final outputs = await _runInference(inputTensor);
        inputTensor.release();

        final processedTile = await _tensorToImage(
          outputs,
          (tileWidth * scale).toInt(),
          (tileHeight * scale).toInt(),
        );

        // Step 4: Draw tile
        updateProgress('Drawing tile');
        final outputX = tileX * scale;
        final outputY = tileY * scale;
        canvas.drawImage(
          processedTile,
          Offset(outputX.toDouble(), outputY.toDouble()),
          paint,
        );

        processedTiles++;
      }
    }

    // Final progress update
    onProgress?.call(1.0, 'Finalizing image...');

    final finalWidth = sourceImage.width * scale;
    final finalHeight = sourceImage.height * scale;
    final picture = recorder.endRecording();
    return await picture.toImage(finalWidth, finalHeight);
  }

  Future<ui.Image> _extractTile(
    ui.Image source,
    int x,
    int y,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    return await recorder.endRecording().toImage(width, height);
  }

  Future<OrtValueTensor> _prepareInputTensor(
    ui.Image image,
    int width,
    int height,
  ) async {
    try {
      // Resize image to 224x224 if needed
      ui.Image resizedImage = image;
      if (width != 224 || height != 224) {
        resizedImage = await _resizeImage(image, 224, 224);
      }

      final bytes = await resizedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (bytes == null) throw Exception('Failed to get image bytes');

      final rgbaList = bytes.buffer.asUint8List();
      final inputData = Float32List(224 * 224); // Single channel

      // Convert to grayscale
      for (int i = 0; i < 224 * 224; i++) {
        final r = rgbaList[i * 4];
        final g = rgbaList[i * 4 + 1];
        final b = rgbaList[i * 4 + 2];
        // Convert to grayscale using standard formula
        inputData[i] = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0;
      }

      return OrtValueTensor.createTensorWithDataList(inputData, [
        1,
        1,
        224,
        224,
      ]);
    } catch (e) {
      throw Exception('Failed to prepare input tensor: $e');
    }
  }

  Future<ui.Image> _resizeImage(
    ui.Image image,
    int targetWidth,
    int targetHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );

    return await recorder.endRecording().toImage(targetWidth, targetHeight);
  }

  Future<List<dynamic>> _runInference(OrtValueTensor inputTensor) async {
    final runOptions = OrtRunOptions();
    try {
      if (_session == null) {
        throw Exception('Model not initialized');
      }

      final outputs = await _session!.runAsync(runOptions, {
        'input': inputTensor,
      });

      if (outputs == null || outputs.isEmpty) {
        throw Exception('No output from model');
      }

      final output = outputs[0]?.value;
      if (output == null) {
        throw Exception('Invalid output from model');
      }

      return output as List;
    } catch (e) {
      throw Exception('Inference failed: $e');
    } finally {
      runOptions.release();
    }
  }

  Future<ui.Image> _tensorToImage(
    List<dynamic> outputs,
    int finalWidth,
    int finalHeight,
  ) async {
    try {
      final pixels = Uint8List(finalWidth * finalHeight * 4);
      int index = 0;

      // Handle both single-channel and multi-channel outputs
      if (outputs[0] is List && outputs[0][0] is List) {
        // Multi-channel output
        for (int y = 0; y < finalHeight; y++) {
          for (int x = 0; x < finalWidth; x++) {
            if (outputs[0].length == 3) {
              // RGB output
              pixels[index++] = (outputs[0][0][y][x] * 255)
                  .clamp(0, 255)
                  .toInt();
              pixels[index++] = (outputs[0][1][y][x] * 255)
                  .clamp(0, 255)
                  .toInt();
              pixels[index++] = (outputs[0][2][y][x] * 255)
                  .clamp(0, 255)
                  .toInt();
            } else {
              // Single channel output
              final gray = (outputs[0][0][y][x] * 255).clamp(0, 255).toInt();
              pixels[index++] = gray;
              pixels[index++] = gray;
              pixels[index++] = gray;
            }
            pixels[index++] = 255; // Alpha
          }
        }
      } else {
        // Single channel output as flat array
        for (int i = 0; i < finalWidth * finalHeight; i++) {
          final gray = (outputs[i] * 255).clamp(0, 255).toInt();
          pixels[i * 4] = gray;
          pixels[i * 4 + 1] = gray;
          pixels[i * 4 + 2] = gray;
          pixels[i * 4 + 3] = 255;
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        finalWidth,
        finalHeight,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    } catch (e) {
      throw Exception('Failed to convert tensor to image: $e');
    }
  }

  /// Dispose of the upscaler and free resources
  void dispose() {
    _session?.release();
    _session = null;
  }
}
