import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import gói url_launcher

class OneTouch extends StatefulWidget {
  const OneTouch({super.key});

  @override
  State<OneTouch> createState() => _OneTouchState();
}

class _OneTouchState extends State<OneTouch> {
  // Controller để lấy dữ liệu từ TextField
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  // Hàm gọi điện
  Future<void> _makePhoneCall(BuildContext context) async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại')),
      );
      return;
    }

    // Format chuẩn: tel:+84...
    final Uri launchUri = Uri.parse('tel:$phone');

    if (!await launchUrl(launchUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở trình quay số.')),
      );
    }
  }

  // Hàm mở video YouTube
  Future<void> _openYoutube(BuildContext context) async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập URL YouTube')),
      );
      return;
    }

    final Uri launchUri = Uri.parse(url);

    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở video YouTube.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneTouch Action'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ô nhập số điện thoại
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nhập số điện thoại',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Ví dụ: +84123456789',
              ),
            ),
            const SizedBox(height: 20),

            // Ô nhập URL YouTube
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Nhập URL YouTube',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Ví dụ: https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              ),
            ),
            const SizedBox(height: 30),

            // Nút gọi điện
            ElevatedButton.icon(
              onPressed: () => _makePhoneCall(context),
              icon: const Icon(Icons.phone),
              label: const Text('Gọi điện ngay'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Nút mở YouTube
            ElevatedButton.icon(
              onPressed: () => _openYoutube(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mở video YouTube'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
