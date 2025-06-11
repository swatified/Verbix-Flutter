import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/daily_scoring_service.dart';
import 'auth_screen.dart';
import 'parent_child_dashboard.dart';
import 'wrong_word_details.dart';

class GeminiPatternService {
  static final _projectId = dotenv.env['VERTEX_PROJECT_ID'] ?? '';
  static final _location = dotenv.env['VERTEX_LOCATION'] ?? 'us-central1';
  static final _modelId = 'gemini-1.5-pro-002';
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  static Future<ServiceAccountCredentials> _getCredentials() async {
    final directory = await getApplicationDocumentsDirectory();
    final credentialsPath = '${directory.path}/service-account.json';
    final file = File(credentialsPath);

    if (!await file.exists()) {
      throw Exception(
        'Service account credentials file not found at: $credentialsPath',
      );
    }

    final jsonString = await file.readAsString();
    final jsonMap = json.decode(jsonString);
    return ServiceAccountCredentials.fromJson(jsonMap);
  }

  static Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    try {
      final credentials = await _getCredentials();
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      final client = await clientViaServiceAccount(credentials, scopes);

      _accessToken = client.credentials.accessToken.data;
      _tokenExpiry = client.credentials.accessToken.expiry;

      return _accessToken!;
    } catch (e) {
      throw Exception('Failed to authenticate with Vertex AI: $e');
    }
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String get _endpoint {
    return 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_modelId:generateContent';
  }

