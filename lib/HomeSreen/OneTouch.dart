import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import gói url_launcher

class OneTouch extends StatelessWidget {
  const OneTouch({super.key});

  // Số điện thoại bạn muốn gọi
  final String phoneNumber =
      'tel:+84123456789'; // Thay thế bằng số điện thoại mong muốn, kèm mã quốc gia

  // URL của video YouTube
  final String youtubeVideoUrl =
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ'; // Thay thế bằng URL video YouTube của bạn

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nút gọi điện
          ElevatedButton.icon(
            onPressed: () async {
              final Uri launchUri = Uri.parse(phoneNumber);
              if (!await launchUrl(launchUri)) {
                // Xử lý lỗi nếu không thể mở trình quay số
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không thể mở trình quay số.')),
                );
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text('Gọi Điện Ngay'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 20), // Khoảng cách giữa các nút
          // Nút mở video YouTube
          ElevatedButton.icon(
            onPressed: () async {
              final Uri launchUri = Uri.parse(youtubeVideoUrl);
              if (!await launchUrl(
                launchUri,
                mode: LaunchMode.externalApplication,
              )) {
                // Xử lý lỗi nếu không thể mở YouTube
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không thể mở video YouTube.')),
                );
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Xem Video YouTube'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
              backgroundColor: Colors.red, // Màu sắc nổi bật cho YouTube
            ),
          ),
        ],
      ),
    );
  }
}
