import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:verbix/services/custom_practice_service.dart'
    as practice_service;
import 'package:verbix/services/daily_scoring_service.dart';
import 'package:verbix/services/practice_module_service.dart';

import 'module_details.dart';
import 'practice_screen.dart';
import 'user_settings.dart';

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
  int _modulesCompletedToday = 0;
  int _practicesCompletedToday = 0;
  List<practice_service.PracticeModule> _dailyPractices = [];
  List<PracticeModule> _popularModules = [];
  DifficultyLevel _currentLevel = DifficultyLevel.easy;
  DailyScore? _todayScore;
  bool _isLoadingLevel = true;

  @override
  void initState() {
    super.initState();
    _checkFirestoreData();
    _loadUserData();
    _loadPracticeData();
    _loadLevelAndScore();

    PracticeModuleService.moduleStream.listen((modules) {
      _loadPopularModules();
      _loadModulesCompletedToday();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedPractices();
      _saveUserProgressData();
    });
  }

  @override
  void dispose() {
    _saveUserProgressData();
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

      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (docSnapshot.exists) {
        if (!mounted) return;
        setState(() {
          _userData = docSnapshot.data();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: ${e.toString()}')),
      );
    } finally {}
  }

  Future<void> _loadPracticeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('progress')
              .orderBy(FieldPath.documentId, descending: true)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        if (!mounted) return;
        setState(() {
          _practicesDoneToday = doc.data()['daily_practices'] ?? 0;
          _modulesCompletedToday = doc.data()['modules_completed'] ?? 0;
          _practicesCompletedToday = doc.data()['practice_modules'] ?? 0;
        });
      } else {
        setState(() {
          _practicesDoneToday = 0;
          _modulesCompletedToday = 0;
          _practicesCompletedToday = 0;
        });
      }

      _saveUserProgressData();

      final practices =
          await practice_service.CustomPracticeService.fetchPractices();

      if (practices.isEmpty || _shouldRefreshPractices(practices)) {
        final newPractices =
            await practice_service
                .CustomPracticeService.generateCustomPractices();
        await practice_service.CustomPracticeService.savePractices(
          newPractices,
        );
        if (!mounted) return;
        setState(() {
          _dailyPractices = newPractices;
          _practicesDoneToday = _countCompletedPractices(newPractices);
        });
      } else {
        setState(() {
          _dailyPractices = practices;
          _practicesDoneToday = _countCompletedPractices(practices);
        });
      }

      await _loadPopularModules();
      await _loadModulesCompletedToday();
      await _loadCompletedPractices();
      await _saveUserProgressData();
    } catch (e) {
      debugPrint('ERROR loading practices: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading practices: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserProgressData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User is null - cannot save progress');
        return;
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final total =
          _practicesDoneToday +
          _modulesCompletedToday +
          _practicesCompletedToday;

      final progressData = {
        'date': dateStr,
        'practice_done': total,
        'daily_practices': _practicesDoneToday,
        'modules_completed': _modulesCompletedToday,
        'practice_modules': _practicesCompletedToday,
        'last_updated': FieldValue.serverTimestamp(),
      };

      debugPrint('Saving progress data: $progressData');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc(dateStr)
          .set(progressData, SetOptions(merge: true));

      debugPrint('Progress successfully saved to Firestore');

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('progress')
              .doc(dateStr)
              .get();

      if (doc.exists) {
        debugPrint('Verification read successful:');
        debugPrint('   Saved data: ${doc.data()}');
      } else {
        debugPrint('Verification failed - document not found');
      }
    } catch (e) {
      debugPrint('ERROR saving progress: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving progress: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkFirestoreData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('progress')
              .doc(dateStr)
              .get();

      debugPrint('🔍 Current Firestore data for today:');
      if (doc.exists) {
        debugPrint(doc.data().toString());
      } else {
        debugPrint('No document found for today');
      }
    } catch (e) {
      debugPrint('Error checking Firestore data: $e');
    }
  }

  Future<void> _loadPopularModules() async {
    try {
      final popularModules = await PracticeModuleService.getPopularModules();
      if (!mounted) return;
      setState(() {
        _popularModules = popularModules;
      });
    } catch (e) {
      debugPrint('Error loading popular modules: $e');
    }
  }

  Future<void> _saveDailyProgress({
    required List<practice_service.PracticeModule> practices,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = DateFormat('yyyy-MM-dd').format(yesterday);

      final completed =
          practices.where((practice) => practice.completed).length;
      final total = practices.length;

      await FirebaseFirestore.instance
          .collection('dailyProgress')
          .doc('${user.uid}_$dateStr')
          .set({
            'userId': user.uid,
            'date': dateStr,
            'completed': completed,
            'total': total,
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('Saved daily progress: $completed/$total for $dateStr');
    } catch (e) {
      debugPrint('Error saving daily progress: $e');
    }
  }

  Future<void> _loadModulesCompletedToday() async {
    try {
      final completedCount =
          await PracticeModuleService.getCompletedModulesToday();
      if (!mounted) return;
      setState(() {
        _modulesCompletedToday = completedCount;
      });
    } catch (e) {
      debugPrint('Error loading completed modules: $e');
    }
  }

  Future<void> _loadCompletedPractices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('userStats')
              .orderBy(FieldPath.documentId, descending: true)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        if (!mounted) return;
        setState(() {
          _practicesCompletedToday = doc.data()['completedPractices'] ?? 0;
        });
      } else {
        setState(() {
          _practicesCompletedToday = 0;
        });
        debugPrint(
          'No historical completed practices found. Initializing to 0.',
        );
      }
    } catch (e) {
      debugPrint('Error loading completed practices: $e');
      setState(() {
        _practicesCompletedToday = 0;
      });
    }
  }

  bool _shouldRefreshPractices(
    List<practice_service.PracticeModule> practices,
  ) {
    if (practices.isEmpty) return true;

    final latestPractice = practices.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );

    if (DateTime.now().difference(latestPractice.createdAt).inDays > 7) {
      _saveDailyProgress(practices: practices);
      return true;
    }

    final today = DateTime.now();
    final createdDate = latestPractice.createdAt;

    final needsRefresh =
        today.year != createdDate.year ||
        today.month != createdDate.month ||
        today.day != createdDate.day;

    if (needsRefresh) {
      _saveDailyProgress(practices: practices);
    }

    return needsRefresh;
  }

  int _countCompletedPractices(
    List<practice_service.PracticeModule> practices,
  ) {
    return practices.where((practice) => practice.completed).length;
  }

  Widget _buildMascot() {
    final bool hasPracticed = _practicesDoneToday > 0;
    final String firstName = _userData?['firstName'] ?? 'there';

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
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEEF2F6),
                ),
                child: Image.asset(
                  hasPracticed
                      ? 'assets/images/lexi_content.webp'
                      : 'assets/images/lexi_sad.webp',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPracticed)
                      Text(
                        '$greeting, $firstName!',
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324259),
                        ),
                      )
                    else
                      const Text(
                        'Uh oh...',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324259),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      hasPracticed
                          ? ''
                          : "You haven't completed any practices today.",
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            hasPracticed ? Colors.green[700] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_modulesCompletedToday > 0 || _practicesCompletedToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: [
                  if (_modulesCompletedToday > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'You completed $_modulesCompletedToday ${_modulesCompletedToday == 1 ? 'module' : 'modules'} today!',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF324259),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_practicesCompletedToday > 0)
                    Container(
                      width: double.infinity,
                      margin:
                          _modulesCompletedToday > 0
                              ? const EdgeInsets.only(top: 8.0)
                              : EdgeInsets.zero,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You completed $_practicesCompletedToday ${_practicesCompletedToday == 1 ? 'practice' : 'practices'} today!',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF324259),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getPracticeIcon(practice_service.PracticeType type) {
    switch (type) {
      case practice_service.PracticeType.letterWriting:
        return Icons.text_fields;
      case practice_service.PracticeType.sentenceWriting:
        return Icons.short_text;
      case practice_service.PracticeType.phonetic:
        return Icons.record_voice_over;
      case practice_service.PracticeType.letterReversal:
        return Icons.compare_arrows;
      case practice_service.PracticeType.vowelSounds:
        return Icons.volume_up;
    }
  }

  Widget _buildDailyPractices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your daily practices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324259),
              ),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                try {
                  final newPractices =
                      await practice_service
                          .CustomPracticeService.generateCustomPractices();
                  await practice_service.CustomPracticeService.savePractices(
                    newPractices,
                  );
                  if (!mounted) return;
                  setState(() {
                    _dailyPractices = newPractices;
                    _practicesDoneToday = _countCompletedPractices(
                      newPractices,
                    );
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error refreshing practices: ${e.toString()}',
                      ),
                    ),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          child:
              _dailyPractices.isEmpty
                  ? const Center(child: Text('No practices available'))
                  : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dailyPractices.length,
                    itemBuilder: (context, index) {
                      final practice = _dailyPractices[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      PracticeScreen(practice: practice),
                            ),
                          ).then((_) => _loadPracticeData());
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  practice.completed
                                      ? Colors.green.withValues(alpha: 0.5)
                                      : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getPracticeIcon(practice.type),
                                  color:
                                      practice.completed
                                          ? Colors.green
                                          : const Color(0xFF324259),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  practice.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (practice.completed)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                            ],
                          ),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324259),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child:
              _popularModules.isEmpty
                  ? const Center(child: Text('No modules available'))
                  : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularModules.length,
                    itemBuilder: (context, index) {
                      final module = _popularModules[index];
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.70,
                        margin: const EdgeInsets.only(right: 16),
                        child: Card(
                          elevation: 2,
                          color: const Color.fromARGB(255, 233, 240, 252),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ModuleDetailScreen(
                                        module: module,
                                        onProgressUpdate: (completed) {
                                          PracticeModuleService.updateModuleProgress(
                                            module.id,
                                            completed,
                                          );
                                        },
                                      ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          module.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              module.type == ModuleType.written
                                                  ? Colors.blue.withValues(
                                                    alpha: 0.2,
                                                  )
                                                  : Colors.green.withValues(
                                                    alpha: 0.2,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          module.type == ModuleType.written
                                              ? "Written"
                                              : "Speech",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                module.type ==
                                                        ModuleType.written
                                                    ? Colors.blue
                                                    : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    module.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Progress: ${module.completedExercises}/${module.totalExercises}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${(module.progressPercentage * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: module.progressPercentage,
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          205,
                                          205,
                                          206,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              module.progressPercentage == 1.0
                                                  ? const Color.fromARGB(
                                                    255,
                                                    84,
                                                    156,
                                                    86,
                                                  )
                                                  : Colors.blue,
                                            ),
                                        minHeight: 5,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Future<void> _loadLevelAndScore() async {
    setState(() {
      _isLoadingLevel = true;
    });

    try {
      await DailyScoringService.checkAndProcessDayTransition();

      final level = await DailyScoringService.getCurrentUserLevel();

      final score = await DailyScoringService.getTodayScore();

      if (!mounted) return;
      setState(() {
        _currentLevel = level;
        _todayScore = score;
        _isLoadingLevel = false;
      });

      debugPrint('Loaded level: ${level.toString().split('.').last}');
      if (score != null) {
        debugPrint(
          'Today\'s score: ${score.correctAnswers}/${score.totalAttempts} (${(score.accuracy * 100).toStringAsFixed(1)}%)',
        );
      }
    } catch (e) {
      debugPrint('Error loading level and score: $e');
      setState(() {
        _isLoadingLevel = false;
      });
    }
  }

  Widget _buildLevelDisplay() {
    if (_isLoadingLevel) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: const Offset(60, 0),
            child: Lottie.asset(
              'assets/gifs/loader-anim.json',
              width: 600,
              height: 600,
            ),
          ),
        ),
      );
    }

    final levelInfo = DailyScoringService.getLevelDisplayInfo(_currentLevel);
    final todayAccuracy = _todayScore?.accuracy ?? 0.0;
    final todayAttempts = _todayScore?.totalAttempts ?? 0;
    final todayCorrect = _todayScore?.correctAnswers ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (levelInfo['color'] as Color).withValues(alpha: 0.1),
            (levelInfo['color'] as Color).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (levelInfo['color'] as Color).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: levelInfo['color'],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(levelInfo['icon'], color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Level: ${levelInfo['name']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324259),
                      ),
                    ),
                    Text(
                      levelInfo['description'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (todayAttempts > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today\'s Performance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(todayAccuracy * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              todayAccuracy >= 0.85
                                  ? Colors.green
                                  : todayAccuracy <= 0.25
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: todayAccuracy,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      todayAccuracy >= 0.85
                          ? Colors.green
                          : todayAccuracy <= 0.25
                          ? Colors.red
                          : Colors.orange,
                    ),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$todayCorrect correct out of $todayAttempts attempts',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (todayAccuracy >= 0.85 &&
                      _currentLevel != DifficultyLevel.hard)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'On track to level up!',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (todayAccuracy <= 0.25 &&
                      _currentLevel != DifficultyLevel.easy)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.trending_down,
                            color: Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Practice more to maintain level',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Start practicing to see your daily progress!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child:
            _isLoading
                ? Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: const Offset(60, 0),
                    child: Lottie.asset(
                      'assets/gifs/loader-anim.json',
                      width: 600,
                      height: 600,
                    ),
                  ),
                )
                : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const UserSettingsScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadUserData();
                              }
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
                                child:
                                    _userData?['avatarIndex'] != null
                                        ? Image.asset(
                                          'assets/images/avatar${_userData!['avatarIndex'] + 1}.webp',
                                          fit: BoxFit.cover,
                                        )
                                        : const Icon(Icons.person),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMascot(),
                            const SizedBox(height: 24),
                            _buildLevelDisplay(),
                            const SizedBox(height: 24),
                            _buildDailyPractices(),
                            const SizedBox(height: 24),
                            _buildPopularModules(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
