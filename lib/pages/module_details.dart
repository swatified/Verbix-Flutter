import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:verbix/services/practice_module_service.dart';
import 'package:verbix/services/drawing_utils.dart';

class ModuleDetailScreen extends StatefulWidget {
  final PracticeModule module;
  final Function(int) onProgressUpdate;

  const ModuleDetailScreen({
    super.key,
    required this.module,
    required this.onProgressUpdate,
  });

  @override
  ModuleDetailScreenState createState() => ModuleDetailScreenState();
}

class ModuleDetailScreenState extends State<ModuleDetailScreen> {
  late int currentExercise;
  bool isProcessing = false;
  String recognizedText = '';
  bool isCorrect = false;
  bool hasChecked = false;
  final ImagePicker _picker = ImagePicker();
  final textRecognizer = TextRecognizer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechText = '';
  
  List<DrawingArea?> points = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 5.0;
  bool _isProcessingDrawing = false;
  
  final Map<String, List<String>> moduleExercises = {
    'sentence_writing': [
      'The quick brown fox jumps over the lazy dog.',
      'She sells seashells by the seashore.',
      'How much wood would a woodchuck chuck?',
      'Peter Piper picked a peck of pickled peppers.',
      'All good things must come to an end.',
    ],
    'word_formation': [
      'apple',
      'banana',
      'elephant',
      'dinosaur',
      'butterfly',
    ],
    'speech_recognition': [
      'She sells seashells by the seashore',
      'The big black bug bit the big black bear',
      'Unique New York, unique New York',
      'Peter Piper picked a peck of pickled peppers',
      'Three free throws for three points',
    ],
    'phonetic_awareness': [
      'Snowflake',
      'Caterpillar',
      'Basketball',
      'Butterfly',
      'Sunshine',
    ],
    'visual_tracking': [
      'Find the pattern: 1 2 3, 1 2 3, 1 2 _',
      'Track left to right: → → → ← → → ← →',
      'Follow the pattern: A B A B B A B A A',
      'Scan for the letter D: a b c d e f g h i j k l m n o p',
      'Count the circles: ■ ● ■ ● ● ■ ● ■ ● ■ ■ ●',
    ],
    'reading_comprehension': [
      'Tom has a red ball. The ball is round. Tom likes to play with his ball. What color is Tom\'s ball?',
      'Sara went to the store. She bought milk and bread. What did Sara buy at the store?',
      'The sky is blue. The grass is green. Flowers come in many colors. What color is the grass?',
      'Ben has three pets: a dog, a cat, and a fish. How many pets does Ben have?',
      'Maya likes to read books about dinosaurs. She learns about T-Rex and Triceratops. What does Maya like to read about?',
    ],
  };

