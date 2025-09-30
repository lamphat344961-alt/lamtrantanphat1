import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class TransPage extends StatefulWidget {
  const TransPage({super.key});

  @override
  State<TransPage> createState() => _TransPageState();
}

class _TransPageState extends State<TransPage> with WidgetsBindingObserver {
  // Camera & OCR
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  final TextRecognizer _liveRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // Translation
  final _langs = const {
    'Tiếng Việt': TranslateLanguage.vietnamese,
    'Tiếng Anh': TranslateLanguage.english,
    'Tiếng Trung': TranslateLanguage.chinese,
    'Tiếng Nhật': TranslateLanguage.japanese,
    'Tiếng Hàn': TranslateLanguage.korean,
    'Tiếng Thái': TranslateLanguage.thai,
    'Tiếng Pháp': TranslateLanguage.french,
  };

  String _fromLabel = 'Tiếng Anh';
  String _toLabel = 'Tiếng Việt';

  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();

  // State
  String _liveOcr = '';
  String _translatedText = '';
  bool _busy = false;
  bool _liveBusy = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureModels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveCam();
    _liveRecognizer.close();
    _translator?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null) return;
    if (state == AppLifecycleState.inactive) {
      try {
        if (c.value.isStreamingImages) c.stopImageStream();
      } catch (_) {}
    }
  }

  // ==== Tải model dịch ====
  Future<void> _ensureModels() async {
    setState(() => _busy = true);
    try {
      final from = _langs[_fromLabel]!;
      final to = _langs[_toLabel]!;

      if (!await _modelManager.isModelDownloaded(from.code)) {
        await _modelManager.downloadModel(from.code);
      }
      if (!await _modelManager.isModelDownloaded(to.code)) {
        await _modelManager.downloadModel(to.code);
      }

      await _translator?.close();
      _translator = OnDeviceTranslator(
        sourceLanguage: from,
        targetLanguage: to,
      );
    } catch (e) {
      _snack('Lỗi tải model: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchLangs({required String from, required String to}) async {
    setState(() {
      _fromLabel = from;
      _toLabel = to;
    });
    await _ensureModels();
  }

  // ==== LiveCam OCR ====
  Future<void> _startLiveCam() async {
    try {
      if (_translator == null) await _ensureModels();

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _snack('Không tìm thấy camera.');
        return;
      }

      final cam = _cameras.first;
      _cam = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cam!.initialize();

      // Bắt đầu stream
      await _cam!.startImageStream((image) {
        if (_liveBusy) return;
        _liveBusy = true;
        _processLiveFrame(image, cam).whenComplete(() {
          Future.delayed(const Duration(milliseconds: 600), () {
            _liveBusy = false;
          });
        });
      });

      setState(() => _isStreaming = true);
    } catch (e) {
      _snack('Không mở được camera: $e');
    }
  }

  Future<void> _stopLiveCam() async {
    try {
      if (_cam != null) {
        if (_cam!.value.isStreamingImages) {
          await _cam!.stopImageStream();
        }
        await _cam!.dispose();
      }
    } catch (_) {}
    _cam = null;
    setState(() {
      _isStreaming = false;
      _liveOcr = '';
      _translatedText = '';
    });
  }

  Future<void> _processLiveFrame(
    CameraImage image,
    CameraDescription desc,
  ) async {
    try {
      final input = _inputImageFromCameraImage(image, desc);
      if (input == null) return;

      final result = await _liveRecognizer.processImage(input);

      final buf = StringBuffer();
      for (final b in result.blocks) {
        buf.writeln(b.text);
      }
      final raw = buf.toString().trim();

      if (!mounted) return;
      setState(() => _liveOcr = raw);

      if (raw.isNotEmpty) {
        final translated = await _translator!.translateText(raw);
        if (!mounted) return;
        setState(() => _translatedText = translated);
      } else {
        if (!mounted) return;
        setState(() => _translatedText = '');
      }
    } catch (_) {
      // Bỏ qua lỗi để không crash
    }
  }

  // CameraImage -> InputImage
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription description,
  ) {
    try {
      final sensorOrientation = description.sensorOrientation;
      InputImageRotation? rotation;

      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation = 0;
        if (description.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }

      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      if (format == null ||
          (Platform.isAndroid && format != InputImageFormat.nv21) ||
          (Platform.isIOS && format != InputImageFormat.bgra8888)) {
        return null;
      }

      if (image.planes.length != 1) return null;
      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    final isReady = _cam != null && _cam!.value.isInitialized;

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
          // Language selector
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _langDropdown(true)),
                IconButton(
                  onPressed: () => _switchLangs(from: _toLabel, to: _fromLabel),
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Đổi chiều dịch',
                ),
                Expanded(child: _langDropdown(false)),
              ],
            ),
          ),

          if (_busy) const LinearProgressIndicator(minHeight: 3),

          // Camera preview
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: isReady
                      ? AspectRatio(
                          aspectRatio: _cam!.value.aspectRatio,
                          child: CameraPreview(_cam!),
                        )
                      : Center(
                          child: FilledButton.icon(
                            onPressed: _startLiveCam,
                            icon: const Icon(Icons.videocam),
                            label: const Text('Bắt đầu LiveCam OCR'),
                          ),
                        ),
                ),
                if (isReady)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // OCR text preview
          if (_isStreaming)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Văn bản nhận diện:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _liveOcr.isEmpty ? 'Đang quét...' : _liveOcr,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Translation result
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kết quả dịch:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isStreaming)
                        OutlinedButton.icon(
                          onPressed: _stopLiveCam,
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Dừng'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _translatedText.isEmpty
                            ? 'Chưa có kết quả'
                            : _translatedText,
                        style: const TextStyle(fontSize: 18, height: 1.5),
                      ),
                    ),
                  ),
                ],
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
        _switchLangs(from: isFrom ? v : _fromLabel, to: isFrom ? _toLabel : v);
      },
      decoration: InputDecoration(
        labelText: isFrom ? 'Từ' : 'Sang',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

// ==== Extension ====
extension TranslateLangCode on TranslateLanguage {
  String get code {
    switch (this) {
      case TranslateLanguage.vietnamese:
        return 'vi';
      case TranslateLanguage.english:
        return 'en';
      case TranslateLanguage.chinese:
        return 'zh';
      case TranslateLanguage.japanese:
        return 'ja';
      case TranslateLanguage.korean:
        return 'ko';
      case TranslateLanguage.thai:
        return 'th';
      case TranslateLanguage.french:
        return 'fr';
      default:
        return 'en';
    }
  }
}
