import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verbix/services/custom_practice_service.dart';
import 'package:verbix/services/practice_stats_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

// Drawing area for handwriting input
class DrawingArea {
  Offset point;
  Paint areaPaint;

  DrawingArea({required this.point, required this.areaPaint});
}

class PracticeScreen extends StatefulWidget {
  final PracticeModule practice;

  const PracticeScreen({Key? key, required this.practice}) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _currentIndex = 0;
  bool _isCompleted = false;
  List<bool> _itemStatus = [];
  bool _isSubmitting = false;
  bool _isProcessingDrawing = false;
  String _recognizedText = '';
  
  // Controllers for written responses
  final List<TextEditingController> _textControllers = [];
  
  // Speech recognition (for phonetic practices)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechText = '';
  
  // Drawing capabilities
  List<DrawingArea?> points = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 5.0;
  final textRecognizer = TextRecognizer();
  
  @override
  void initState() {
    super.initState();
    _isCompleted = widget.practice.completed;
    
    // Initialize item status and text controllers
    _itemStatus = List.generate(widget.practice.content.length, (_) => false);
    
    // Initialize text controllers
    for (int i = 0; i < widget.practice.content.length; i++) {
      _textControllers.add(TextEditingController());
    }
    
    // Initialize speech recognition for phonetic practices
    if (widget.practice.type == PracticeType.phonetic) {
      _initSpeech();
    }
  }
  
  @override
  void dispose() {
    // Dispose text controllers
    for (var controller in _textControllers) {
      controller.dispose();
    }
    textRecognizer.close();
    super.dispose();
  }
  
