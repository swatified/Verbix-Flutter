import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

// Import the daily scoring service
import 'package:verbix/services/daily_scoring_service.dart';

// Types of practices
enum PracticeType {
  letterWriting,
  sentenceWriting,
  phonetic,
  letterReversal,
  vowelSounds
}

// Model for a practice module
class PracticeModule {
  final String id;
  final String title;
  final PracticeType type;
  final List<String> content;
  final bool completed;
  final DateTime createdAt;
  final int difficulty; // 1-5 scale
  final DifficultyLevel difficultyLevel; // New field for easy/medium/hard
  List<ImageOption>? imageOptions;

  PracticeModule({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    this.completed = false,
    required this.createdAt,
    this.difficulty = 1,
    this.difficultyLevel = DifficultyLevel.easy,
    this.imageOptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'content': content,
      'completed': completed,
      'createdAt': createdAt,
      'difficulty': difficulty,
      'difficultyLevel': difficultyLevel.toString().split('.').last,
      'imageOptions': imageOptions?.map((e) => e.toJson()).toList(),
    };
  }

  factory PracticeModule.fromMap(Map<String, dynamic> map) {
    return PracticeModule(
      id: map['id'],
      title: map['title'],
      type: PracticeType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => PracticeType.letterWriting,
      ),
      content: List<String>.from(map['content']),
      completed: map['completed'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      difficulty: map['difficulty'] ?? 1,
      difficultyLevel: map['difficultyLevel'] != null
          ? DifficultyLevel.values.firstWhere(
              (e) => e.toString().split('.').last == map['difficultyLevel'],
              orElse: () => DifficultyLevel.easy,
            )
          : DifficultyLevel.easy,
      imageOptions: map['imageOptions'] != null
          ? List<ImageOption>.from(
              map['imageOptions'].map((x) => ImageOption.fromJson(x)))
          : null,
    );
  }

  // Create a copy of this practice with updated fields
  PracticeModule copyWith({
    String? id,
    String? title,
    PracticeType? type,
    List<String>? content,
    bool? completed,
    DateTime? createdAt,
    int? difficulty,
    DifficultyLevel? difficultyLevel,
    List<ImageOption>? imageOptions,
  }) {
    return PracticeModule(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      difficulty: difficulty ?? this.difficulty,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      imageOptions: imageOptions ?? this.imageOptions,
    );
  }
}

class ImageOption {
  final String id;
  final String imageUrl;
  final String word;

  ImageOption({
    required this.id,
    required this.imageUrl,
    required this.word,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageUrl': imageUrl,
        'word': word,
      };

  factory ImageOption.fromJson(Map<String, dynamic> json) {
    return ImageOption(
      id: json['id'],
      imageUrl: json['imageUrl'],
      word: json['word'],
    );
  }
}

class CustomPracticeService {
  static final _projectId = dotenv.env['VERTEX_PROJECT_ID'] ?? '';
  static final _location = dotenv.env['VERTEX_LOCATION'] ?? 'us-central1';
  static final _modelId = 'gemini-1.5-pro-002';
  static String? _accessToken;
  static DateTime? _tokenExpiry;
  
  // Get service account credentials from a file
  static Future<ServiceAccountCredentials> _getCredentials() async {
    final directory = await getApplicationDocumentsDirectory();
    final credentialsPath = '${directory.path}/service-account.json';
    final file = File(credentialsPath);
    
    if (!await file.exists()) {
      throw Exception('Service account credentials file not found at: $credentialsPath');
    }
    
    final jsonString = await file.readAsString();
    final jsonMap = json.decode(jsonString);
    return ServiceAccountCredentials.fromJson(jsonMap);
  }

  // Get OAuth2 access token
  static Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
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

  // Method to get authentication headers with token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get the Vertex AI endpoint for Gemini
  static String get _endpoint {
    return 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_modelId:generateContent';
  }
  
