import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Ấn nút micro để nói giờ báo thức";
  int? _hour;
  int? _minute;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
          });
          _parseTimeAndSetAlarm(result.recognizedWords);
        },
      );
    } else {
      setState(() {
        _text = "Không thể khởi tạo nhận diện giọng nói";
      });
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _parseTimeAndSetAlarm(String input) {
    // Ví dụ: "đặt báo thức lúc 6 giờ 30"
    RegExp regex = RegExp(r'(\d{1,2})\s*(giờ|h)\s*(\d{1,2})?');
    Match? match = regex.firstMatch(input);
    if (match != null) {
      _hour = int.tryParse(match.group(1)!);
      _minute = match.group(3) != null ? int.tryParse(match.group(3)!) : 0;

      if (_hour != null) {
        _setAlarm(_hour!, _minute ?? 0);
      }
    }
  }

  Future<void> _setAlarm(int hour, int minute) async {
    final Uri intentUri = Uri(
      scheme: 'android.intent.action.SET_ALARM',
      queryParameters: {
        'android.intent.extra.alarm.HOUR': hour.toString(),
        'android.intent.extra.alarm.MINUTES': minute.toString(),
        'android.intent.extra.alarm.SKIP_UI': 'false',
      },
    );

    if (await canLaunchUrl(intentUri)) {
      await launchUrl(intentUri);
    } else {
      setState(() {
        _text = "Không mở được ứng dụng đồng hồ";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Báo thức bằng giọng nói")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_text, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            FloatingActionButton(
              onPressed: _isListening ? _stopListening : _startListening,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            ),
          ],
        ),
      ),
    );
  }
}
