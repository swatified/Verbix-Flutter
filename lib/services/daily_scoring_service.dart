
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum DifficultyLevel {
  easy,
  medium,
  hard
}

class DailyScore {
  final String userId;
  final String date;   final int correctAnswers;
  final int totalAttempts;
  final double accuracy;
  final DifficultyLevel levelAtStart;
  final DifficultyLevel? levelAtEnd;
  final DateTime timestamp;

  DailyScore({
    required this.userId,
    required this.date,
    required this.correctAnswers,
    required this.totalAttempts,
    required this.accuracy,
    required this.levelAtStart,
    this.levelAtEnd,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'correctAnswers': correctAnswers,
      'totalAttempts': totalAttempts,
      'accuracy': accuracy,
      'levelAtStart': levelAtStart.toString().split('.').last,
      'levelAtEnd': levelAtEnd?.toString().split('.').last,
      'timestamp': timestamp,
    };
  }

  factory DailyScore.fromMap(Map<String, dynamic> map) {
    return DailyScore(
      userId: map['userId'],
      date: map['date'],
      correctAnswers: map['correctAnswers'],
      totalAttempts: map['totalAttempts'],
      accuracy: map['accuracy'].toDouble(),
      levelAtStart: DifficultyLevel.values.firstWhere(
        (e) => e.toString().split('.').last == map['levelAtStart'],
        orElse: () => DifficultyLevel.easy,
      ),
      levelAtEnd: map['levelAtEnd'] != null
          ? DifficultyLevel.values.firstWhere(
              (e) => e.toString().split('.').last == map['levelAtEnd'],
              orElse: () => DifficultyLevel.easy,
            )
          : null,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

class DailyScoringService {
  static const double levelUpThreshold = 0.85;   static const double levelDownThreshold = 0.25; 
    static String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

    static Future<DifficultyLevel> getCurrentUserLevel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return DifficultyLevel.easy;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('level')) {
        final levelString = userDoc.data()!['level'] as String;
        return DifficultyLevel.values.firstWhere(
          (e) => e.toString().split('.').last == levelString,
          orElse: () => DifficultyLevel.easy,
        );
      }

            await _setUserLevel(DifficultyLevel.easy);
      return DifficultyLevel.easy;
    } catch (e) {
      debugPrint('Error getting user level: $e');
      return DifficultyLevel.easy;
    }
  }