  static Future<String> generatePatternBreakdown(
    List<Map<String, dynamic>> testResults,
    List<Map<String, dynamic>> todaysTroubles,
  ) async {
    try {
      debugPrint("DEBUG: Starting dyslexia pattern breakdown generation");
      debugPrint("DEBUG: Test results count: ${testResults.length}");
      debugPrint("DEBUG: Today's troubles count: ${todaysTroubles.length}");

      if (testResults.isEmpty && todaysTroubles.isEmpty) {
        debugPrint("DEBUG: No data available for analysis");
        return 'No test results or practice data available yet. Complete a dyslexia test to get personalized pattern analysis.';
      }

      String testResultsAnalysis = '';
      if (testResults.isNotEmpty) {
        debugPrint("DEBUG: Processing ${testResults.length} test results");
        testResultsAnalysis = testResults
            .map((test) {
              final date =
                  test['timestamp']?.toDate()?.toString() ?? 'Unknown date';
              final heading = test['heading'] ?? 'No heading';
              final originalSentence = test['originalSentence'] ?? '';
              final writtenResponse = test['writtenResponse'] ?? '';
              final speechResponse = test['speechResponse'] ?? '';
              final writtenAnalysis = test['writtenAnalysis'] ?? '';
              final speechAnalysis = test['speechAnalysis'] ?? '';

              debugPrint(
                "DEBUG: Test - Heading: $heading, Original: $originalSentence",
              );
              debugPrint(
                "DEBUG: Written: $writtenResponse, Speech: $speechResponse",
              );

              return '''
Test Date: $date
Test Heading: "$heading"
Original Sentence: "$originalSentence"
Child's Written Response: "$writtenResponse"
Child's Speech Response: "$speechResponse"

Written Analysis:
$writtenAnalysis

Speech Analysis:
$speechAnalysis
''';
            })
            .join('\n---\n\n');
      }

      String troublesSummary = '';
      if (todaysTroubles.isNotEmpty) {
        debugPrint("DEBUG: Processing ${todaysTroubles.length} trouble items");
        troublesSummary = todaysTroubles
            .map((trouble) {
              return '- Word: "${trouble['word']}" (Practice Type: ${trouble['practiceType']}, Failed ${trouble['count']} time${trouble['count'] == 1 ? '' : 's'})';
            })
            .join('\n');
      }

      final prompt = '''
# Dyslexia Pattern Analysis for Parent Dashboard

## Child's Test Results and Performance Data

### Recent Dyslexia Test Results:
${testResultsAnalysis.isNotEmpty ? testResultsAnalysis : 'No recent test results available.'}

### Today's Practice Difficulties:
${troublesSummary.isNotEmpty ? troublesSummary : 'No practice difficulties recorded today.'}

## Task
Analyze the dyslexia patterns from the test results and generate a detailed, custom parent-friendly summary that identifies:

### Focus on Specific Details:
1. **Exact letters/sounds the child confuses** (e.g., "often confuses 'b' and 'd'", "struggles with 'th' sounds")
2. **Specific pattern examples** from their actual responses (e.g., "wrote 'Dib' instead of 'Did'")
3. **Consistent error types** across multiple tests
4. **Sound substitutions** they commonly make (e.g., "says 'dogs' for 'dog'")
5. **Omission patterns** (e.g., "frequently omits word endings", "skips middle sounds")

### Generate Custom Analysis Like:
"Your child consistently confuses 'b' and 'd' letters, as seen when they wrote 'Dib' instead of 'Did'. They also tend to add extra sounds, saying 'dogs' instead of 'dog', and often omit parts of longer sentences. The pattern shows difficulty with letter orientation and auditory processing of word endings."

## Requirements
- BE VERY SPECIFIC about which letters, sounds, or words cause confusion
- Use ACTUAL EXAMPLES from their test responses when possible
- Identify 2-3 concrete patterns with specific details
- Keep it under 100 words but be detailed
- Use parent-friendly language
- If insufficient data, ask for more test data to provide better analysis

## Example Output:
"Your child consistently confuses 'b' and 'd' letters, as seen when they wrote 'Dib' instead of 'Did'. They also tend to add extra sounds, saying 'dogs' instead of 'dog', and often omit parts of longer sentences. The pattern shows difficulty with letter orientation and auditory processing of word endings."

Generate the dyslexia pattern analysis now:
''';

      debugPrint("DEBUG: Prompt length: ${prompt.length} characters");
      debugPrint("DEBUG: Getting authentication headers");

      final headers = await _getAuthHeaders();
      debugPrint("DEBUG: Successfully got auth headers");

      final requestBody = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.3,
          "maxOutputTokens": 200,
          "topK": 40,
          "topP": 0.95,
        },
      });

      debugPrint(
        "DEBUG: Request body prepared, making API call to: $_endpoint",
      );
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: requestBody,
      );

      debugPrint(
        "DEBUG: Pattern breakdown response status: ${response.statusCode}",
      );
      debugPrint(
        "DEBUG: Response body preview: ${response.body.substring(0, min(500, response.body.length))}",
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint("DEBUG: Successfully decoded JSON response");

        
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty) {
          var candidate = responseData['candidates'][0];
          if (candidate.containsKey('content') &&
              candidate['content'].containsKey('parts') &&
              candidate['content']['parts'] is List &&
              candidate['content']['parts'].isNotEmpty) {
            final text = candidate['content']['parts'][0]['text'] ?? '';
            debugPrint(
              "DEBUG: Successfully extracted text: ${text.substring(0, min(100, text.length))}...",
            );
            return text.trim();
          } else {
            debugPrint(
              "ERROR: Response structure unexpected - missing content/parts",
            );
            debugPrint("DEBUG: Candidate structure: $candidate");
          }
        } else {
          debugPrint(
            "ERROR: Response structure unexpected - missing candidates",
          );
          debugPrint("DEBUG: Response structure keys: ${responseData.keys}");
        }
      } else {
        debugPrint("ERROR: API call failed with status ${response.statusCode}");
        debugPrint("ERROR: Response body: ${response.body}");
      }

      throw Exception(
        "Failed to generate pattern breakdown: ${response.statusCode}",
      );
    } catch (e) {
      debugPrint("ERROR in generatePatternBreakdown: $e");
      debugPrint("ERROR: Stack trace: ${StackTrace.current}");
      
      return _generateDyslexiaPatternFallback(testResults, todaysTroubles);
    }
  }

  
  static String _generateDyslexiaPatternFallback(
    List<Map<String, dynamic>> testResults,
    List<Map<String, dynamic>> todaysTroubles,
  ) {
    debugPrint("DEBUG: Using fallback pattern analysis");

    
    if (testResults.isNotEmpty) {
      List<String> patterns = [];

      for (var test in testResults) {
        final originalSentence = test['originalSentence']?.toString() ?? '';
        final writtenResponse = test['writtenResponse']?.toString() ?? '';
        final speechResponse = test['speechResponse']?.toString() ?? '';

        debugPrint(
          "DEBUG: Analyzing test - Original: '$originalSentence', Written: '$writtenResponse', Speech: '$speechResponse'",
        );

        
        if (originalSentence.isNotEmpty && writtenResponse.isNotEmpty) {
          
          if (originalSentence.toLowerCase().contains('d') &&
              writtenResponse.toLowerCase().contains('b')) {
            patterns.add('confuses \'b\' and \'d\' letters');
          }

          
          if (writtenResponse.length < originalSentence.length / 2) {
            patterns.add('tends to omit large portions of sentences');
          }

          
          if (writtenResponse.toLowerCase().contains('dib') &&
              originalSentence.toLowerCase().contains('did')) {
            patterns.add('wrote \'Dib\' instead of \'Did\'');
          }
        }

        if (speechResponse.isNotEmpty && originalSentence.isNotEmpty) {
          
          if (speechResponse.toLowerCase().contains('dogs') &&
              originalSentence.toLowerCase().contains('dog') &&
              !originalSentence.toLowerCase().contains('dogs')) {
            patterns.add('adds plural sounds (\'dogs\' for \'dog\')');
          }
        }
      }

      if (patterns.isNotEmpty) {
        final uniquePatterns = patterns.toSet().take(3).toList();
        return 'Based on recent tests, your child ${uniquePatterns.join(', ')}. These patterns indicate specific areas where targeted practice can help improve reading and writing skills.';
      }
    }

    return 'Unable to analyze patterns at this time. Check the app logs for technical details, or try completing a new dyslexia test to generate fresh analysis.';
  }
}

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
        
        final parentDoc =
            await FirebaseFirestore.instance
                .collection('parents')
                .doc(user.uid)
                .get();

        if (parentDoc.exists) {
          setState(() {
            _parentName = parentDoc.data()?['name'] ?? 'Parent';
          });

          
          final email = user.email;
          if (email != null) {
            final childQuery =
                await FirebaseFirestore.instance
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
      debugPrint('Error loading parent data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildData(String childId) async {
    try {
      
      final childDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(childId)
              .get();

      if (childDoc.exists) {
        
        setState(() {
          _childLevel = childDoc.data()?['level'] ?? 'Beginner';
          _childId = childId;
        });

        
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

        
        final attemptsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(childId)
                .collection('daily_score')
                .doc(dateStr)
                .collection('attempts')
                .where('isCorrect', isEqualTo: false)
                .get();

        
        final Map<String, Map<String, dynamic>> uniqueWords = {};

        for (var doc in attemptsSnapshot.docs) {
          final word = doc.data()['wordOrText'] ?? 'Unknown';
          if (!uniqueWords.containsKey(word)) {
            uniqueWords[word] = {
              'id': doc.id,
              'word': word,
              'practiceType': doc.data()['practiceType'] ?? 'Unknown',
              'timestamp': doc.data()['timestamp'] ?? Timestamp.now(),
              'count': 1,
            };
          } else {
            
            uniqueWords[word]?['count'] =
                (uniqueWords[word]?['count'] ?? 0) + 1;
          }
        }

        
        final troublesList = uniqueWords.values.toList();
        final limitedTroublesList = troublesList.take(3).toList();

        
        final testResults = await _fetchRecentTestResults(childId);

        
        final patternBreakdown = await _generatePatternBreakdownWithGemini(
          testResults,
          troublesList,
        );

        setState(() {
          _recentTroubles = limitedTroublesList;
          _patternBreakdown = patternBreakdown;
        });
      }
    } catch (e) {
      debugPrint('Error loading child data: $e');
      
      setState(() {
        _patternBreakdown =
            'Unable to analyze patterns at this time. Please check back later for updated dyslexia pattern insights.';
      });
    }
  }

  
  Future<List<Map<String, dynamic>>> _fetchRecentTestResults(
    String childId,
  ) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(childId)
              .collection('test_results')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching test results: $e');
      return [];
    }
  }

  
  Future<String> _generatePatternBreakdownWithGemini(
    List<Map<String, dynamic>> testResults,
    List<Map<String, dynamic>> troubles,
  ) async {
    try {
      
      await _ensureServiceAccountExists();

      return await GeminiPatternService.generatePatternBreakdown(
        testResults,
        troubles,
      );
    } catch (e) {
      debugPrint('Error generating pattern breakdown with Gemini: $e');
      return GeminiPatternService._generateDyslexiaPatternFallback(
        testResults,
        troubles,
      );
    }
  }

  
  Future<void> _ensureServiceAccountExists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final credentialsPath = '${directory.path}/service-account.json';
      final file = File(credentialsPath);

      if (!await file.exists()) {
        debugPrint(
          "DEBUG: Service account file doesn't exist, copying from assets",
        );
        
        final byteData = await rootBundle.load('assets/service-account.json');
        final buffer = byteData.buffer;
        await file.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
        debugPrint("DEBUG: Service account file copied successfully");
      } else {
        debugPrint("DEBUG: Service account file already exists");
      }
    } catch (e) {
      debugPrint("ERROR: Failed to setup service account file: $e");
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _getGreeting();
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
      body:
          _isLoading
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
            color: Colors.grey.withValues(alpha: 0.2),
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
    
    final levelString = _childLevel.toLowerCase();
    DifficultyLevel childLevel = DifficultyLevel.easy; 

    
    if (levelString.contains('medium')) {
      childLevel = DifficultyLevel.medium;
    } else if (levelString.contains('hard')) {
      childLevel = DifficultyLevel.hard;
    }

    final levelInfo = DailyScoringService.getLevelDisplayInfo(childLevel);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: (levelInfo['color'] as Color).withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (levelInfo['color'] as Color).withValues(alpha: 0.3),
          width: 1,
        ),
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
        side: BorderSide(
          color: const Color.fromARGB(98, 154, 151, 151),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Incorrect Attempts:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF455A64),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_recentTroubles.isNotEmpty) {
                      _navigateToAllIncorrectWords(_recentTroubles.first);
                    }
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._recentTroubles.isEmpty
                ? [const Text('No incorrect attempts recorded today')]
                : _recentTroubles.map((trouble) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              trouble['word'],
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${trouble['count']} ${trouble['count'] == 1 ? 'time' : 'times'}',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Practice Type: ${trouble['practiceType']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
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

  void _navigateToAllIncorrectWords(Map<String, dynamic> trouble) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => WrongWordDetailsScreen(
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
      color: const Color.fromARGB(182, 239, 239, 214), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color.fromARGB(100, 166, 155, 99),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Color(0xFF455A64),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Pattern Analysis:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF455A64),
                  ),
                ),
              ],
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
      color: const Color.fromARGB(
        88,
        197,
        223,
        214,
      ), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color.fromARGB(100, 86, 112, 104),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ParentChildDashboardScreen(childId: _childId),
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
                color: Color(0xFF324259), 
              ),
            ],
          ),
        ),
      ),
    );
  }
}
