import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  int _practicesDoneToday = 0;
  final List<Map<String, dynamic>> _dailyPractices = [];
  final List<Map<String, dynamic>> _popularModules = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPracticeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _userData = docSnapshot.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPracticeData() async {
    // This would typically come from your Firestore database
    // For now, we'll use dummy data
    
    // Simulate loading daily practices
    setState(() {
      _dailyPractices.addAll([
        {
          'id': 'practice_e',
          'title': 'Practice E',
          'icon': 'assets/images/practice_e.png',
          'completed': true,
        },
        {
          'id': 'practice_s',
          'title': 'Practice S',
          'icon': 'assets/images/practice_s.png',
          'completed': false,
        },
        {
          'id': 'practice_r',
          'title': 'Practice R',
          'icon': 'assets/images/practice_r.png',
          'completed': false,
        },
      ]);

      _popularModules.addAll([
        {
          'id': 'cards_basic',
          'title': 'Basic Cards',
          'description': 'Practice with basic flashcards',
          'popularity': 98,
        },
        {
          'id': 'pronunciation',
          'title': 'Pronunciation',
          'description': 'Improve your accent',
          'popularity': 87,
        },
      ]);

      // Random number of practices done today (0-3)
      _practicesDoneToday = math.Random().nextInt(4);
    });
  }

  Widget _buildMascot() {
    final bool hasPracticed = _practicesDoneToday > 0;
    final String firstName = _userData?['firstName'] ?? 'there';
    
    // Get the current hour to determine greeting
    final int currentHour = DateTime.now().hour;
    String greeting;
    
    if (currentHour < 12) {
      greeting = 'Good morning';
    } else if (currentHour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mascot image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFEEF2F6),
            ),
            child: Image.asset(
              hasPracticed 
                  ? 'assets/images/lexi_content.jpeg'
                  : 'assets/images/lexi_sad.jpeg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          
          // Mascot message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPracticed 
                      ? '$greeting, $firstName!'
                      : 'Uh oh...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324259),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPracticed
                      ? 'You have done $_practicesDoneToday exercises today.'
                      : "You haven't practiced today.",
                  style: TextStyle(
                    fontSize: 14,
                    color: hasPracticed ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          // No icon or arrow here - clean design
        ],
      ),
    );
  }

  Widget _buildDailyPractices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your daily practices',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324259),
          ),
        ),
        const SizedBox(height: 12),
        
        // Practice items row
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _dailyPractices.length,
            itemBuilder: (context, index) {
              final practice = _dailyPractices[index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.school,
                        color: const Color(0xFF324259),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      practice['title'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (practice['completed'])
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularModules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular exercise modules',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324259),
          ),
        ),
        const SizedBox(height: 12),
        
        // Cards module
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Cards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324259),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Practice with flashcards',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF324259).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Personalized',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF324259),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, String route) {
    // Define if this is the selected item
    final bool isSelected = index == 0; // Home is always selected on this page
    
    return GestureDetector(
      onTap: () {
        if (index != 0) { // Don't navigate if already on home
          Navigator.pushNamed(context, route);
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Top bar with search and profile
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Profile avatar
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF324259),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _userData?['avatarIndex'] != null
                                  ? Image.asset(
                                      'assets/images/avatar${_userData!['avatarIndex'] + 1}.png',
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.person),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main content area with scrolling
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMascot(),
                          const SizedBox(height: 24),
                          _buildDailyPractices(),
                          const SizedBox(height: 24),
                          _buildPopularModules(),
                          const SizedBox(height: 24),
                          
                          // Statistics/Insights section
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.insert_chart_outlined,
                                        color: Color(0xFF324259),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Statistics',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF324259),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Color(0xFF324259),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Insights',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF324259),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
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
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0, '/home'),
            _buildNavItem(Icons.article, 'Tests', 1, '/tests'),
            _buildNavItem(Icons.school, 'Practice', 2, '/practice'),
            _buildNavItem(Icons.dashboard, 'Dashboard', 3, '/dashboard'),
          ],
        ),
      ),
    );
  }
}