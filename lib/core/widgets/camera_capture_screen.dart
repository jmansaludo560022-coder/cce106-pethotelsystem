import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'custom_button.dart';

/// What the camera screen returns.
class CameraCaptureResult {
  final XFile? file;
  final Uint8List? bytes;

  /// True when the user chose "Choose a file instead" (camera unavailable,
  /// denied, or simply preferred).
  final bool useFileInstead;
  const CameraCaptureResult.photo(XFile this.file, Uint8List this.bytes) : useFileInstead = false;
  const CameraCaptureResult.fileInstead()
      : file = null,
        bytes = null,
        useFileInstead = true;
}

/// In-app camera (decision D4). Used on Flutter Web, where image_picker cannot
/// open a webcam and silently falls back to the file chooser. The browser asks
/// for camera permission only when this screen opens (i.e. after the user
/// tapped "Take photo"). Requires a secure origin (https or localhost).
///
/// Flow: live preview → Capture → Retake / Use photo. If no camera exists or
/// access is denied, a clear message is shown with "Choose a file instead".
class CameraCaptureScreen extends StatefulWidget {
  final String title;
  const CameraCaptureScreen({super.key, this.title = 'Take photo'});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  static const Duration startupTimeout = Duration(seconds: 60);
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  String? _error;
  bool _starting = true;
  bool _capturing = false;
  XFile? _shot;
  Uint8List? _shotBytes;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // On web this also shows the browser permission prompt, so the limit is
      // generous; it only stops an endless spinner if the camera never answers.
      _cameras = await availableCameras().timeout(startupTimeout);
      if (_cameras.isEmpty) {
        _fail('No camera was found on this device.');
        return;
      }
      // Prefer the back camera on phones/tablets, otherwise the first one.
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_controller == null && back >= 0) _cameraIndex = back;
      await _openCamera();
    } on CameraException catch (e) {
      _fail(_messageFor(e));
    } on TimeoutException {
      _fail('The camera did not respond. Check that your browser allowed camera access, then try again.');
    } catch (_) {
      _fail('The camera could not be started on this device.');
    }
  }

  Future<void> _openCamera() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    final c = CameraController(_cameras[_cameraIndex], ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    await c.initialize().timeout(startupTimeout);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _controller = c;
      _starting = false;
    });
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _starting = false;
    });
  }

  static String _messageFor(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission') || code.contains('notallowed')) {
      return 'Camera access was blocked. Allow camera access for this site in your browser (the camera icon in the address bar), then try again.';
    }
    if (code.contains('notfound') || code.contains('notreadable') || code.contains('inuse') || code.contains('abort')) {
      return 'The camera is not available. It may be missing or in use by another app.';
    }
    if (code.contains('notsupported') || code.contains('insecure')) {
      return 'This browser cannot use the camera here. Use https (or localhost) in Chrome, Edge or Safari.';
    }
    return 'The camera could not be started (${e.code}).';
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final f = await c.takePicture();
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _shot = f;
        _shotBytes = bytes;
      });
    } on CameraException catch (e) {
      _fail(_messageFor(e));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _starting = true;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    try {
      await _openCamera();
    } on CameraException catch (e) {
      _fail(_messageFor(e));
    } on TimeoutException {
      _fail('The camera did not respond. Try again or choose a file instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.onInk,
        titleTextStyle: AppTextStyles.headingMedium.copyWith(color: AppColors.onInk),
        actions: [
          if (_shot == null && _error == null && _cameras.length > 1)
            IconButton(tooltip: 'Switch camera', icon: const Icon(Icons.cameraswitch_rounded), onPressed: _starting ? null : _switchCamera),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.onInk),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onInk)),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Choose a file instead',
              icon: Icons.upload_file_rounded,
              onPressed: () => Navigator.pop(context, const CameraCaptureResult.fileInstead()),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _start, child: const Text('Try camera again', style: TextStyle(color: AppColors.onInk))),
          ]),
        ),
      );
    }
    if (_shotBytes != null) {
      return Column(children: [
        Expanded(child: Center(child: Image.memory(_shotBytes!, fit: BoxFit.contain))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: SecondaryButton(
                label: 'Retake',
                icon: Icons.refresh_rounded,
                onPressed: () => setState(() {
                  _shot = null;
                  _shotBytes = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Use photo',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(context, CameraCaptureResult.photo(_shot!, _shotBytes!)),
              ),
            ),
          ]),
        ),
      ]);
    }
    final c = _controller;
    if (_starting || c == null || !c.value.isInitialized) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.onInk),
          SizedBox(height: 14),
          Text('Starting camera… allow access if your browser asks.', style: TextStyle(color: AppColors.onInk)),
        ]),
      );
    }
    return Column(children: [
      Expanded(child: Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: CameraPreview(c)))),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Semantics(
          button: true,
          label: 'Capture photo',
          child: GestureDetector(
            onTap: _capture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary, border: Border.all(color: AppColors.onInk, width: 4)),
              child: _capturing
                  ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                  : const Icon(Icons.camera_alt_rounded, color: AppColors.ink, size: 30),
            ),
          ),
        ),
      ),
    ]);
  }
}
