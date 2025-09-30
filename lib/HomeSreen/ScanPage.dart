import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// ML Kit
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Import cho InputImage
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  // ── Tabs: Text | Voice | Image (đã bỏ LiveCam)
  late final TabController _tab = TabController(length: 3, vsync: this);

  // ── Ngôn ngữ
  final Map<String, TranslateLanguage> _langs = const {
    'Việt (vi)': TranslateLanguage.vietnamese,
    'Anh (en)': TranslateLanguage.english,
    'Trung (zh)': TranslateLanguage.chinese,
    'Nhật (ja)': TranslateLanguage.japanese,
    'Hàn (ko)': TranslateLanguage.korean,
    'Thái (th)': TranslateLanguage.thai,
    'Pháp (fr)': TranslateLanguage.french,
  };
  String _fromLabel = 'Việt (vi)';
  String _toLabel = 'Anh (en)';
  TranslateLanguage get _fromLang => _langs[_fromLabel]!;
  TranslateLanguage get _toLang => _langs[_toLabel]!;

  final _modelManager = OnDeviceTranslatorModelManager();
  OnDeviceTranslator? _translator;
  bool _busy = false;

  // ── Text mode
  final _inputCtrl = TextEditingController();
  String _output = '';

  // ── Voice mode
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _engineReady = false;
  bool _hasMicPerm = false;
  bool _listening = false;
  String _voiceRaw = '';
  Timer? _silenceTimer;
  final int _silenceTimeout = 5; // tự dừng sau 5s im lặng

  // ── Image mode
  final ImagePicker _picker = ImagePicker();
  XFile? _picked;
  String _ocrText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _ensureModels(); // tải model cho cặp mặc định
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speech.stop();
    _translator?.close();
    _inputCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ===================== Translation models =====================
  Future<void> _ensureModels() async {
    setState(() => _busy = true);
    try {
      // tải model nguồn nếu chưa có
      if (!await _modelManager.isModelDownloaded(_fromLang.code)) {
        await _modelManager.downloadModel(_fromLang.code);
      }

      // tải model đích nếu chưa có
      if (!await _modelManager.isModelDownloaded(_toLang.code)) {
        await _modelManager.downloadModel(_toLang.code);
      }

      await _translator?.close();
      _translator = OnDeviceTranslator(
        sourceLanguage: _fromLang,
        targetLanguage: _toLang,
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

  Future<void> _translateText(String text) async {
    if (text.trim().isEmpty) return;
    if (_translator == null) await _ensureModels();
    setState(() => _busy = true);
    try {
      final res = await _translator!.translateText(text);
      setState(() => _output = res);
    } catch (e) {
      _snack('Lỗi dịch: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===================== Voice =====================
  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onStatus: (_) {},
      onError: (e) => _snack('STT error: $e'),
      debugLogging: false,
    );
    final perm = await _speech.hasPermission;
    setState(() {
      _engineReady = ready;
      _hasMicPerm = perm;
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: _silenceTimeout), () {
      if (_listening) _stopVoice(listenOnly: true);
    });
  }

  Future<void> _startVoice() async {
    if (!_engineReady) return _snack('Nhận giọng nói chưa sẵn sàng.');
    if (!_hasMicPerm) {
      await _speech.initialize();
      _hasMicPerm = await _speech.hasPermission;
      if (!_hasMicPerm) return _snack('Chưa có quyền micro.');
    }

    setState(() {
      _voiceRaw = '';
      _listening = true;
    });
    _resetSilenceTimer();

    await _speech.listen(
      localeId: 'vi_VN',
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (r) {
        setState(() => _voiceRaw = r.recognizedWords);
        _resetSilenceTimer();
        if (r.finalResult) {
          _stopVoice(listenOnly: true);
          _inputCtrl.text = _voiceRaw;
          _translateText(_voiceRaw);
        }
      },
    );
  }

  Future<void> _stopVoice({bool listenOnly = false}) async {
    await _speech.stop();
    _silenceTimer?.cancel();
    setState(() => _listening = false);
    if (!listenOnly && _voiceRaw.isNotEmpty) {
      _inputCtrl.text = _voiceRaw;
      _translateText(_voiceRaw);
    }
  }

  // ===================== Image / OCR =====================
  Future<void> _pickImage(ImageSource src) async {
    final f = await _picker.pickImage(source: src, imageQuality: 92);
    if (f == null) return;
    setState(() {
      _picked = f;
      _ocrText = '';
    });
    await _runOcrAndTranslate(f);
  }

  Future<void> _runOcrAndTranslate(XFile xf) async {
    setState(() => _busy = true);
    try {
      final input = InputImage.fromFilePath(xf.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(input);

      final buf = StringBuffer();
      for (final block in result.blocks) {
        buf.writeln(block.text);
      }
      await recognizer.close();

      _ocrText = buf.toString().trim();
      _inputCtrl.text = _ocrText;
      if (_ocrText.isEmpty) {
        setState(() => _output = 'Không đọc được chữ trong ảnh.');
      } else {
        await _translateText(_ocrText);
      }
    } catch (e) {
      _snack('Lỗi OCR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===================== UI helpers =====================
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch (Text • Voice • Image)'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'Text'),
            Tab(icon: Icon(Icons.mic), text: 'Voice'),
            Tab(icon: Icon(Icons.image), text: 'Image'),
          ],
        ),
      ),
      body: Column(
        children: [
          _langRow(),
          if (_busy) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_textTab(), _voiceTab(), _imageTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(child: _langDropdown(isFrom: true)),
          IconButton(
            onPressed: () => _switchLangs(from: _toLabel, to: _fromLabel),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Đổi chiều dịch',
          ),
          Expanded(child: _langDropdown(isFrom: false)),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _ensureModels,
            child: const Text('Tải model'),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown({required bool isFrom}) {
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

  Widget _textTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          TextField(
            controller: _inputCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nhập văn bản nguồn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _translateText(_inputCtrl.text),
                icon: const Icon(Icons.translate),
                label: const Text('Dịch'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _inputCtrl.clear();
                  setState(() => _output = '');
                },
                child: const Text('Xóa'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Kết quả:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(_output.isEmpty ? '—' : _output),
          ),
        ],
      ),
    );
  }

  Widget _voiceTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _listening ? null : _startVoice,
                icon: const Icon(Icons.mic),
                label: const Text('Nói (vi_VN)'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _listening ? _stopVoice : null,
                icon: const Icon(Icons.stop),
                label: const Text('Dừng ngay'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Bạn nói:'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_voiceRaw.isEmpty ? '—' : _voiceRaw),
          ),
          const SizedBox(height: 12),
          const Text('Dịch:'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(_output.isEmpty ? '—' : _output),
          ),
          const Spacer(),
          Text(
            _listening
                ? 'Đang nghe… (tự dừng nếu im lặng ${_silenceTimeout}s)'
                : 'Đã dừng',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _imageTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Thư viện'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_picked != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_picked!.path),
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          const Text('Văn bản OCR:'),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_ocrText.isEmpty ? '—' : _ocrText),
          ),
          const SizedBox(height: 12),
          const Text('Dịch:'),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(_output.isEmpty ? '—' : _output),
          ),
        ],
      ),
    );
  }
}

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
        return 'en'; // fallback
    }
  }
}
