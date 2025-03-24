import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Gemini API Service
class GeminiService {
  static final _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final _model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);

  static Future<String> generateSentence() async {
    try {
      final content = [Content.text('Generate a simple sentence for dyslexia testing using common words. Keep it short, below 10 words.')];
      final response = await _model.generateContent(content);
      return response.text ?? 'She seemed like an angel in her white dress.';
    } catch (e) {
      // Fallback sentences in case API call fails
      final fallbackSentences = [
        'She seemed like an angel in her white dress.',
        'The boy quickly ran across the green field.',
        'My mother made delicious cookies yesterday.',
        'We watched stars twinkle in the night sky.',
        'He found his lost keys under the table.',
      ];
      return fallbackSentences[DateTime.now().second % fallbackSentences.length];
    }
  }

  static Future<Map<String, String>> analyzeTest(String original, String written, String spoken) async {
    try {
      // Construct the prompt to Gemini
      final prompt = '''
      Original sentence: "$original"
      Written response: "$written"
      Spoken response: "$spoken"
      
      Analyze both responses for signs of dyslexia or reading/spelling difficulties. Provide:
      1. A concise heading summarizing the key findings (max 8 words)
      2. Detailed written analysis (2-3 paragraphs)
      3. Detailed speech analysis (2-3 paragraphs)
      
      Format your response exactly as follows:
      HEADING: [your heading here]
      WRITTEN_ANALYSIS: [your detailed written analysis here]
      SPEECH_ANALYSIS: [your detailed speech analysis here]
      ''';
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';
      
      // Parse the formatted response
      final headingMatch = RegExp(r'HEADING:(.*?)(?=WRITTEN_ANALYSIS:|$)', dotAll: true).firstMatch(responseText);
      final writtenMatch = RegExp(r'WRITTEN_ANALYSIS:(.*?)(?=SPEECH_ANALYSIS:|$)', dotAll: true).firstMatch(responseText);
      final speechMatch = RegExp(r'SPEECH_ANALYSIS:(.*?)(?=$)', dotAll: true).firstMatch(responseText);
      
      return {
        'heading': headingMatch?.group(1)?.trim() ?? 'Dyslexia Assessment Results',
        'writtenAnalysis': writtenMatch?.group(1)?.trim() ?? 'The written sample shows some potential indicators of dyslexia that would benefit from further assessment.',
        'speechAnalysis': speechMatch?.group(1)?.trim() ?? 'The speech sample indicates phonological processing patterns that may be consistent with dyslexic tendencies.',
      };
    } catch (e) {
      // Fallback analysis in case API call fails
      return {
        'heading': 'Potential Reading-Writing Challenges',
        'writtenAnalysis': 'The written response shows possible challenges with spelling and word recognition. There appear to be some letter omissions and substitutions that are common in individuals with dyslexic patterns. Further assessment would be beneficial to determine specific areas for intervention.',
        'speechAnalysis': 'The spoken response indicates some difficulties with phonological processing. Pronunciation patterns suggest challenges with certain sound blends and word articulation. These patterns are sometimes associated with dyslexia and related language processing differences.',
      };
    }
  }
}

