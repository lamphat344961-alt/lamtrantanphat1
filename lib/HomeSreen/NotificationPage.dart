import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;

  late TextRecognizer _textRecognizer;

  final _langs = const {
    'Tiếng Việt': TranslateLanguage.vietnamese,
    'Tiếng Anh': TranslateLanguage.english,
    'Tiếng Trung': TranslateLanguage.chinese,
  };

  String _fromLabel = 'Tiếng Anh';
  String _toLabel = 'Tiếng Việt';

  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();

  String _translatedText = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _ensureModels();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _translator?.close();
    super.dispose();
  }

  // ==== Camera khởi tạo ====
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    _initializeControllerFuture = _cameraController!.initialize();
    setState(() {});
  }

  // ==== Tải model dịch nếu chưa có ====
  Future<void> _ensureModels() async {
    setState(() => _busy = true);
    final from = _langs[_fromLabel]!;
    final to = _langs[_toLabel]!;

    if (!await _modelManager.isModelDownloaded(from.code)) {
      await _modelManager.downloadModel(from.code);
    }
    if (!await _modelManager.isModelDownloaded(to.code)) {
      await _modelManager.downloadModel(to.code);
    }

    _translator?.close();
    _translator = OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);

    setState(() => _busy = false);
  }

  // ==== Chụp frame và xử lý OCR + dịch ====
  Future<void> _processFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      final picture = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final fullText = recognizedText.text.trim();
      if (fullText.isEmpty) return;

      final translated = await _translator?.translateText(fullText) ?? '';
      setState(() => _translatedText = translated);
    } catch (e) {
      debugPrint('Lỗi OCR/Dịch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch Real-time bằng Camera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ensureModels,
            tooltip: 'Tải lại model',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            flex: 3,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_cameraController!);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _langDropdown(true)),
                    const SizedBox(width: 8),
                    const Icon(Icons.swap_horiz),
                    const SizedBox(width: 8),
                    Expanded(child: _langDropdown(false)),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _processFrame,
                  icon: const Icon(Icons.camera),
                  label: const Text('Quét & Dịch'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  _translatedText.isEmpty ? 'Chưa có kết quả' : _translatedText,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown(bool isFrom) {
    final value = isFrom ? _fromLabel : _toLabel;
    return DropdownButtonFormField<String>(
      value: value,
      items: _langs.keys
          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          if (isFrom) {
            _fromLabel = v;
          } else {
            _toLabel = v;
          }
          _ensureModels();
        });
      },
      decoration: InputDecoration(
        labelText: isFrom ? 'Từ' : 'Sang',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

// ==== Extension: enum → String code ====
extension TranslateLangCode on TranslateLanguage {
  String get code {
    switch (this) {
      case TranslateLanguage.vietnamese:
        return 'vi';
      case TranslateLanguage.english:
        return 'en';
      case TranslateLanguage.chinese:
        return 'zh';
      default:
        return 'en';
    }
  }
}