  @override
  void initState() {
    super.initState();
    currentExercise = widget.module.completedExercises;
    
    if (widget.module.type == ModuleType.speech) {
      _initSpeech();
    }
  }
  
  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }
  
  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

    Future<void> _takePhoto() async {
    setState(() {
      isProcessing = true;
      recognizedText = '';
      isCorrect = false;
      hasChecked = false;
    });
    
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        setState(() {
          isProcessing = false;
        });
        return;
      }
      
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        this.recognizedText = recognizedText.text;
        
                final currentContent = getCurrentExercise().toLowerCase();
        final cleanRecognized = this.recognizedText.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim();
        final cleanTarget = currentContent
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim();
          
        if (widget.module.id == 'sentence_writing') {
                    final targetWords = cleanTarget.split(' ');
          final recognizedWords = cleanRecognized.split(' ');
          
          int matchedWords = 0;
          for (final targetWord in targetWords) {
            if (targetWord.isNotEmpty && 
                recognizedWords.any((word) => word.contains(targetWord) || 
                targetWord.contains(word))) {
              matchedWords++;
            }
          }
          
          final matchPercentage = targetWords.isEmpty ? 
              0 : (matchedWords / targetWords.length) * 100;
          isCorrect = matchPercentage >= 100;
        } else {
                    isCorrect = cleanRecognized.isNotEmpty && (cleanRecognized.contains(cleanTarget) || 
                      cleanTarget.contains(cleanRecognized));
        }
        
        hasChecked = true;
        isProcessing = false;
      });
      
    } catch (e) {
      setState(() {
        recognizedText = 'Error: ${e.toString()}';
        isProcessing = false;
        isCorrect = false;         hasChecked = true;
      });
    }
  }
  
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
      isCorrect = false;
      hasChecked = false;
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
      
            final currentContent = getCurrentExercise().toLowerCase();
      isCorrect = _speechText.isNotEmpty && (_speechText.contains(currentContent) || 
                  currentContent.contains(_speechText));
      hasChecked = true;
    });
  }
  
  String getCurrentExercise() {
    final exercises = moduleExercises[widget.module.id] ?? ['Exercise not found'];
    if (currentExercise < exercises.length) {
      return exercises[currentExercise];
    }
    return 'Exercise not found';
  }

  void _nextExercise() {
    if (isCorrect) {
            if (currentExercise >= widget.module.completedExercises) {
                widget.onProgressUpdate(currentExercise + 1);
        
                PracticeModuleService.updateModuleProgress(
          widget.module.id, 
          currentExercise + 1
        );
        
        debugPrint('Progress updated: ${currentExercise + 1}/${widget.module.totalExercises}');
      }
      
      if (currentExercise < widget.module.totalExercises - 1) {
        setState(() {
          currentExercise += 1;
          recognizedText = '';
          _speechText = '';
          hasChecked = false;
          isCorrect = false;
          points.clear();         });
      } else {
        _completeModule();
      }
    }
  }
  
  void _previousExercise() {
    if (currentExercise > 0) {
      setState(() {
        currentExercise -= 1;
        recognizedText = '';
        _speechText = '';
        hasChecked = false;
        isCorrect = false;
      });
    }
  }

  void _completeModule() {
        widget.onProgressUpdate(widget.module.totalExercises);
    
        PracticeModuleService.updateModuleProgress(
      widget.module.id, 
      widget.module.totalExercises
    );
    
            
    debugPrint('Module completed: ${widget.module.title}');
    
        showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Module Completed!'),
        content: Text('Congratulations! You have completed the ${widget.module.title} module.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);              
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
    void _clearDrawing() {
    setState(() {
      points.clear();
      recognizedText = '';
      hasChecked = false;
      isCorrect = false;
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
    recognizedText = '';
    isCorrect = false;
    hasChecked = false;
  });
  
  try {
        final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
        final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
        final size = MediaQuery.of(context).size;
    final width = size.width - 32;     final height = 300.0;     
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);
    
        for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.areaPaint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!.point], points[i]!.areaPaint);
      }
    }
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    
    if (pngBytes != null) {
      final buffer = pngBytes.buffer;
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/drawing.png').writeAsBytes(
        buffer.asUint8List(pngBytes.offsetInBytes, pngBytes.lengthInBytes)
      );
      
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final extracted = recognizedText.text.toLowerCase().trim();
      
      setState(() {
        hasChecked = true;
        this.recognizedText = extracted.isEmpty ? "No text detected" : extracted;
        final currentContent = getCurrentExercise();
        
        if (widget.module.id == 'word_formation') {
          isCorrect = extracted.isNotEmpty && extracted.toLowerCase().trim() == currentContent.toLowerCase().trim();
        } else if (widget.module.id == 'visual_tracking') {
          if (currentContent.contains('Find the pattern')) {
            isCorrect = extracted == '3' || extracted == 'three';
          } else {
            isCorrect = _validateVisualTrackingAnswerStrict(currentContent, extracted);
          }
        } else if (widget.module.id == 'reading_comprehension') {
          isCorrect = _validateReadingComprehensionAnswerStrict(currentContent, extracted);
        }
        else {
          isCorrect = extracted.toLowerCase().trim() == currentContent.toLowerCase().trim();
        }
      });
    } else {
      if (!mounted) return;
      setState(() {
        hasChecked = true;
        recognizedText = "Error: Could not process image";
        isCorrect = false;
      });
    }
  } catch (e) {
    if (!mounted) return;
    debugPrint('Error in _processDrawing: ${e.toString()}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error processing drawing: ${e.toString()}')),
    );
    
        setState(() {
      hasChecked = true;
      recognizedText = "Error processing drawing";
      isCorrect = false;
      _isProcessingDrawing = false;
    });
  } finally {
    setState(() {
      _isProcessingDrawing = false;
    });
  }
}

bool _validateVisualTrackingAnswerStrict(String exerciseContent, String userAnswer) {
  debugPrint('Strict visual tracking validation - Exercise: $exerciseContent, Answer: $userAnswer');
  
    final cleanUserAnswer = userAnswer.trim().toLowerCase();
  debugPrint('Cleaned user answer: $cleanUserAnswer');
  
    if (exerciseContent.contains('Find the pattern')) {
        return cleanUserAnswer == '3' || cleanUserAnswer == 'three';
  } 
  else if (exerciseContent.contains('Track left to right')) {
        return cleanUserAnswer == '←' || cleanUserAnswer == 'left';
  }
  else if (exerciseContent.contains('Follow the pattern')) {
        return cleanUserAnswer == 'b';
  }
  else if (exerciseContent.contains('Scan for the letter')) {
        return cleanUserAnswer == 'd';
  }
  else if (exerciseContent.contains('Count the circles')) {
        return cleanUserAnswer == '6' || cleanUserAnswer == 'six';
  }
  
    return false;
}