  // Initialize speech recognition
  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
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
      _isListening = true;
      _speechText = '';
    });
    
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 5),
      localeId: 'en_US',
    );
  }
  
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }
  
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _speechText = result.recognizedWords.toLowerCase();
      
      // For phonetic exercise, check if the spoken word matches the target
      if (widget.practice.type == PracticeType.phonetic) {
        final targetWord = widget.practice.content[_currentIndex].toLowerCase();
        if (_speechText.contains(targetWord)) {
          _itemStatus[_currentIndex] = true;
        }
      }
    });
  }
  
  Future<void> _checkWrittenResponse() async {
    final response = _textControllers[_currentIndex].text.trim().toLowerCase();
    final target = widget.practice.content[_currentIndex].toLowerCase();
    
    bool isCorrect = false;
    
    // Different comparison logic based on practice type
    switch (widget.practice.type) {
      case PracticeType.letterWriting:
        isCorrect = response == target;
        break;
      case PracticeType.sentenceWriting:
        // More lenient check for sentences - remove punctuation and extra spaces
        final cleanTarget = target.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
        final cleanResponse = response.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
        isCorrect = cleanResponse == cleanTarget;
        break;
      case PracticeType.letterReversal:
        // Check if user entered either of the two options in the pair
        final options = target.split('/');
        isCorrect = options.contains(response);
        break;
      case PracticeType.vowelSounds:
        isCorrect = response == target;
        break;
      default:
        isCorrect = response == target;
    }
    
    setState(() {
      _itemStatus[_currentIndex] = isCorrect;
    });
  }
  
  Future<void> _processDrawing() async {
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw something first')),
      );
      return;
    }
    
    setState(() {
      _isProcessingDrawing = true;
    });
    
    try {
      // Convert drawing to image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // White background
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      // Use the actual size of the drawing area
      final size = MediaQuery.of(context).size;
      final width = size.width - 32; // Account for padding
      final height = 300.0; // Increased height for better recognition
      
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);
      
      // Draw the points - scale them to fit the image size
      for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != null && points[i + 1] != null) {
          canvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.areaPaint);
        } else if (points[i] != null && points[i + 1] == null) {
          canvas.drawPoints(ui.PointMode.points, [points[i]!.point], points[i]!.areaPaint);
        }
      }
      
      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (pngBytes != null) {
        final buffer = pngBytes.buffer;
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/drawing.png').writeAsBytes(
          buffer.asUint8List(pngBytes.offsetInBytes, pngBytes.lengthInBytes)
        );
        
        // Use ML Kit for text recognition
        final inputImage = InputImage.fromFile(file);
        final recognizedText = await textRecognizer.processImage(inputImage);
        
        // Process the recognized text
        final extracted = recognizedText.text.toLowerCase().trim();
        
        // Add debugging
        debugPrint('Raw recognized text: $extracted');
        
        setState(() {
          _recognizedText = extracted;
          debugPrint('Set recognizedText to: $_recognizedText');
          
          // Only set to true if it's actually correct
          _itemStatus[_currentIndex] = false;
          
          // Check if the recognized text matches the target
          final target = widget.practice.content[_currentIndex].toLowerCase();
          
          if (widget.practice.type == PracticeType.letterWriting) {
            // For letters, be more lenient as OCR might struggle with single letters
            if (extracted.contains(target) || target.contains(extracted)) {
              _itemStatus[_currentIndex] = true;
            }
          } else if (widget.practice.type == PracticeType.sentenceWriting) {
            // For sentences, use more lenient comparison
            final cleanTarget = target.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
            final cleanExtracted = extracted.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
            
            // Check if the extracted text contains at least 75% of the target words
            final targetWords = cleanTarget.split(' ');
            final extractedWords = cleanExtracted.split(' ');
            
            int matchedWords = 0;
            for (final targetWord in targetWords) {
              if (targetWord.isNotEmpty && extractedWords.any((word) => 
                  word.isNotEmpty && 
                  (word.contains(targetWord) || targetWord.contains(word)))) {
                matchedWords++;
              }
            }
            
            final matchPercentage = targetWords.isEmpty ? 0 : (matchedWords / targetWords.length) * 100;
            
            // Debug the matching process
            print('Target: $cleanTarget');
            print('Extracted: $cleanExtracted');
            print('Match percentage: $matchPercentage%');
            
            if (matchPercentage >= 75) {
              _itemStatus[_currentIndex] = true;
            }
          } else if (widget.practice.type == PracticeType.letterReversal) {
            // Process letter reversal - check for either option in pair
            final options = target.split('/');
            if (options.any((option) => extracted.contains(option))) {
              _itemStatus[_currentIndex] = true;
            }
          } else if (widget.practice.type == PracticeType.vowelSounds) {
            // For vowel sounds, be a bit more lenient
            if (extracted == target || 
                extracted.contains(target) ||
                _compareVowelSounds(extracted, target)) {
              _itemStatus[_currentIndex] = true;
            }
          } else {
            // For other types, use more specific checks
            if (extracted == target) {
              _itemStatus[_currentIndex] = true;
            }
          }
          
          // Add a final debug statement
          debugPrint('Final status: ${_itemStatus[_currentIndex]}');
        });
      }
    } catch (e) {
      debugPrint('Error in _processDrawing: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing drawing: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isProcessingDrawing = false;
      });
    }
  }
  
  // Helper method for vowel sound comparison
  bool _compareVowelSounds(String extracted, String target) {
    // Get all vowels from both strings
    final targetVowels = target.replaceAll(RegExp(r'[^aeiou]'), '');
    final extractedVowels = extracted.replaceAll(RegExp(r'[^aeiou]'), '');
    
    // If vowel count and pattern are similar, consider it correct
    return targetVowels.length == extractedVowels.length &&
          targetVowels.length > 0 &&
          extractedVowels.length > 0;
  }
  
  void _clearDrawing() {
    setState(() {
      points.clear();
      _recognizedText = '';
    });
  }
  
  void _nextItem() {
    if (_currentIndex < widget.practice.content.length - 1) {
      setState(() {
        _currentIndex++;
        _speechText = '';
        _recognizedText = '';
        points.clear();
      });
    } else {
      _completePractice();
    }
  }
  
  void _previousItem() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _speechText = '';
        _recognizedText = '';
        points.clear();
      });
    }
  }
  
  Future<void> _completePractice() async {
    // Check if all items have been answered correctly
    final allCorrect = _itemStatus.every((status) => status);
    
    if (!allCorrect) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not all items completed'),
          content: const Text('Please complete all items correctly before finishing.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Mark the practice as completed
      await CustomPracticeService.markPracticeCompleted(widget.practice.id);
      
      // Update practice statistics
      await PracticeStatsService.updateStatsAfterCompletion(
        widget.practice.type.toString().split('.').last
      );
      
      setState(() {
        _isCompleted = true;
        _isSubmitting = false;
      });
      
      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Practice Completed!'),
            content: const Text('Great job! You have successfully completed this practice.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to home
                },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing practice: ${e.toString()}')),
      );
    }
  }
  
  String _getInstructionText() {
    switch (widget.practice.type) {
      case PracticeType.letterWriting:
        return 'Draw the letter below:';
      case PracticeType.sentenceWriting:
        return 'Write the sentence below:';
      case PracticeType.phonetic:
        return 'Say the word below out loud:';
      case PracticeType.letterReversal:
        return 'Draw one of the words from the pair:';
      case PracticeType.vowelSounds:
        return 'Write the word with the correct vowel sounds:';
      default:
        return 'Complete the exercise:';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // If already completed, show completed screen
    if (_isCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.practice.title),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF324259),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Practice Completed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324259),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have already completed ${widget.practice.title}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5377),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      );
    }
    
    final currentItem = widget.practice.content[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.practice.title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF324259),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / widget.practice.content.length,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1F5377)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Item ${_currentIndex + 1} of ${widget.practice.content.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Instructions
                Text(
                  _getInstructionText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324259),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Target content display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
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
                  child: Text(
                    currentItem,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324259),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Input method based on practice type
                if (widget.practice.type == PracticeType.phonetic)
                  _buildPhoneticInput()
                else if (widget.practice.type == PracticeType.letterWriting || 
                         widget.practice.type == PracticeType.vowelSounds ||
                         widget.practice.type == PracticeType.letterReversal ||
                         widget.practice.type == PracticeType.sentenceWriting) // Added sentenceWriting
                  _buildDrawingInput()
                else
                  _buildWrittenInput(),
                
                // Input feedback
                if (_itemStatus[_currentIndex])
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Correct!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const Spacer(),
                
                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    if (_currentIndex > 0)
                      ElevatedButton(
                        onPressed: _previousItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox(width: 80), // Placeholder for alignment
                    
                    // Next/Finish button
                    ElevatedButton(
                      onPressed: _itemStatus[_currentIndex]
                          ? (_currentIndex < widget.practice.content.length - 1
                              ? _nextItem
                              : _completePractice)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F5377),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: Text(
                        _currentIndex < widget.practice.content.length - 1
                            ? 'Next'
                            : 'Finish',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Overlay loading indicator
          if (_isSubmitting || _isProcessingDrawing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPhoneticInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Click the microphone and say the word above',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isListening ? _stopListening : _startListening,
          icon: Icon(_isListening ? Icons.stop : Icons.mic),
          label: Text(_isListening ? 'Stop' : 'Start Speaking'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isListening ? Colors.red : const Color(0xFF1F5377),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        if (_speechText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _itemStatus[_currentIndex] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _itemStatus[_currentIndex] ? Colors.green : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You said:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _speechText,
                  style: TextStyle(
                    fontSize: 18,
                    color: _itemStatus[_currentIndex] ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildDrawingInput() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Draw with your finger in the box below',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing from 8 to 4
          
          // Drawing canvas - adjusted height
          Container(
            height: MediaQuery.of(context).size.height * 0.18, // Reduced from 0.2 to 0.18
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RepaintBoundary(
              child: GestureDetector(
                onPanDown: (details) {
                  setState(() {
                    points.add(
                      DrawingArea(
                        point: details.localPosition,
                        areaPaint: Paint()
                          ..color = selectedColor
                          ..strokeWidth = strokeWidth
                          ..strokeCap = StrokeCap.round
                          ..isAntiAlias = true,
                      ),
                    );
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    points.add(
                      DrawingArea(
                        point: details.localPosition,
                        areaPaint: Paint()
                          ..color = selectedColor
                          ..strokeWidth = strokeWidth
                          ..strokeCap = StrokeCap.round
                          ..isAntiAlias = true,
                      ),
                    );
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    points.add(null);
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: MyCustomPainter(points: points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8), // Reduced spacing from 12 to 8
          
          // Drawing controls - Made more compact
          Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    ElevatedButton.icon(
      onPressed: _clearDrawing,
      icon: const Icon(Icons.clear, size: 18, color: Colors.white),
      label: const Text(
        'Clear', 
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced vertical padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Less rounded corners
        ),
      ),
    ),
    const SizedBox(width: 16),
    ElevatedButton.icon(
      onPressed: _processDrawing,
      icon: const Icon(Icons.check, size: 18, color: Colors.white),
      label: const Text(
        'Analyze', 
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F5377),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced vertical padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Less rounded corners
        ),
      ),
    ),
  ],
),
          
          const SizedBox(height: 8), // Reduced spacing from 12 to 8
          
          // Display recognized text with a smaller fixed height
          Container(
            height: MediaQuery.of(context).size.height * 0.10, // Reduced from 0.15 to 0.10
            width: double.infinity,
            padding: const EdgeInsets.all(8), // Reduced padding from 12 to 8
            decoration: BoxDecoration(
              color: _recognizedText.isEmpty
                  ? Colors.grey.withOpacity(0.1)
                  : (_itemStatus[_currentIndex] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _recognizedText.isEmpty
                    ? Colors.grey
                    : (_itemStatus[_currentIndex] ? Colors.green : Colors.red),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognized:',
                    style: TextStyle(
                      fontSize: 12, // Reduced from 14 to 12
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing from 4 to 2
                  Text(
                    _recognizedText.isEmpty ? 'Draw and click "Analyze" to see the recognized text' : _recognizedText,
                    style: TextStyle(
                      fontSize: 14, // Reduced from 18 to 14
                      color: _recognizedText.isEmpty
                          ? Colors.grey
                          : (_itemStatus[_currentIndex] ? Colors.green : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWrittenInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textControllers[_currentIndex],
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 18),
          maxLines: widget.practice.type == PracticeType.sentenceWriting ? 3 : 1,
          onChanged: (value) {
            // For sentence writing, check as typing
            if (widget.practice.type == PracticeType.sentenceWriting) {
              _checkWrittenResponse();
            }
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _checkWrittenResponse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F5377),
          ),
          child: const Text('Check Answer'),
        ),
      ],
    );
  }
}

// Custom painter for drawing
class MyCustomPainter extends CustomPainter {
  final List<DrawingArea?> points;

  MyCustomPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Paint background white
    Paint background = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

    // Draw points with thicker lines for better visibility
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.areaPaint);
      } else if (points[i] != null && points[i + 1] == null) {
        // For single points, draw a small circle for better visibility
        canvas.drawCircle(points[i]!.point, points[i]!.areaPaint.strokeWidth / 2, points[i]!.areaPaint);
      }
    }
  }

  @override
  bool shouldRepaint(MyCustomPainter oldDelegate) {
    // Always repaint when points change to ensure immediate feedback
    return true;
  }
}