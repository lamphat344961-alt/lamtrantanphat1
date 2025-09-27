import 'package:flutter/material.dart';
import "HomeSreen/OneTouch.dart";
import "HomeSreen/InforPage.dart";
import 'HomeSreen/HomePage.dart';
import 'HomeSreen/AlarmPage.dart';
import 'HomeSreen/ScanPage.dart';
import 'HomeSreen/TransPage.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced BottomNav Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  // Các màn hình với state được bảo toàn
  final _pages = const [
    HomePage(),
    AlarmPage(),
    ScanPage(),
    TransPage(),
    OneTouch(),
    InforPage(),
  ];

  // Danh sách tiêu đề cho AppBar
  final _titles = ['Trang chủ', 'Alarm', 'Trans', 'Scan', 'OneTouch', 'Infor'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Quan trọng cho 6 tabs
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 10,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_alarm_outlined),
              activeIcon: Icon(Icons.access_alarm),
              label: 'Alarm',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.translate_outlined,
              ), // Biểu tượng dịch thuật (rỗng)
              activeIcon: Icon(Icons.translate), // Biểu tượng dịch thuật (đầy)
              label: 'Trans',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined), // Biểu tượng tìm kiếm
              activeIcon: Icon(Icons.search),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined), // Icon tuyến đường
              activeIcon: Icon(Icons.route),
              label: 'OneTouch',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              activeIcon: Icon(Icons.people_alt),
              label: 'Infor',
            ),
          ],
        ),
      ),
    );
  }
}

// ====== CÁC MÀN HÌNH DEMO ======
