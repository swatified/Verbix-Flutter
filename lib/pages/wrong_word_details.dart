import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WrongWordDetailsScreen extends StatefulWidget {
  final String childId;
  final String wordId;
  final String word;

  const WrongWordDetailsScreen({
    super.key,
    required this.childId,
    required this.wordId,
    required this.word,
  });

  @override
  State<WrongWordDetailsScreen> createState() => _WrongWordDetailsScreenState();
}

class _WrongWordDetailsScreenState extends State<WrongWordDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attempts = [];
  Map<String, int> _wordCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAllIncorrectAttempts();
  }

  Future<void> _loadAllIncorrectAttempts() async {
    setState(() {
      _isLoading = true;
    });

    try {
            final dailyScoresSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .collection('daily_score')
          .get();

      List<Map<String, dynamic>> allAttempts = [];
      Map<String, int> wordCounts = {};

            for (var dailyScore in dailyScoresSnapshot.docs) {
        final dateStr = dailyScore.id;
        
                final attemptsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.childId)
            .collection('daily_score')
            .doc(dateStr)
            .collection('attempts')
            .where('isCorrect', isEqualTo: false)
            .get();

                for (var doc in attemptsSnapshot.docs) {
          final word = doc.data()['wordOrText'] ?? 'Unknown';
          
          allAttempts.add({
            'id': doc.id,
            'date': dateStr,
            'word': word,
            'practiceType': doc.data()['practiceType'] ?? 'Unknown',
            'timestamp': doc.data()['timestamp'] ?? Timestamp.now(),
            'isCorrect': false,
          });
          
                    wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        }
      }

            allAttempts.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp;
        final bTimestamp = b['timestamp'] as Timestamp;
        return bTimestamp.compareTo(aTimestamp);
      });

      setState(() {
        _attempts = allAttempts;
        _wordCounts = wordCounts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading attempts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Incorrect Words'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF324259),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                Expanded(
                  child: _attempts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No incorrect attempts found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _attempts.length,
                          itemBuilder: (context, index) {
                            final attempt = _attempts[index];
                            final timestamp = attempt['timestamp'] as Timestamp;
                            final date = timestamp.toDate();
                            final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
                            final word = attempt['word'] as String;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  word,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      'Practice Type: ${attempt['practiceType']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: $formattedDate',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_wordCounts[word] ?? 1}',
                                    style: TextStyle(
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      color: const Color(0xFFFFF3F3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFCCCC), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Incorrect Words History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324259),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_attempts.length} total incorrect attempts',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
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
} 