import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home_page.dart';
import 'tests.dart';
import 'practice_modules.dart';
import 'dashboard.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  
  // List of pages to display in the tabs
  // For now we'll just use the first two pages until the others are created
  late final List<Widget> _pages;
  
  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const TestsPage(),
      const PracticeModulesScreen(),
      const DashboardPage(),
    ];
  }

  @override
Widget build(BuildContext context) {
  // Get the bottom padding from MediaQuery to account for system navigation
  final bottomPadding = MediaQuery.of(context).padding.bottom;
  
  return Scaffold(
    // We use IndexedStack to maintain the state of each tab
    body: IndexedStack(
      index: _currentIndex,
      children: _pages,
    ),
    // Bottom navigation bar with consistent styling
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // Add the bottom padding to your existing height
      height: 60 + bottomPadding,
      child: Padding(
        // Add padding at the bottom to push your content above the system nav bar
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.article, 'Tests', 1),
            _buildNavItem(Icons.school, 'Practice', 2),
            _buildNavItem(Icons.dashboard, 'Dashboard', 3),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = index == _currentIndex;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        height: 40,
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F5377) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}