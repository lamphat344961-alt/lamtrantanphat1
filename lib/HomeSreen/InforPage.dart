import 'package:flutter/material.dart';

// 1) Model có thêm ảnh (avatar)
class Member {
  final String name;
  final String role;
  final Color color; // dùng để phối sắc nhấn/viền
  final String email;
  final String specialty;
  final String experience;
  final String hobbies;
  final String avatar; // đường dẫn ảnh (asset hoặc URL)

  const Member({
    required this.name,
    required this.role,
    required this.color,
    required this.email,
    required this.specialty,
    required this.experience,
    required this.hobbies,
    required this.avatar,
  });
}

// 2) Trang hiển thị
class InforPage extends StatelessWidget {
  const InforPage({super.key});

  // 3) Dữ liệu cố định cho 3–4 người (avatar là asset minh họa)
  final List<Member> members = const [
    Member(
      name: 'Nguyễn Văn A',
      role: 'Leader',
      color: Colors.blue,
      email: 'vana@example.com',
      specialty: 'Quản lý dự án',
      experience: '5 năm kinh nghiệm trong lĩnh vực IT',
      hobbies: 'Đọc sách, chơi bóng đá',
      avatar: 'assets/image/cusin_1.jpg',
    ),
    Member(
      name: 'Trần Thị B',
      role: 'Developer',
      color: Colors.green,
      email: 'thib@example.com',
      specialty: 'Flutter Developer',
      experience: '2 năm kinh nghiệm Mobile App',
      hobbies: 'Chạy bộ, nghe nhạc',
      avatar: 'assets/image/cusin_1.jpg',
    ),
    Member(
      name: 'Lê Văn C',
      role: 'Designer',
      color: Colors.purple,
      email: 'vanc@example.com',
      specialty: 'UI/UX Design',
      experience: '3 năm kinh nghiệm thiết kế ứng dụng',
      hobbies: 'Vẽ, du lịch, cà phê',
      avatar: 'assets/image/cusin_1.jpg',
    ),
    // Có thể thêm người thứ 4 nếu bạn muốn:
    Member(
      name: 'Lê Văn D',
      role: 'Designer',
      color: Color.fromARGB(255, 180, 8, 8),
      email: 'vanaaac@example.com',
      specialty: 'UI/UX Design',
      experience: '3 năm kinh nghiệm thiết kế ứng dụng',
      hobbies: 'Vẽ, du lịch, cà phê',
      avatar: 'assets/image/cusin_1.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Thông tin nhóm',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lướt qua để xem thông tin từng thành viên',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // PageView hiển thị các thẻ thành viên
          Expanded(
            child: PageView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                return _buildMemberCard(context, members[index]);
              },
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              '← Lướt để xem thành viên khác →',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4) Card: dùng ảnh làm nền, overlay tên/vai trò + chi tiết ngay TRONG ảnh
  Widget _buildMemberCard(BuildContext context, Member m) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Ảnh nền
            Positioned.fill(
              child: Image.asset(
                m.avatar, // nếu muốn dùng URL: Image.network(m.avatar)
                fit: BoxFit.cover,
              ),
            ),

            // Lớp phủ gradient để chữ nổi bật (từ trong suốt -> đen)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                    stops: const [0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Nội dung chữ đè trên ảnh
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên + vai trò (trên cùng, có tag vai trò)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black45),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: m.color.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            m.role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Khối thông tin chi tiết (nằm dưới cùng trong ảnh)
                    _infoPill(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: m.email,
                    ),
                    const SizedBox(height: 8),
                    _infoPill(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Chuyên môn',
                      value: m.specialty,
                    ),
                    const SizedBox(height: 8),
                    _infoPill(
                      icon: Icons.badge_rounded,
                      label: 'Kinh nghiệm',
                      value: m.experience,
                    ),
                    const SizedBox(height: 8),
                    _infoPill(
                      icon: Icons.favorite_rounded,
                      label: 'Sở thích',
                      value: m.hobbies,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5) Widget hiển thị 1 dòng info gọn gàng, dễ đọc trên nền ảnh
  Widget _infoPill({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
