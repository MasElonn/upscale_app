import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'upscale.dart';

//todo: fixing any errors

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscale Demo',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[900],
        colorScheme: ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          surface: Colors.grey[800]!,
          background: Colors.grey[900]!,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
      ),
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
  final ImagePicker picker = ImagePicker();
  final FlutterUpscaler _upscaler = FlutterUpscaler();

  ui.Image? _originalImage;
  ui.Image? _upscaledImage;
  double _progress = 0.0;
  String _progressMessage = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _upscaleImage() async {
    if (_originalImage == null || _selectedModel == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = 'Initializing model...';
    });

    try {
      print('Selected model: $_selectedModel');
      print(
        'Original image dimensions: ${_originalImage!.width}x${_originalImage!.height}',
      );

      // Initialize the model
      await _upscaler.initializeModel(_selectedModel!);

      setState(() {
        _progress = 0.1;
        _progressMessage = 'Processing image...';
      });

      // Upscale the image
      _upscaledImage = await _upscaler.upscaleImage(
        _originalImage!,
        4, // 2x upscaling
        onProgress: (progress, message) {
          print('Progress: $progress - $message');
          setState(() {
            _progress = progress;
            _progressMessage = message;
          });
        },
      );

      if (_upscaledImage != null) {
        print(
          'Upscaled image dimensions: ${_upscaledImage!.width}x${_upscaledImage!.height}',
        );
      }

      setState(() {
        _isProcessing = false;
        _progress = 1.0;
        _progressMessage = 'Upscaling complete';
      });
    } catch (e) {
      print('Upscaling error: $e');
      setState(() {
        _isProcessing = false;
        _progressMessage = 'Error: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upscaling failed: $e')));
    }
  }

  Future<void> _saveImage() async {
    if (_upscaledImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upscaled image to save')),
      );
      return;
    }

    try {
      final byteData = await _upscaledImage!.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      // Save to temporary directory
      final tempDir = await getDownloadsDirectory();
      final fileName = 'upscaled_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir?.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image saved to: ${file.path}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
    }
  }

  Future<void> selectimage() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Ensure we get the highest quality
      );

      if (image != null) {
        print('Selected image path: ${image.path}');
        print('Selected image format: ${image.path.split('.').last}');

        final bytes = await image.readAsBytes();
        print('Image size: ${bytes.length} bytes');

        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo fi = await codec.getNextFrame();

        print('Image dimensions: ${fi.image.width}x${fi.image.height}');

        setState(() {
          _originalImage = fi.image;
          _upscaledImage =
              null; // Reset upscaled image when new image is selected
        });
      }
    } catch (e) {
      print('Error selecting image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
    }
  }

  @override
  void dispose() {
    _upscaler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HomePage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // MediaDisplay
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _upscaledImage != null
                  ? RawImage(image: _upscaledImage, fit: BoxFit.cover)
                  : _originalImage != null
                  ? RawImage(image: _originalImage, fit: BoxFit.cover)
                  : const Center(child: Text('No image selected')),
            ),
            // Progress bar
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade300,
              color: Colors.blue,
            ),

            Text(_progressMessage),
            const SizedBox(height: 16),
            // UpscaleButton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _upscaleImage,
                child: Text(_isProcessing ? 'Processing...' : 'Upscale'),
              ),
            ),
            const SizedBox(height: 16),
            // Select & Save buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: selectimage,
                  child: const Text('Select'),
                ),
                ElevatedButton(
                  onPressed: _saveImage,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
              ),
              value: _selectedModel,
              items: _models
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedModel = val),
            ),
          ],
        ),
      ),
    );
  }
}