bool _validateReadingComprehensionAnswerStrict(String exerciseContent, String userAnswer) {
    final cleanAnswer = userAnswer.trim().toLowerCase();
  
    if (exerciseContent.contains('Tom has a red ball')) {
    return cleanAnswer == 'red';
  } 
  else if (exerciseContent.contains('Sara went to the store')) {
        return cleanAnswer == 'milk and bread' || cleanAnswer == 'bread and milk';
  } 
  else if (exerciseContent.contains('The sky is blue')) {
    return cleanAnswer == 'green';
  } 
  else if (exerciseContent.contains('Ben has three pets')) {
    return cleanAnswer == 'three' || cleanAnswer == '3';
  } 
  else if (exerciseContent.contains('Maya likes to read books')) {
    return cleanAnswer == 'dinosaurs' || cleanAnswer == 'dinosaur';
  }
  
    return false;
}


    
  @override
  Widget build(BuildContext context) {
            if (widget.module.completedExercises >= widget.module.totalExercises) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.module.title),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Module Completed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have successfully completed ${widget.module.title}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: const Color(0xFF1F5377),
                ),
                child: const Text('Return to Modules',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
                            const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                                    PracticeModuleService.resetModuleProgress(widget.module.id);
                  
                                    widget.onProgressUpdate(0);
                  
                  setState(() {
                    currentExercise = 0;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 121, 31, 28),
                ),
                child: const Text('Practice Again'),
              ),
            ],
          ),
        ),
      );
    }

    final currentContent = getCurrentExercise();
    final bool isLastExercise = currentExercise == widget.module.totalExercises - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                                    Text(
                    'Exercise ${currentExercise + 1} of ${widget.module.totalExercises}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (currentExercise + 1) / widget.module.totalExercises,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  
                                    if (widget.module.completedExercises > 0 && 
                      widget.module.completedExercises != currentExercise)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Saved progress: ${widget.module.completedExercises}/${widget.module.totalExercises}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                                    Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shouldUseDrawingInput() 
                                ? 'Write the answer with your finger:' 
                                : (widget.module.type == ModuleType.written 
                                    ? 'Write or photograph the following:' 
                                    : 'Say the following:'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentContent,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                                    if (_shouldUseDrawingInput())
                    _buildDrawingInput()
                  else if (widget.module.type == ModuleType.written)
                    Expanded(child: _buildOCRControls())
                  else
                    Expanded(child: _buildSpeechControls()),
                  
                                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                                            currentExercise > 0
                          ? ElevatedButton(
                              onPressed: _previousExercise,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Previous'),
                            )
                          : const SizedBox(width: 88),                       
                                            ElevatedButton(
                        onPressed: isCorrect ? _nextExercise : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: Text(isLastExercise ? 'Complete Module' : 'Next'),
                      ),
                    ],
                  ),
                  
                                    const SizedBox(height: 12),
                ],
              ),
            ),
            
                        if (isProcessing || _isProcessingDrawing)
              Container(
                color: Colors.black.withValues(alpha:0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

    bool _shouldUseDrawingInput() {
    final drawingModules = ['word_formation', 'visual_tracking', 'reading_comprehension'];
    return drawingModules.contains(widget.module.id);
  }

    Widget _buildDrawingInput() {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.2,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha:0.2),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
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
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: MyCustomPainter(points: points),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
                Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _clearDrawing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Clear'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _processDrawing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Check Answer'),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
                if (hasChecked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recognized Text:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                                    (recognizedText.isEmpty || recognizedText == "No text detected") 
                      ? 'No text was recognized. Please try again with clearer writing.'
                      : recognizedText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCorrect ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCorrect ? 'Correct!' : 'Try again',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
        const Spacer(flex: 1),
      ],
    ),
  );
}

    Widget _buildOCRControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
                const Spacer(flex: 4),
        
                if (hasChecked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recognized Text:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recognizedText.isEmpty ? 'No text recognized' : recognizedText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCorrect ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCorrect ? 'Correct!' : 'Try again',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
                const Spacer(flex: 1),
      ],
    );
  }

    Widget _buildSpeechControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Press and hold the microphone to speak',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),
        
                GestureDetector(
          onTapDown: (_) => _startListening(),
          onTapUp: (_) => _stopListening(),
          onTapCancel: () => _stopListening(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        
                const Spacer(flex: 4),
        
                if (hasChecked && _speechText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You said:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _speechText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCorrect ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCorrect ? 'Correct!' : 'Try again',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Spacer(flex: 1),
      ],
    );
  }
}