import 'package:flutter/material.dart';


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscale Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
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
                image: const DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/400x200'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // UpscaleButton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: trigger upscale logic
                },
                child: const Text('Upscale'),
              ),
            ),
            const SizedBox(height: 16),
            // Select & Save buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: open file picker
                  },
                  child: const Text('Select'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: save image
                  },
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
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedModel = val),
            ),
          ],
        ),
      ),
    );
  }
}