    static Future<void> _setUserLevel(DifficultyLevel level) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'level': level.toString().split('.').last,
        'levelUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('User level updated to: ${level.toString().split('.').last}');
    } catch (e) {
      debugPrint('Error setting user level: $e');
    }
  }

    static Future<void> recordAttempt({
    required bool isCorrect,
    required String practiceId,
    required String practiceType,
    String? wordOrText,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dateStr = _getTodayDateString();
      final userLevel = await getCurrentUserLevel();
      
            final dailyScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_score')
          .doc(dateStr);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(dailyScoreRef);
        
        if (doc.exists) {
                    final data = doc.data()!;
          final currentCorrect = data['correctAnswers'] as int;
          final currentTotal = data['totalAttempts'] as int;
          
          final newCorrect = currentCorrect + (isCorrect ? 1 : 0);
          final newTotal = currentTotal + 1;
          final newAccuracy = newTotal > 0 ? (newCorrect / newTotal) : 0.0;
          
          transaction.update(dailyScoreRef, {
            'correctAnswers': newCorrect,
            'totalAttempts': newTotal,
            'accuracy': newAccuracy,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
                    final newCorrect = isCorrect ? 1 : 0;
          const newTotal = 1;
          final newAccuracy = newCorrect / newTotal;
          
          final dailyScore = DailyScore(
            userId: user.uid,
            date: dateStr,
            correctAnswers: newCorrect,
            totalAttempts: newTotal,
            accuracy: newAccuracy,
            levelAtStart: userLevel,
            timestamp: DateTime.now(),
          );
          
          transaction.set(dailyScoreRef, dailyScore.toMap());
        }
      });

            await _recordDetailedAttempt(
        isCorrect: isCorrect,
        practiceId: practiceId,
        practiceType: practiceType,
        wordOrText: wordOrText,
        dateStr: dateStr,
      );

      debugPrint('Recorded attempt: correct=$isCorrect, practice=$practiceId, word=${wordOrText ?? "N/A"}');
    } catch (e) {
      debugPrint('Error recording attempt: $e');
    }
  }

    static Future<void> _recordDetailedAttempt({
    required bool isCorrect,
    required String practiceId,
    required String practiceType,
    String? wordOrText,
    required String dateStr,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final attemptId = '${DateTime.now().millisecondsSinceEpoch}';
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_score')
          .doc(dateStr)
          .collection('attempts')
          .doc(attemptId)
          .set({
        'isCorrect': isCorrect,
        'practiceId': practiceId,
        'practiceType': practiceType,
        'wordOrText': wordOrText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording detailed attempt: $e');
    }
  }

    static Future<DailyScore?> getTodayScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final dateStr = _getTodayDateString();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_score')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        return DailyScore.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting today score: $e');
      return null;
    }
  }

    static Future<DifficultyLevel?> processEndOfDay() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final dateStr = _getTodayDateString();
      final currentLevel = await getCurrentUserLevel();
      
            final dailyScore = await getTodayScore();
      if (dailyScore == null || dailyScore.totalAttempts == 0) {
        debugPrint('No attempts today, keeping current level');
        return currentLevel;
      }

            DifficultyLevel newLevel = currentLevel;
      
      if (dailyScore.accuracy >= levelUpThreshold) {
                switch (currentLevel) {
          case DifficultyLevel.easy:
            newLevel = DifficultyLevel.medium;
            break;
          case DifficultyLevel.medium:
            newLevel = DifficultyLevel.hard;
            break;
          case DifficultyLevel.hard:
            newLevel = DifficultyLevel.hard;             break;
        }
      } else if (dailyScore.accuracy <= levelDownThreshold) {
                switch (currentLevel) {
          case DifficultyLevel.easy:
            newLevel = DifficultyLevel.easy;             break;
          case DifficultyLevel.medium:
            newLevel = DifficultyLevel.easy;
            break;
          case DifficultyLevel.hard:
            newLevel = DifficultyLevel.medium;
            break;
        }
      }
      
            if (newLevel != currentLevel) {
        await _setUserLevel(newLevel);
        
                await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_score')
            .doc(dateStr)
            .update({
          'levelAtEnd': newLevel.toString().split('.').last,
        });

        debugPrint('Level changed from ${currentLevel.toString().split('.').last} to ${newLevel.toString().split('.').last}');
        debugPrint('Based on accuracy: ${(dailyScore.accuracy * 100).toStringAsFixed(1)}%');
      } else {
        debugPrint('Level unchanged: ${currentLevel.toString().split('.').last}');
        debugPrint('Based on accuracy: ${(dailyScore.accuracy * 100).toStringAsFixed(1)}%');
      }

      return newLevel;
    } catch (e) {
      debugPrint('Error processing end of day: $e');
      return null;
    }
  }

    static Future<List<DailyScore>> getPerformanceHistory({int days = 7}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_score')
          .orderBy('date', descending: true)
          .limit(days)
          .get();

      return querySnapshot.docs
          .map((doc) => DailyScore.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting performance history: $e');
      return [];
    }
  }

    static Future<void> checkAndProcessDayTransition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

            final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      
      final yesterdayDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_score')
          .doc(yesterdayStr)
          .get();

      if (yesterdayDoc.exists) {
        final data = yesterdayDoc.data()!;
                if (data['levelAtEnd'] == null && data['totalAttempts'] > 0) {
          debugPrint('Processing yesterday\'s data...');
          
                    final yesterdayScore = DailyScore.fromMap(data);
          
                    final yesterdayLevel = yesterdayScore.levelAtStart;
          
                    DifficultyLevel newLevel = yesterdayLevel;
          
          if (yesterdayScore.accuracy >= levelUpThreshold) {
            switch (yesterdayLevel) {
              case DifficultyLevel.easy:
                newLevel = DifficultyLevel.medium;
                break;
              case DifficultyLevel.medium:
                newLevel = DifficultyLevel.hard;
                break;
              case DifficultyLevel.hard:
                newLevel = DifficultyLevel.hard;
                break;
            }
          } else if (yesterdayScore.accuracy <= levelDownThreshold) {
            switch (yesterdayLevel) {
              case DifficultyLevel.easy:
                newLevel = DifficultyLevel.easy;
                break;
              case DifficultyLevel.medium:
                newLevel = DifficultyLevel.easy;
                break;
              case DifficultyLevel.hard:
                newLevel = DifficultyLevel.medium;
                break;
            }
          }

                    if (newLevel != yesterdayLevel) {
            await _setUserLevel(newLevel);
          }

                    await yesterdayDoc.reference.update({
            'levelAtEnd': newLevel.toString().split('.').last,
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking day transition: $e');
    }
  }

  static Map<String, dynamic> getLevelDisplayInfo(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.easy:
      return {
        'name': 'Easy',
        'color': const Color(0xFF4CAF50),         'icon': const IconData(0xe86c, fontFamily: 'MaterialIcons'),         'description': 'Building confidence with simpler exercises',
      };
    case DifficultyLevel.medium:
      return {
        'name': 'Medium',
        'color': const Color(0xFFFF9800),         'icon': const IconData(0xe86a, fontFamily: 'MaterialIcons'),         'description': 'Progressing with moderate challenges',
      };
    case DifficultyLevel.hard:
      return {
        'name': 'Hard',
        'color': const Color(0xFFF44336),         'icon': const IconData(0xe86d, fontFamily: 'MaterialIcons'),         'description': 'Mastering advanced exercises',
      };
  }
}
}