import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_super_resolution/flutter_super_resolution.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscale',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedModel;
  XFile? _selectedImage;
  XFile? _upscaledImage;
  double _sliderValue = 0.0;
  double _progress = 0.0;
  bool _isProcessing = false;
  final List<String> _models = [
    'assets/super-resolution-10.onnx',
    'assets/Real-ESRGAN_x2plus.onnx',
    'assets/4x-UltraSharpV2_fp32_op17.onnx',
    'assets/4x-UltraSharpV2_Lite_fp16_op17.onnx',
    'assets/4x-UltraSharpV2_Lite_fp32_op17.onnx',
    'assets/4x-UltraSharpV2_fp16_op17.onnx',
    'assets/edsr_onnxsim_2x.onnx',
    'assets/Real-ESRGAN-x4plus.onnx',
  ];
  final ImagePicker _picker = ImagePicker();
  late FlutterUpscaler _upscaler;

  @override
  void initState() {
    super.initState();
    _upscaler = FlutterUpscaler(
      tileSize: 224, // Changed to match model's expected input size
      overlap: 8,
    );
  }

  @override
  void dispose() {
    _upscaler.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _upscaledImage = null;
      });
    }
  }

  Future<void> _upscaleImage() async {
    if (_selectedImage == null || _selectedModel == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      await _upscaler.initializeModel(_selectedModel!);
      final image = await decodeImageFromList(
        await _selectedImage!.readAsBytes(),
      );

      // Resize image to match model's expected input size
      final resizedImage = await _resizeImage(image, 224, 224);

      final upscaledImage = await _upscaler.upscaleImage(
        resizedImage,
        2, // scale factor
        onProgress: (progress, message) {
          setState(() {
            _progress = progress;
          });
        },
      );

      if (upscaledImage != null) {
        final byteData = await upscaledImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/upscaled.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());

          setState(() {
            _upscaledImage = XFile(file.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error upscaling image: $e')));
    } finally {
      setState(() {
        _isProcessing = false;
      });
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

    final picture = recorder.endRecording();
    return await picture.toImage(targetWidth, targetHeight);
  }

  Future<void> _saveImage() async {
    if (_upscaledImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upscaled image to save')),
      );
      return;
    }

    try {
      final bytes = await _upscaledImage!.readAsBytes();
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: "upscaled_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved successfully')),
        );
      } else {
        throw Exception('Failed to save image');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upscale')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200], // Added background color
              ),
              child: _selectedImage != null
                  ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('Processing: ${(_progress * 100).toStringAsFixed(1)}%'),
            ],
            if (_upscaledImage != null) ...[
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(_upscaledImage!.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(_selectedImage!.path)),
                        fit: BoxFit.cover,
                        alignment: Alignment(-1 + _sliderValue * 2, 0),
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _sliderValue,
                onChanged: (value) {
                  setState(() {
                    _sliderValue = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _upscaleImage,
                child: const Text('Upscale'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _selectImage,
                  child: const Text('Select Image'),
                ),
                ElevatedButton(
                  onPressed: _upscaledImage != null ? _saveImage : null,
                  child: const Text('Save Image'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          label: Text('Select Model'),
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedModel,
                        items: _models
                            .map(
                              (String model) => DropdownMenuItem<String>(
                                value: model,
                                child: Text(
                                  model.split('/').last,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedModel = newValue;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
