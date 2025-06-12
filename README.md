# Flutter Image Upscaler

A Flutter application that uses machine learning models to upscale images with high quality. The app supports multiple ONNX models for super-resolution and provides a user-friendly interface for image processing.

## Features

- Select and upscale images from gallery
- Multiple ONNX model support
- Real-time progress tracking
- Before/after comparison with slider
- Save upscaled images to gallery
- High-quality image processing with tiling support

## Requirements

- Flutter SDK
- ONNX Runtime Flutter plugin
- Pre-trained ONNX super-resolution models

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/upscale_app.git
```

2. Install dependencies:
```bash
flutter pub get
```

3. Place your ONNX models in the `assets` directory

4. Run the app:
```bash
flutter run
```

## Usage

1. Select an image from your gallery
2. Choose an upscaling model from the dropdown
3. Click "Upscale" to process the image
4. Use the slider to compare before/after results
5. Save the upscaled image to your gallery

## Supported Models

- super-resolution-10.onnx
- Real-ESRGAN_x2plus.onnx
- 4x-UltraSharpV2_fp32_op17.onnx
- 4x-UltraSharpV2_Lite_fp16_op17.onnx
- 4x-UltraSharpV2_Lite_fp32_op17.onnx
- 4x-UltraSharpV2_fp16_op17.onnx
- edsr_onnxsim_2x.onnx
- Real-ESRGAN-x4plus.onnx

## License

This project is licensed under the MIT License - see the LICENSE file for details.