  // Fetch user's recent test results
  static Future<List<Map<String, dynamic>>> _fetchRecentTestResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching test results: $e');
      return [];
    }
  }

  // Generate custom practice modules based on test results and difficulty level
  static Future<List<PracticeModule>> generateCustomPractices() async {
    try {
      // Check day transition first
      await DailyScoringService.checkAndProcessDayTransition();
      
      // Get user's current difficulty level
      final userLevel = await DailyScoringService.getCurrentUserLevel();
      
      // Fetch recent test results
      final testResults = await _fetchRecentTestResults();
      if (testResults.isEmpty) {
        return _createDefaultPractices(userLevel);
      }

      // Extract patterns from test results
      List<String> writtenAnalyses = [];
      List<String> speechAnalyses = [];
      List<String> recommendations = [];

      for (var test in testResults) {
        writtenAnalyses.add(test['writtenAnalysis'] ?? '');
        speechAnalyses.add(test['speechAnalysis'] ?? '');
        recommendations.add(test['recommendations'] ?? '');
      }

      // Combine analyses for prompt
      final combinedAnalyses = {
        'writtenAnalysis': writtenAnalyses.join('\n\n'),
        'speechAnalysis': speechAnalyses.join('\n\n'),
        'recommendations': recommendations.join('\n\n'),
      };

      // Generate personalized practices using Vertex AI
      return await _generatePracticesWithGemini(combinedAnalyses, userLevel);
    } catch (e) {
      print('Error generating custom practices: $e');
      final userLevel = await DailyScoringService.getCurrentUserLevel();
      return _createDefaultPractices(userLevel);
    }
  }

  // Generate practices using Vertex AI API with difficulty level
  static Future<List<PracticeModule>> _generatePracticesWithGemini(
      Map<String, String> analyses, DifficultyLevel userLevel) async {
    try {
      final randomSeed = DateTime.now().millisecondsSinceEpoch;
      
      // Get difficulty-specific instructions
      final difficultyInstructions = _getDifficultyInstructions(userLevel);
      
      // Create the prompt for Vertex AI
      final prompt = '''
      # Dyslexia Practice Module Generation

      ## User's Current Level: ${userLevel.toString().split('.').last.toUpperCase()}
      
      ## Difficulty Guidelines:
      $difficultyInstructions

      ## User's Analysis Data
      ### Written Analysis:
      ${analyses['writtenAnalysis']}

      ### Speech Analysis:
      ${analyses['speechAnalysis']}

      ### Recommendations:
      ${analyses['recommendations']}

      ## Task
      Create 5 personalized practice modules for this user based on their dyslexia test results and current difficulty level.
      Each module should target a specific pattern or challenge identified in the analysis, adjusted for their current level.

      ## Requirements
      For each practice module, provide the following in JSON format:
      
      ```json
      [
        {
          "title": "Short descriptive title appropriate for ${userLevel.toString().split('.').last} level",
          "type": "One of: letterWriting, sentenceWriting, phonetic, letterReversal, vowelSounds",
          "content": ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"],
          "difficulty": number from 1-5 (adjusted for ${userLevel.toString().split('.').last} level)
        },
        ...
      ]
      ```

      For the "content" field based on ${userLevel.toString().split('.').last} level:
      - For letterWriting: Include 5 letters following the difficulty guidelines above
      - For sentenceWriting: Include 5 sentences following the length and complexity guidelines
      - For phonetic: Include 5 words following the phonetic complexity guidelines
      - For letterReversal: Include 5 pairs following the difficulty guidelines
      - For vowelSounds: Include 5 words following the vowel complexity guidelines

      IMPORTANT DIFFICULTY ADJUSTMENTS:
      ${_getSpecificContentGuidelines(userLevel)}

      Generate different content each time, including ${DateTime.now().toIso8601String()} as a timestamp to ensure uniqueness.
      Generation ID: $randomSeed
      ''';

      // Get headers with OAuth token
      final headers = await _getAuthHeaders();
      
      // Prepare request body for Gemini model
      final requestBody = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": prompt
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1024,
          "topK": 40,
          "topP": 0.95
        }
      });
      
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: requestBody,
      );
      
      if (response.statusCode != 200) {
        throw Exception("API call failed with status code: ${response.statusCode}");
      }
      
      final responseData = jsonDecode(response.body);
      
      // Extract text from Gemini response
      String responseText = "";
      if (responseData.containsKey('candidates') && 
          responseData['candidates'] is List && 
          responseData['candidates'].isNotEmpty) {
        
        var candidate = responseData['candidates'][0];
        if (candidate.containsKey('content') && 
            candidate['content'].containsKey('parts') && 
            candidate['content']['parts'] is List && 
            candidate['content']['parts'].isNotEmpty) {
          
          responseText = candidate['content']['parts'][0]['text'] ?? '';
        }
      }

      // Extract JSON from the response
      final jsonRegex = RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true);
      final match = jsonRegex.firstMatch(responseText);
      
      if (match == null) {
        final anyJsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(responseText);
        
        if (anyJsonMatch != null) {
          try {
            final jsonString = anyJsonMatch.group(0);
            final List<dynamic> jsonData = json.decode(jsonString!);
            return _createPracticesFromJsonData(jsonData, userLevel);
          } catch (e) {
            throw Exception('Could not extract valid JSON from response');
          }
        } else {
          throw Exception('Could not extract valid JSON from response');
        }
      }
      
      final jsonString = match.group(0);
      final List<dynamic> jsonData = json.decode(jsonString!);
      
      return _createPracticesFromJsonData(jsonData, userLevel);
    } catch (e) {
      print('Error with Vertex AI API: $e');
      return _createDefaultPractices(userLevel);
    }
  }

  // Get difficulty-specific instructions
  static String _getDifficultyInstructions(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return '''
        EASY LEVEL GUIDELINES:
        - Use simple, short words (3-5 letters)
        - Simple sentence structures (5-8 words)
        - Common, everyday vocabulary
        - Clear phonetic patterns
        - Basic letter combinations
        - Avoid complex grammar or punctuation
        ''';
      case DifficultyLevel.medium:
        return '''
        MEDIUM LEVEL GUIDELINES:
        - Moderate length words (4-7 letters)
        - Medium sentences (6-12 words)
        - Mix of common and slightly challenging vocabulary
        - More complex phonetic patterns
        - Include some compound words
        - Basic punctuation (periods, commas)
        ''';
      case DifficultyLevel.hard:
        return '''
        HARD LEVEL GUIDELINES:
        - Longer words (6-10+ letters)
        - Complex sentences (10-15+ words)
        - Advanced vocabulary and concepts
        - Complex phonetic patterns and silent letters
        - Multi-syllable words
        - Advanced punctuation and grammar
        - Include challenging letter combinations
        ''';
    }
  }

  // Get specific content guidelines for each practice type
  static String _getSpecificContentGuidelines(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return '''
        EASY CONTENT SPECIFICS:
        - Letters: Focus on commonly confused letters (b/d, p/q, m/w)
        - Sentences: "The cat sat." "I like dogs." "We go home."
        - Phonetic: Simple words like "cat", "dog", "run", "big", "sun"
        - Reversals: Simple pairs like "was/saw", "on/no", "it/ti"
        - Vowels: Short vowel sounds in simple words like "cat", "pet", "sit"
        ''';
      case DifficultyLevel.medium:
        return '''
        MEDIUM CONTENT SPECIFICS:
        - Letters: Include cursive transitions and less common letters
        - Sentences: "The quick brown fox jumps." "She walked to the store yesterday."
        - Phonetic: Words with blends like "string", "splash", "through"
        - Reversals: More complex pairs like "form/from", "trail/trial"
        - Vowels: Long vowels and diphthongs like "boat", "night", "house"
        ''';
      case DifficultyLevel.hard:
        return '''
        HARD CONTENT SPECIFICS:
        - Letters: Complex letter combinations and ligatures
        - Sentences: "The extraordinary circumstances required immediate attention." "Despite the challenging weather conditions, they persevered."
        - Phonetic: Complex words like "extraordinary", "circumstances", "perseverance"
        - Reversals: Challenging pairs like "psychology/psychologist", "definitely/defiantly"
        - Vowels: Complex vowel patterns like "beautiful", "curious", "mysterious"
        ''';
    }
  }
  
  // Helper method to create practice modules from JSON data
  static List<PracticeModule> _createPracticesFromJsonData(List<dynamic> jsonData, DifficultyLevel userLevel) {
    List<PracticeModule> practices = [];
    
    for (var item in jsonData) {
      try {
        final typeStr = item['type'] as String;
        final type = PracticeType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => PracticeType.letterWriting,
        );
        
        final practice = PracticeModule(
          id: 'practice_${DateTime.now().millisecondsSinceEpoch}_${practices.length}',
          title: item['title'],
          type: type,
          content: List<String>.from(item['content']),
          completed: false,
          createdAt: DateTime.now(),
          difficulty: item['difficulty'] ?? 1,
          difficultyLevel: userLevel, // Set the user's current level
        );

        if (practice.type == PracticeType.sentenceWriting) {
          practice.imageOptions = [
            ImageOption(
              id: 'img1',
              imageUrl: 'https://example.com/image1.jpg',
              word: 'example',
            ),
          ];
        }

        practices.add(practice);
      } catch (e) {
        print("Error creating practice module: $e");
      }
    }
    
    return practices.take(5).toList();
  }

  // Save practices to Firestore
  static Future<void> savePractices(List<PracticeModule> practices) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete existing practices
      final existingPractices = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('practice_modules')
          .get();
          
      for (var doc in existingPractices.docs) {
        batch.delete(doc.reference);
      }
      
      // Add new practices
      for (var practice in practices) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('practice_modules')
            .doc(practice.id);
            
        batch.set(docRef, practice.toMap());
      }
      
      await batch.commit();
    } catch (e) {
      print('Error saving practices: $e');
    }
  }

  // Fetch practices from Firestore
  static Future<List<PracticeModule>> fetchPractices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('practice_modules')
          .orderBy('createdAt', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        final userLevel = await DailyScoringService.getCurrentUserLevel();
        final defaults = _createDefaultPractices(userLevel);
        await savePractices(defaults);
        return defaults;
      }

      return querySnapshot.docs
          .map((doc) => PracticeModule.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching practices: $e');
      final userLevel = await DailyScoringService.getCurrentUserLevel();
      return _createDefaultPractices(userLevel);
    }
  }

  // Mark a practice as completed
  static Future<void> markPracticeCompleted(String practiceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('practice_modules')
          .doc(practiceId)
          .update({'completed': true});
    } catch (e) {
      print('Error marking practice as completed: $e');
    }
  }

  // Create default practices based on difficulty level
  static List<PracticeModule> _createDefaultPractices(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return [
          PracticeModule(
            id: 'default_letter_writing_easy',
            title: 'Basic Letter Practice',
            type: PracticeType.letterWriting,
            content: ['b', 'd', 'p', 'q', 'm'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 1,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_sentence_writing_easy',
            title: 'Simple Sentences',
            type: PracticeType.sentenceWriting,
            content: [
              'The cat sat.',
              'I like dogs.',
              'We go home.',
              'She is nice.',
              'He can run.'
            ],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 1,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_phonetic_easy',
            title: 'Simple Sounds',
            type: PracticeType.phonetic,
            content: ['cat', 'dog', 'run', 'big', 'sun'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 1,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_reversal_easy',
            title: 'Letter Pairs',
            type: PracticeType.letterReversal,
            content: ['was/saw', 'on/no', 'it/ti', 'am/ma', 'at/ta'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 1,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_vowels_easy',
            title: 'Short Vowels',
            type: PracticeType.vowelSounds,
            content: ['cat', 'pet', 'sit', 'dot', 'cut'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 1,
            difficultyLevel: level,
          ),
        ];
      
      case DifficultyLevel.medium:
        return [
          PracticeModule(
            id: 'default_letter_writing_medium',
            title: 'Advanced Letter Practice',
            type: PracticeType.letterWriting,
            content: ['g', 'j', 'y', 'f', 'z'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 3,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_sentence_writing_medium',
            title: 'Compound Sentences',
            type: PracticeType.sentenceWriting,
            content: [
              'The quick brown fox jumps over the fence.',
              'She walked to the store yesterday morning.',
              'They played games after finishing their homework.',
              'We saw many colorful birds in the tall tree.',
              'He likes to read adventure books at night.'
            ],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 3,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_phonetic_medium',
            title: 'Complex Sounds',
            type: PracticeType.phonetic,
            content: ['string', 'splash', 'through', 'bright', 'school'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 3,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_reversal_medium',
            title: 'Word Reversals',
            type: PracticeType.letterReversal,
            content: ['form/from', 'trail/trial', 'angel/angle', 'quite/quiet', 'desert/dessert'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 3,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_vowels_medium',
            title: 'Long Vowels',
            type: PracticeType.vowelSounds,
            content: ['boat', 'night', 'house', 'coin', 'fruit'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 3,
            difficultyLevel: level,
          ),
        ];
      
      case DifficultyLevel.hard:
        return [
          PracticeModule(
            id: 'default_letter_writing_hard',
            title: 'Complex Letters',
            type: PracticeType.letterWriting,
            content: ['x', 'k', 'v', 'w', 'u'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 5,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_sentence_writing_hard',
            title: 'Advanced Sentences',
            type: PracticeType.sentenceWriting,
            content: [
              'The extraordinary circumstances required immediate attention from the authorities.',
              'Despite the challenging weather conditions, they persevered through the journey.',
              'The magnificent architecture demonstrated the civilization\'s advanced engineering.',
              'Contemporary literature influences modern philosophical discussions significantly.',
              'Environmental conservation efforts require collaborative international cooperation.'
            ],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 5,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_phonetic_hard',
            title: 'Advanced Phonetics',
            type: PracticeType.phonetic,
            content: ['extraordinary', 'circumstances', 'perseverance', 'magnificent', 'contemporary'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 5,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_reversal_hard',
            title: 'Complex Reversals',
            type: PracticeType.letterReversal,
            content: ['psychology/psychologist', 'definitely/defiantly', 'accept/except', 'affect/effect', 'principal/principle'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 5,
            difficultyLevel: level,
          ),
          PracticeModule(
            id: 'default_vowels_hard',
            title: 'Complex Vowels',
            type: PracticeType.vowelSounds,
            content: ['beautiful', 'curious', 'mysterious', 'previous', 'serious'],
            completed: false,
            createdAt: DateTime.now(),
            difficulty: 5,
            difficultyLevel: level,
          ),
        ];
    }
  }
}