import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PracticeStats {
  final int totalCompleted;
  final int streak;   final DateTime lastPracticeDate;
  final Map<String, int> practiceTypeBreakdown;
  
  PracticeStats({
    this.totalCompleted = 0,
    this.streak = 0,
    required this.lastPracticeDate,
    required this.practiceTypeBreakdown,
  });
  
  factory PracticeStats.fromMap(Map<String, dynamic> map) {
    return PracticeStats(
      totalCompleted: map['totalCompleted'] ?? 0,
      streak: map['streak'] ?? 0,
      lastPracticeDate: (map['lastPracticeDate'] as Timestamp).toDate(),
      practiceTypeBreakdown: Map<String, int>.from(map['practiceTypeBreakdown'] ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'totalCompleted': totalCompleted,
      'streak': streak,
      'lastPracticeDate': lastPracticeDate,
      'practiceTypeBreakdown': practiceTypeBreakdown,
    };
  }
}

class PracticeStatsService {
  static Future<PracticeStats> getUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stats')
          .doc('practice_stats')
          .get();
          
      if (!docSnapshot.exists) {
                final defaultStats = PracticeStats(
          totalCompleted: 0,
          streak: 0,
          lastPracticeDate: DateTime.now().subtract(const Duration(days: 1)),
          practiceTypeBreakdown: {},
        );
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stats')
            .doc('practice_stats')
            .set(defaultStats.toMap());
            
        return defaultStats;
      }
      
      return PracticeStats.fromMap(docSnapshot.data()!);
    } catch (e) {
      debugPrint('Error getting user stats: $e');
            return PracticeStats(
        totalCompleted: 0,
        streak: 0,
        lastPracticeDate: DateTime.now().subtract(const Duration(days: 1)),
        practiceTypeBreakdown: {},
      );
    }
  }
  
  static Future<void> updateStatsAfterCompletion(String practiceType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
            final currentStats = await getUserStats();
      
            final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      
            final lastDate = DateTime(
        currentStats.lastPracticeDate.year,
        currentStats.lastPracticeDate.month,
        currentStats.lastPracticeDate.day,
      );
      
            final difference = today.difference(lastDate).inDays;
      
            int newStreak = currentStats.streak;
      if (difference == 0) {
                newStreak = currentStats.streak;
      } else if (difference == 1) {
                newStreak = currentStats.streak + 1;
      } else {
                newStreak = 1;
      }
      
            final typeBreakdown = Map<String, int>.from(currentStats.practiceTypeBreakdown);
      typeBreakdown[practiceType] = (typeBreakdown[practiceType] ?? 0) + 1;
      
            final updatedStats = PracticeStats(
        totalCompleted: currentStats.totalCompleted + 1,
        streak: newStreak,
        lastPracticeDate: today,
        practiceTypeBreakdown: typeBreakdown,
      );
      
            await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stats')
          .doc('practice_stats')
          .set(updatedStats.toMap());
    } catch (e) {
      debugPrint('Error updating stats: $e');
    }
  }
  
    static Future<int> getPracticesCompletedToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
            final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
            final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('practice_modules')
          .where('completed', isEqualTo: true)
          .where('lastCompletedAt', isGreaterThanOrEqualTo: startOfDay)
          .where('lastCompletedAt', isLessThan: endOfDay)
          .get();
          
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting practices completed today: $e');
      return 0;
    }
  }
}