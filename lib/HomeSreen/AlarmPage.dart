import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:android_intent_plus/android_intent.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});
  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  // Speech
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _engineReady = false;
  bool _hasMicPerm = false;
  bool _listening = false;

  // Silence auto-stop
  Timer? _silenceTimer;
  final int _silenceTimeout = 3; // giây im lặng
  double _soundLevel = 0;

  // UI state
  String _recognized = '';
  String _status = 'Nhấn mic và nói: “7 giờ 30 sáng”, “9 giờ tối”, “6 rưỡi”…';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  // ==== SPEECH ====
  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onStatus: (s) => setState(() => _status = 'STT: $s'),
      onError: (e) => setState(() => _status = 'Lỗi STT: $e'),
      debugLogging: false,
    );
    final perm = await _speech.hasPermission;
    setState(() {
      _engineReady = ready;
      _hasMicPerm = perm;
      if (ready && perm) _status = 'Sẵn sàng. Nhấn mic để nói.';
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: _silenceTimeout), () {
      if (_listening) {
        _stopListen();
        setState(() => _status = 'Tự dừng sau $_silenceTimeout giây im lặng');
      }
    });
  }

  Future<void> _startListen() async {
    if (!_engineReady) {
      setState(() => _status = 'STT chưa sẵn sàng.');
      return;
    }
    if (!_hasMicPerm) {
      final ok = await _speech.initialize();
      _hasMicPerm = await _speech.hasPermission;
      if (!_hasMicPerm) {
        setState(() => _status = 'Chưa có quyền micro.');
        return;
      }
    }

    setState(() {
      _recognized = '';
      _listening = true;
      _status = 'Đang nghe…';
    });

    _resetSilenceTimer();

    await _speech.listen(
      localeId: 'vi_VN',
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (r) {
        setState(() => _recognized = r.recognizedWords);
        _resetSilenceTimer(); // có âm → reset

        if (r.finalResult) {
          _listening = false;
          _speech.stop();
          _silenceTimer?.cancel();
          _handleRecognized(_recognized);
        }
      },
      // 7.3.0: callback 1 tham số
      onSoundLevelChange: (double level) {
        _soundLevel = level;
        if (level > 0.02) _resetSilenceTimer();
        setState(() {});
      },
    );
  }

  Future<void> _stopListen() async {
    await _speech.stop();
    _silenceTimer?.cancel();
    setState(() => _listening = false);
  }

  Future<void> _handleRecognized(String text) async {
    setState(() => _status = 'Bạn nói: “$text”. Đang phân tích giờ…');

    final t = _parseTimeVi(text);
    if (t == null) {
      setState(
        () => _status =
            'Không hiểu giờ từ câu nói. Mở danh sách báo thức để chỉnh tay.',
      );
      await _openShowAlarms();
      return;
    }

    final h = t.hour;
    final m = t.minute;
    setState(() => _status = 'Đặt báo thức: ${_two(h)}:${_two(m)}');

    await _setAlarmAndroid(
      hour: h,
      minute: m,
      message: 'Báo thức từ giọng nói',
      skipUi: true, // có máy sẽ mở UI xác nhận
    );
  }

  // ==== ANDROID INTENTS ====
  Future<void> _openShowAlarms() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(action: 'android.intent.action.SHOW_ALARMS');
    await intent.launch();
  }

  Future<void> _setAlarmAndroid({
    required int hour,
    required int minute,
    String message = 'Alarm',
    bool skipUi = false,
  }) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': message,
        'android.intent.extra.alarm.SKIP_UI': skipUi,
      },
    );
    await intent.launch();
  }

  // ==== PARSE "GIỜ" TIẾNG VIỆT (đã fix "12 giờ") ====
  ({int hour, int minute})? _parseTimeVi(String input) {
    var s = input.toLowerCase().trim();

    // 1) chuẩn hoá số tiếng Việt theo ranh giới từ & đúng thứ tự ưu tiên
    s = _normalizeVietnameseNumbers(s);

    // 2) gom khoảng trắng
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 3) h:mm / h mm / h giờ mm
    final reHM = RegExp(r'\b(\d{1,2})\s*(?:[:h]|(?:\s*giờ\s*))\s*(\d{1,2})\b');
    final mHM = reHM.firstMatch(s);
    if (mHM != null) {
      var h = int.parse(mHM.group(1)!);
      var m = int.parse(mHM.group(2)!);
      (h, m) = _applyAmPm(h, m, s);
      if (_valid(h, m)) return (hour: h, minute: m);
    }

    // 4) "kém" -> 10 giờ kém 15 = 09:45
    final reKem = RegExp(r'\b(\d{1,2})\s*(?:giờ|h)\s*kém\s*(\d{1,2})\b');
    final mKem = reKem.firstMatch(s);
    if (mKem != null) {
      var h = int.parse(mKem.group(1)!);
      final sub = int.parse(mKem.group(2)!);
      var m = (60 - (sub % 60)) % 60;
      if (m != 0) h = (h - 1) < 0 ? 23 : (h - 1);
      (h, m) = _applyAmPm(h, m, s);
      if (_valid(h, m)) return (hour: h, minute: m);
    }

    // 5) "rưỡi" -> 6 rưỡi = 6:30
    if (s.contains('rưỡi')) {
      final mh = RegExp(r'\b(\d{1,2})\b').firstMatch(s);
      if (mh != null) {
        var h = int.parse(mh.group(1)!);
        var m = 30;
        (h, m) = _applyAmPm(h, m, s);
        if (_valid(h, m)) return (hour: h, minute: m);
      }
    }

    // 6) giờ tròn: "12 giờ", "19h"
    final reHourOnly = RegExp(r'\b(\d{1,2})\s*(?:giờ|h)\b');
    final mH = reHourOnly.firstMatch(s);
    if (mH != null) {
      var h = int.parse(mH.group(1)!);
      var m = 0;
      (h, m) = _applyAmPm(h, m, s);
      if (_valid(h, m)) return (hour: h, minute: m);
    }

    // 7) fallback: chỉ số đơn lẻ
    final lone = RegExp(r'\b(\d{1,2})\b').firstMatch(s);
    if (lone != null) {
      var h = int.parse(lone.group(1)!);
      var m = s.contains('rưỡi') ? 30 : 0;
      (h, m) = _applyAmPm(h, m, s);
      if (_valid(h, m)) return (hour: h, minute: m);
    }

    return null;
  }

  String _normalizeVietnameseNumbers(String s) {
    final repl = <RegExp, String>{
      RegExp(r'\bmười hai\b'): '12',
      RegExp(r'\bmười một\b'): '11',
      RegExp(r'\bmười\b'): '10',
      RegExp(r'\bchín\b'): '9',
      RegExp(r'\btám\b'): '8',
      RegExp(r'\bbảy\b|\bbẩy\b'): '7',
      RegExp(r'\bsáu\b'): '6',
      RegExp(r'\bnăm\b|\blăm\b'): '5',
      RegExp(r'\bbốn\b|\btư\b'): '4',
      RegExp(r'\bba\b'): '3',
      RegExp(r'\bhai\b'): '2',
      RegExp(r'\bmột\b|\bmốt\b'): '1',
    };
    repl.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  (int, int) _applyAmPm(int h, int m, String s) {
    final pmHint =
        s.contains('tối') ||
        s.contains('chiều') ||
        s.contains('trưa') ||
        s.contains('pm');
    final amHint =
        s.contains('sáng') ||
        s.contains('khuya') ||
        s.contains('đêm') ||
        s.contains('am');

    if (pmHint) {
      if (h >= 1 && h <= 11) h += 12; // 1..11 -> 13..23
      // h==12 (trưa) giữ nguyên 12
    }
    if (amHint) {
      if (h == 12) h = 0; // 12 sáng -> 00
    }
    return (h, m);
  }

  bool _valid(int h, int m) => h >= 0 && h <= 23 && m >= 0 && m <= 59;
  String _two(int n) => n.toString().padLeft(2, '0');

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt báo thức bằng giọng nói')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _recognized.isEmpty ? '(chưa có nội dung)' : _recognized,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _soundLevel.clamp(0, 1.0),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              _listening
                  ? 'Đang nghe… (tự dừng nếu im lặng $_silenceTimeout giây)'
                  : 'Đã dừng',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _listening ? null : _startListen,
                  icon: const Icon(Icons.mic),
                  label: const Text('Nói giờ (vi_VN)'),
                ),
                OutlinedButton.icon(
                  onPressed: _listening ? _stopListen : _openShowAlarms,
                  icon: Icon(_listening ? Icons.stop : Icons.alarm),
                  label: Text(_listening ? 'Dừng ngay' : 'Mở báo thức'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