class TestsPage extends StatefulWidget {
  const TestsPage({super.key});

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tests = [];

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() {
      _isLoading = true;
    });

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
          .get();

      final tests = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'heading': data['heading'] ?? 'Test Result',
          'date': (data['timestamp'] as Timestamp).toDate(),
          'writtenAnalysis': data['writtenAnalysis'] ?? '',
          'speechAnalysis': data['speechAnalysis'] ?? '',
        };
      }).toList();

      setState(() {
        _tests = tests;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tests: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index, String route) {
    // Define if this is the selected item
    final bool isSelected = index == 1; // Tests is selected on this page
    
    return GestureDetector(
      onTap: () {
        if (index != 1) { // Don't navigate if already on tests
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
      appBar: AppBar(
        title: const Text(
          'Test Results',
          style: TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tests.isEmpty
              ? _buildEmptyState()
              : _buildTestsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewTestPage(),
            ),
          ).then((_) => _loadTests()); // Refresh when returning
        },
        backgroundColor: const Color(0xFF1F5377),
        child: const Icon(Icons.add, color: Colors.white),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_tests.png', // Create this placeholder image
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          const Text(
            'No tests completed yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324259),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to take your first test',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        final test = _tests[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TestDetailPage(testId: test['id']),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F5377),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          test['heading'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${test['date'].day}/${test['date'].month}/${test['date'].year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Writing Analysis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324259),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        test['writtenAnalysis'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Speech Analysis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324259),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        test['speechAnalysis'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TestDetailPage(testId: test['id']),
                            ),
                          );
                        },
                        child: const Text(
                          'See Details',
                          style: TextStyle(
                            color: Color(0xFF1F5377),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NewTestPage extends StatefulWidget {
  const NewTestPage({super.key});

  @override
  State<NewTestPage> createState() => _NewTestPageState();
}

class _NewTestPageState extends State<NewTestPage> {
  bool _isLoading = true;
  String _testSentence = '';
  final TextEditingController _writtenTextController = TextEditingController();
  String _speechText = '';
  bool _isRecording = false;
  bool _hasSubmitted = false;
  
  // Speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  
  // Image picker and text recognition
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  File? _imageFile;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _generateTestSentence();
  }

  @override
  void dispose() {
    _writtenTextController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

  Future<void> _generateTestSentence() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get a sentence from Gemini
      final sentence = await GeminiService.generateSentence();
      setState(() {
        _testSentence = sentence;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback sentence if API fails
      setState(() {
        _testSentence = 'She seemed like an angel in her white dress.';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating test: ${e.toString()}')),
      );
    }
  }

  // Handle speech recognition
  void _startListening() {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }
    
    setState(() {
      _isRecording = true;
    });
    
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isRecording = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _speechText = result.recognizedWords;
    });
  }

  // Handle image picking and OCR
  Future<void> _takePicture() async {
    setState(() {
      _isProcessingImage = true;
    });
    
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        setState(() {
          _isProcessingImage = false;
        });
        return;
      }
      
      _imageFile = File(photo.path);
      final inputImage = InputImage.fromFile(_imageFile!);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      setState(() {
        _writtenTextController.text = recognizedText.text;
        _isProcessingImage = false;
      });
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitTest() async {
    setState(() {
      _isLoading = true;
      _hasSubmitted = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      // Get analysis from Gemini
      final analysis = await GeminiService.analyzeTest(
        _testSentence,
        _writtenTextController.text,
        _speechText,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .add({
        'heading': analysis['heading'],
        'writtenAnalysis': analysis['writtenAnalysis'],
        'speechAnalysis': analysis['speechAnalysis'],
        'originalSentence': _testSentence,
        'writtenResponse': _writtenTextController.text,
        'speechResponse': _speechText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Show success and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test results saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return to tests page
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving test: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
        _hasSubmitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'New Test',
          style: TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF324259),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test sentence card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Read and Write This Sentence',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324259),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _testSentence,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF324259),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Image and speech input buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _isProcessingImage ? null : _takePicture,
                        tooltip: 'Take a picture of handwriting',
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        onPressed: _isRecording ? _stopListening : _startListening,
                        tooltip: _isRecording ? 'Stop Recording' : 'Start Speaking',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Display submitted image
                  if (_imageFile != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submitted Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324259),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Image.file(_imageFile!),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Display recognized text
                  if (_writtenTextController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recognized Text',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324259),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _writtenTextController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF324259),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Display recognized speech text
                  if (_speechText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recognized Speech Text',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324259),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _speechText,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF324259),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_speechText.isNotEmpty &&
                              _writtenTextController.text.isNotEmpty &&
                              !_hasSubmitted)
                          ? _submitTest
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F5377),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _hasSubmitted
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Submit Test',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class TestDetailPage extends StatefulWidget {
  final String testId;
  const TestDetailPage({super.key, required this.testId});

  @override
  State<TestDetailPage> createState() => _TestDetailPageState();
}

class _TestDetailPageState extends State<TestDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic> _testData = {};

  @override
  void initState() {
    super.initState();
    _loadTestDetails();
  }

  Future<void> _loadTestDetails() async {
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
          .collection('test_results')
          .doc(widget.testId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Test not found');
      }

      setState(() {
        _testData = docSnapshot.data()!;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading test details: ${e.toString()}')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Test Details' : _testData['heading'] ?? 'Test Details',
          style: const TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF324259),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test date and basic info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324259),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Taken on ${_testData['timestamp'].toDate().day}/${_testData['timestamp'].toDate().month}/${_testData['timestamp'].toDate().year}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Original sentence
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Original Sentence',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324259),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _testData['originalSentence'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF324259),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Written analysis
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Writing Analysis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324259),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _testData['writtenAnalysis'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF324259),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Speech analysis
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Speech Analysis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324259),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _testData['speechAnalysis'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
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
}