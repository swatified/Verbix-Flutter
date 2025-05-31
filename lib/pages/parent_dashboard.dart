import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'wrong_word_details.dart';
import 'parent_child_dashboard.dart';
import '../services/gemini_service.dart';
import '../services/daily_scoring_service.dart';
import 'auth_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String _parentName = '';
  String _childLevel = 'Loading...';
  List<Map<String, dynamic>> _recentTroubles = [];
  String _patternBreakdown = 'Loading pattern analysis...';
  bool _isLoading = true;
  String _childId = '';

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _loadParentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load parent profile
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .get();

        if (parentDoc.exists) {
          setState(() {
            _parentName = parentDoc.data()?['name'] ?? 'Parent';
          });

          // Find child account with the same email
          final email = user.email;
          if (email != null) {
            final childQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            
            if (childQuery.docs.isNotEmpty) {
              final childId = childQuery.docs.first.id;
              await _loadChildData(childId);
            }
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading parent data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildData(String childId) async {
    try {
      // Load child profile
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();

      if (childDoc.exists) {
        // Get child's current level
        setState(() {
          _childLevel = childDoc.data()?['level'] ?? 'Beginner';
          _childId = childId;
        });

        // Get today's date in the format used in Firestore
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        // Get today's incorrect attempts
        final attemptsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .collection('daily_score')
            .doc(dateStr)
            .collection('attempts')
            .where('isCorrect', isEqualTo: false)
            .get();

        final troublesList = attemptsSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'word': doc.data()['wordOrText'] ?? 'Unknown',
            'practiceType': doc.data()['practiceType'] ?? 'Unknown',
            'timestamp': doc.data()['timestamp'] ?? Timestamp.now(),
          };
        }).toList();

        // Generate pattern breakdown using test data for now
        // This would be replaced with a Gemini API call
        final patternBreakdown = _generatePatternBreakdown(troublesList);

        setState(() {
          _recentTroubles = troublesList;
          _patternBreakdown = patternBreakdown;
        });
      }
    } catch (e) {
      print('Error loading child data: $e');
    }
  }

  String _generatePatternBreakdown(List<Map<String, dynamic>> troubles) {
    // This is a placeholder - in production, call the Gemini API
    if (troubles.isEmpty) {
      return 'Not enough data to generate a pattern breakdown. Encourage your child to practice more.';
    }
    
    // In a real implementation, this would call GeminiService.generatePatternBreakdown(troubles)
    // For now, we return a static message to avoid API costs during development
    return 'The child struggles to form b and d and often '
        'confuses between similar sounding sounds like s and sh. '
        'They repeatedly fail to speak "ay" end words correctly.';
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // Navigate to AuthScreen after signing out
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String greeting = _getGreeting();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF455A64)),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGreetingCard(),
                    const SizedBox(height: 16),
                    _buildLevelCard(),
                    const SizedBox(height: 16),
                    _buildRecentTroublesCard(),
                    const SizedBox(height: 16),
                    _buildPatternBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildProgressDashboardCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGreetingCard() {
    String greeting = _getGreeting();
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/parent_lexi.webp',
                height: 120,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF324259),
                    ),
                  ),
                  Text(
                    _parentName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF324259),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    // Get the level info based on the child's level
    final levelString = _childLevel.toLowerCase();
    DifficultyLevel childLevel = DifficultyLevel.easy; // Default to easy
    
    // Map the string level to DifficultyLevel enum
    if (levelString.contains('medium')) {
      childLevel = DifficultyLevel.medium;
    } else if (levelString.contains('hard')) {
      childLevel = DifficultyLevel.hard;
    }
    
    final levelInfo = DailyScoringService.getLevelDisplayInfo(childLevel);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: (levelInfo['color'] as Color).withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: (levelInfo['color'] as Color).withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Your child\'s current level is "${levelInfo['name']}"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF455A64),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/books.webp',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTroublesCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color.fromARGB(98, 154, 151, 151), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Incorrect Attempts:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF455A64),
              ),
            ),
            const SizedBox(height: 16),
            ..._recentTroubles.isEmpty
                ? [const Text('No incorrect attempts recorded today')]
                : _recentTroubles.map((trouble) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          trouble['word'],
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          'Practice Type: ${trouble['practiceType']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          _navigateToWordDetails(trouble);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }).toList(),
          ],
        ),
      ),
    );
  }

  void _navigateToWordDetails(Map<String, dynamic> trouble) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WrongWordDetailsScreen(
          childId: _childId,
          wordId: trouble['id'],
          word: trouble['word'],
        ),
      ),
    );
  }

  Widget _buildPatternBreakdownCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: const Color.fromARGB(182, 239, 239, 214), // Light beige
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color.fromARGB(100, 166, 155, 99)!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pattern Breakdown:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF455A64),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _patternBreakdown,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF455A64),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDashboardCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: const Color.fromARGB(88, 197, 223, 214), // Darker green-gray as requested
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color.fromARGB(100, 86, 112, 104)!, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentChildDashboardScreen(childId: _childId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text(
                'Progress Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF455A64),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.trending_up,
                size: 40,
                color: Color(0xFF324259), // Dark blue/gray color
              ),
            ],
          ),
        ),
      ),
    );
  }
} 