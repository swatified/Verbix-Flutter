import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all wrong attempts for this word
      final attemptsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .collection('wrong_attempts')
          .where('wordId', isEqualTo: widget.wordId)
          .orderBy('timestamp', descending: true)
          .get();

      final attemptsList = attemptsQuery.docs.map((doc) {
        return {
          'id': doc.id,
          'attempt': doc.data()['attempt'] ?? 'Unknown',
          'isCorrect': doc.data()['isCorrect'] ?? false,
          'timestamp': doc.data()['timestamp'] ?? Timestamp.now(),
          'practiceType': doc.data()['practiceType'] ?? 'Unknown',
        };
      }).toList();

      setState(() {
        _attempts = attemptsList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attempts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attempts for "${widget.word}"'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF324259),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
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
                        'No attempts found for "${widget.word}"',
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
                    final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          attempt['attempt'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                        trailing: Icon(
                          attempt['isCorrect'] ? Icons.check_circle : Icons.cancel,
                          color: attempt['isCorrect'] ? Colors.green : Colors.red,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 