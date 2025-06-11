import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verbix/services/custom_practice_service.dart';
import 'package:verbix/services/practice_stats_service.dart';
import 'package:verbix/services/audio_service.dart'; 
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verbix/services/daily_scoring_service.dart';


class DrawingArea {
  Offset point;
  Paint areaPaint;

  DrawingArea({required this.point, required this.areaPaint});
}


enum FeedbackState {
  correct,
  wrong,
  noText,
}

class PracticeScreen extends StatefulWidget {
  final PracticeModule practice;

  const PracticeScreen({super.key, required this.practice});

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
  bool _showingFeedback = false;
  
    final AudioService _audioService = AudioService();
  
    final List<TextEditingController> _textControllers = [];
  
    final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechText = '';
  
    List<DrawingArea?> points = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 5.0;
  final textRecognizer = TextRecognizer();
  
    final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  
  @override
  void initState() {
    super.initState();
    _isCompleted = widget.practice.completed;
    
        _itemStatus = List.generate(widget.practice.content.length, (_) => false);
    
        for (int i = 0; i < widget.practice.content.length; i++) {
      _textControllers.add(TextEditingController());
    }
    
        if (widget.practice.type == PracticeType.phonetic) {
      _initSpeech();
    }
  }

    Future<void> _recordAttemptWithWord(bool isCorrect) async {
    try {
            final currentWord = widget.practice.content[_currentIndex];
      
      await DailyScoringService.recordAttempt(
        isCorrect: isCorrect,
        practiceId: widget.practice.id,
        practiceType: widget.practice.type.toString().split('.').last,
        wordOrText: currentWord,
      );
      
      debugPrint('Recorded attempt in scoring system: $isCorrect, word=$currentWord');
    } catch (e) {
      debugPrint('Error recording attempt in scoring: $e');
    }
  }
  
  @override
  void dispose() {
        for (var controller in _textControllers) {
      controller.dispose();
    }
    textRecognizer.close();
    super.dispose();
  }
  
    Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
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
    
        if (widget.practice.type == PracticeType.phonetic) {
      final targetWord = widget.practice.content[_currentIndex].toLowerCase();
      bool isCorrect = _speechText.contains(targetWord);
      
      if (isCorrect) {
        _itemStatus[_currentIndex] = true;
                _recordAttemptWithWord(true);
                _showFeedbackPopup(FeedbackState.correct);
      } else if (_speechText.isNotEmpty) {
                _recordAttemptWithWord(false);
                _showFeedbackPopup(FeedbackState.wrong);
      }
    }
  });
}
  
  Future<void> _checkWrittenResponse() async {
  final response = _textControllers[_currentIndex].text.trim().toLowerCase();
  final target = widget.practice.content[_currentIndex].toLowerCase();
  
  bool isCorrect = false;
  
    switch (widget.practice.type) {
    case PracticeType.letterWriting:
      isCorrect = response == target;
      break;
    case PracticeType.sentenceWriting:
            final cleanTarget = target.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
      final cleanResponse = response.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
      isCorrect = cleanResponse == cleanTarget;
      break;
    case PracticeType.letterReversal:
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

    await _recordAttemptWithWord(isCorrect);
  
    if (response.isEmpty) {
    _showFeedbackPopup(FeedbackState.noText);
  } else if (isCorrect) {
    _showFeedbackPopup(FeedbackState.correct);
  } else {
    _showFeedbackPopup(FeedbackState.wrong);
  }
}
  
  Future<void> _processDrawing() async {
  if (points.isEmpty) {
    _showFeedbackPopup(FeedbackState.noText);
    return;
  }
  
  setState(() {
    _isProcessingDrawing = true;
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
      
            debugPrint('Raw recognized text: $extracted');
      
      bool isCorrect = false;       
      setState(() {
                if (extracted.isEmpty) {
          _recognizedText = "No text detected";
        } else {
          _recognizedText = extracted;
        }
        debugPrint('Recognized text set to: "$_recognizedText"');
        
                _itemStatus[_currentIndex] = false;
        
                final target = widget.practice.content[_currentIndex].toLowerCase();
        
        if (widget.practice.type == PracticeType.letterWriting) {
                    debugPrint('Letter writing check: extracted="$extracted", target="$target"');
                    if (extracted == target) {
            isCorrect = true;
            _itemStatus[_currentIndex] = true;
            debugPrint('Letter match found: ${_itemStatus[_currentIndex]}');
          }
        } else if (widget.practice.type == PracticeType.sentenceWriting) {
                    final cleanTarget = target.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
          final cleanExtracted = extracted.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
          
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
          
                    debugPrint('Target: $cleanTarget');
          debugPrint('Extracted: $cleanExtracted');
          debugPrint('Match percentage: $matchPercentage%');
          
          if (matchPercentage >= 75) {
            isCorrect = true;
            _itemStatus[_currentIndex] = true;
          }
        } else if (widget.practice.type == PracticeType.letterReversal) {
                    final options = target.split('/');
          if (options.any((option) => extracted.contains(option))) {
            isCorrect = true;
            _itemStatus[_currentIndex] = true;
          }
        } else if (widget.practice.type == PracticeType.vowelSounds) {
                    if (extracted == target) {
            isCorrect = true;
            _itemStatus[_currentIndex] = true;
          }
        } else {
                    if (extracted == target) {
            isCorrect = true;
            _itemStatus[_currentIndex] = true;
          }
        }
        
                debugPrint('Final status: ${_itemStatus[_currentIndex]}');
      });
      
            if (extracted.isNotEmpty) {
        await _recordAttemptWithWord(isCorrect);
      }
      
            if (extracted.isEmpty) {
        _showFeedbackPopup(FeedbackState.noText);
      } else if (_itemStatus[_currentIndex]) {
        _showFeedbackPopup(FeedbackState.correct);
      } else {
        _showFeedbackPopup(FeedbackState.wrong);
      }
    }
  } catch (e) {
      if (!mounted) return;
      debugPrint('Error in _processDrawing: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing drawing: ${e.toString()}')),
      );
    
        await _recordAttemptWithWord(false);
    
        _showFeedbackPopup(FeedbackState.noText);
  } finally {
    setState(() {
      _isProcessingDrawing = false;
            if (_recognizedText.isEmpty) {
        _recognizedText = "No text detected";
                if (!_itemStatus[_currentIndex]) {
          _itemStatus[_currentIndex] = false;
        }
        
                _showFeedbackPopup(FeedbackState.noText);
      }
    });
  }
}
  
    void _showFeedbackPopup(FeedbackState state) {
        if (_showingFeedback) return;
    
    setState(() {
      _showingFeedback = true;
    });
    
    String gifAsset;
    String heading;
    String message;
    Color headerColor;
    
    switch (state) {
      case FeedbackState.correct:
        gifAsset = 'assets/gifs/correct.gif';
        heading = 'Great job!';
        message = 'Your answer is correct. Keep up the good work!';
        headerColor = Colors.green;
        _audioService.playCorrectSound();         break;
      case FeedbackState.wrong:
        gifAsset = 'assets/gifs/lexi_shocked.gif';
        heading = 'Oops!';
        message = 'Your answer is incorrect. Keep practicing!';
        headerColor = const Color.fromARGB(255, 194, 185, 18);
        _audioService.playWrongSound();         break;
      case FeedbackState.noText:
        gifAsset = 'assets/gifs/lexi_confused.gif';
        heading = 'No Text Detected';
        message = 'I couldn\'t read your answer. Please try again.';
        headerColor = const Color.fromARGB(255, 114, 63, 151);
        _audioService.playWrongSound();         break;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _showingFeedback = false;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                ),

                                SizedBox(
                  height: 120,
                  width: 120,
                  child: Image.asset(
                    gifAsset,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),

                                Text(
                  heading,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF324259),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _showingFeedback = false;
                    });
                    
                                        if (state == FeedbackState.correct && _itemStatus[_currentIndex]) {
                      _nextItem();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: headerColor,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    state == FeedbackState.correct ? 'Continue' : 'Try Again',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            await CustomPracticeService.markPracticeCompleted(widget.practice.id);
      
            await PracticeStatsService.updateStatsAfterCompletion(
        widget.practice.type.toString().split('.').last
      );
      
            await _recordPracticeCompletion();
      
      setState(() {
        _isCompleted = true;
        _isSubmitting = false;
      });
      
            if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Practice Completed!'),
            content: const Text('Great job! You have successfully completed this practice.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);                   Navigator.pop(context);                 },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
      
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing practice: ${e.toString()}')),
        );
      }
    }
  
    Future<void> _recordPracticeCompletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
            final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
            final dailyStatsRef = FirebaseFirestore.instance
          .collection('userStats')
          .doc('${user.uid}_$dateStr');
      
            final docSnapshot = await dailyStatsRef.get();
      
      final practiceId = widget.practice.id;
      final practiceType = widget.practice.type.toString().split('.').last;
      
      if (docSnapshot.exists) {
                final data = docSnapshot.data() as Map<String, dynamic>;
        final practiceIds = List<String>.from(data['practiceIds'] ?? []);
        
        if (practiceIds.contains(practiceId)) {
          debugPrint('Practice $practiceId already recorded for today, skipping');
          return;         }
        
                await dailyStatsRef.update({
          'completedPractices': FieldValue.increment(1),
          'practiceIds': FieldValue.arrayUnion([practiceId]),
          'practiceTypes': FieldValue.arrayUnion([practiceType]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        debugPrint('Updated existing stats document for $dateStr with practice $practiceId');
      } else {
                await dailyStatsRef.set({
          'userId': user.uid,
          'date': dateStr,
          'completedModules': 0,           'moduleIds': [],           'completedPractices': 1,           'practiceIds': [practiceId],
          'practiceTypes': [practiceType],
          'timestamp': FieldValue.serverTimestamp(),
        });

        debugPrint('Created new stats document for $dateStr with practice $practiceId');
      }

            final verificationDoc = await dailyStatsRef.get();
      if (verificationDoc.exists) {
        final data = verificationDoc.data() as Map<String, dynamic>;
        final practiceIds = List<String>.from(data['practiceIds'] ?? []);
        debugPrint('Verification: Document contains ${practiceIds.length} practices: $practiceIds');
      } else {
        debugPrint('ERROR: Failed to verify document - not found after save!');
      }
      
      debugPrint('Practice completion recorded: $practiceId on $dateStr');
      
            await _storeLocalPracticeCompletion(practiceId);
      
    } catch (e) {
      debugPrint('Error recording practice completion: $e');
          }
  }

    Future<void> _storeLocalPracticeCompletion(String practiceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

            final completedPractices = prefs.getStringList('completed_practices:$dateStr') ?? [];

      if (!completedPractices.contains(practiceId)) {
        completedPractices.add(practiceId);
        await prefs.setStringList('completed_practices:$dateStr', completedPractices);
        debugPrint('Stored practice $practiceId in local storage');
      }
    } catch (e) {
      debugPrint('Error storing local practice completion: $e');
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
      }
  }
  
    Future<void> _takePhoto() async {
  setState(() {
    _isProcessingDrawing = true;
    _recognizedText = '';
    _itemStatus[_currentIndex] = false;
  });
  
  try {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) {
      setState(() {
        _isProcessingDrawing = false;
      });
      return;
    }
    
    _imageFile = File(photo.path);
    final inputImage = InputImage.fromFilePath(photo.path);
    final recognizedText = await textRecognizer.processImage(inputImage);
    
    final extractedText = recognizedText.text.trim();
    
    bool isCorrect = false;     
    setState(() {
      _recognizedText = extractedText.isEmpty 
          ? "No text detected in image" 
          : extractedText;
      
            if (extractedText.isEmpty) {
        _itemStatus[_currentIndex] = false;
        _isProcessingDrawing = false;
        _showFeedbackPopup(FeedbackState.noText);
        return;
      }
      
            final currentContent = widget.practice.content[_currentIndex].toLowerCase();
      final cleanRecognized = extractedText.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
      final cleanTarget = currentContent
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
        
            if (cleanRecognized.isEmpty) {
        _itemStatus[_currentIndex] = false;
        _isProcessingDrawing = false;
        _showFeedbackPopup(FeedbackState.noText);
        return;
      }
        
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
      _itemStatus[_currentIndex] = isCorrect;
      _isProcessingDrawing = false;
    });
    
        await _recordAttemptWithWord(isCorrect);
    
        if (_itemStatus[_currentIndex]) {
      _showFeedbackPopup(FeedbackState.correct);
    } else {
      _showFeedbackPopup(FeedbackState.wrong);
    }
    
  } catch (e) {
    setState(() {
      _recognizedText = 'Error: ${e.toString()}';
      _isProcessingDrawing = false;
      _itemStatus[_currentIndex] = false;
    });
    
        await _recordAttemptWithWord(false);
    
    _showFeedbackPopup(FeedbackState.noText);
  }
}

    Future<void> _processImageWithOCR(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      final extractedText = recognizedText.text.trim();
      debugPrint('OCR extracted text: $extractedText');
      
      bool isCorrect = false;
      
      setState(() {
        _recognizedText = extractedText.isEmpty 
            ? "No text detected in image" 
            : extractedText;
        
                if (extractedText.isEmpty) {
          _itemStatus[_currentIndex] = false;
          _showFeedbackPopup(FeedbackState.noText);
          return;
        }
        
                final target = widget.practice.content[_currentIndex].toLowerCase();
        final extracted = extractedText.toLowerCase();
        
                final cleanTarget = target.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        final cleanExtracted = extracted.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        
                if (cleanExtracted.isEmpty) {
          _itemStatus[_currentIndex] = false;
          _showFeedbackPopup(FeedbackState.noText);
          return;
        }
        
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
        
                debugPrint('Target: $cleanTarget');
        debugPrint('Extracted: $cleanExtracted');
        debugPrint('Match percentage: $matchPercentage%');
        
        isCorrect = matchPercentage >= 75;
        
        if (isCorrect) {
          _itemStatus[_currentIndex] = true;
        } else {
          _itemStatus[_currentIndex] = false;
        }
      });
      
            await _recordAttemptWithWord(isCorrect);
      
            if (isCorrect) {
        _showFeedbackPopup(FeedbackState.correct);
      } else {
        _showFeedbackPopup(FeedbackState.wrong);
      }
      
    } catch (e) {
        if (!mounted) return;
        debugPrint('Error in OCR processing: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: ${e.toString()}')),
        );
        
        setState(() {
          _itemStatus[_currentIndex] = false;
        });
      
      _showFeedbackPopup(FeedbackState.noText);
    } finally {
      setState(() {
        _isProcessingDrawing = false;
      });
    }
  }
  
  Widget _buildOCRControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                ElevatedButton.icon(
          onPressed: _takePhoto,
          icon: const Icon(Icons.camera_alt,color: Colors.white, size:16),
          label: const Text('Take Photo',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F5377),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),             minimumSize: const Size(80, 28),             shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
                if (_imageFile != null)
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
                if (_recognizedText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _itemStatus[_currentIndex] ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _itemStatus[_currentIndex] ? Colors.green : Colors.red,
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
                  _recognizedText,
                  style: TextStyle(
                    fontSize: 16,
                    color: _itemStatus[_currentIndex] ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _itemStatus[_currentIndex] ? Icons.check_circle : Icons.cancel,
                      color: _itemStatus[_currentIndex] ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _itemStatus[_currentIndex] ? 'You got this one!' : 'Try again',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _itemStatus[_currentIndex] ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
        if (_isCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.practice.title,
            style: const TextStyle(
              color: Color(0xFF324259),
              fontWeight: FontWeight.bold,
            ),
          ),
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
                  foregroundColor: Colors.white,
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
        title: Text(widget.practice.title,
          style: const TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF324259),
        elevation: 0,
      ),
      body: Stack(
        children: [
                    Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                
                                Text(
                  _getInstructionText(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF324259),
                  ),
                ),
                const SizedBox(height: 4),
                
                                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha:0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    currentItem,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324259),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                
                                if (widget.practice.type == PracticeType.phonetic)
                  _buildPhoneticInput()
                else if (widget.practice.type == PracticeType.sentenceWriting)
                  _buildOCRControls()                 else if (widget.practice.type == PracticeType.letterWriting || 
                         widget.practice.type == PracticeType.vowelSounds ||
                         widget.practice.type == PracticeType.letterReversal)
                  _buildDrawingInput()
                else
                  _buildWrittenInput(),
                
                                if (_itemStatus[_currentIndex] && (_recognizedText.isNotEmpty || widget.practice.type != PracticeType.letterWriting))
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha:0.1),
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
                
                                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                      const SizedBox(width: 40),                     
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
          
                    if (_isSubmitting || _isProcessingDrawing)
            Container(
              color: Colors.black.withValues(alpha:0.3),
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
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        if (_speechText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _itemStatus[_currentIndex] ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
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
        if (widget.practice.type == PracticeType.sentenceWriting) {
      return _buildImageCaptureInput();
    }
    
        return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.15,             width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),               boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha:0.2),                   spreadRadius: 1,
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
                  borderRadius: BorderRadius.circular(8),                   child: CustomPaint(
                    painter: MyCustomPainter(points: points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 4),           
                    Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _clearDrawing,
                icon: const Icon(Icons.clear, size: 14, color: Colors.white),                 label: const Text(
                  'Clear', 
                  style: TextStyle(fontSize: 12, color: Colors.white),                 ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),                   minimumSize: const Size(70, 28),                   shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),               ElevatedButton.icon(
                onPressed: _processDrawing,
                icon: const Icon(Icons.check, size: 14, color: Colors.white),                 label: const Text(
                  'Analyze', 
                  style: TextStyle(fontSize: 12, color: Colors.white),                 ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5377),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),                   minimumSize: const Size(80, 28),                   shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),           
                    Container(
            height: MediaQuery.of(context).size.height * 0.06,
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _recognizedText.isEmpty
                  ? Colors.grey.withValues(alpha:0.1)
                  : (_itemStatus[_currentIndex] ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _recognizedText.isEmpty
                    ? Colors.grey
                    : (_itemStatus[_currentIndex] ? Colors.green : Colors.red),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recognized:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                                    _recognizedText.isEmpty 
                      ? 'Draw and click "Analyze"' 
                      : _recognizedText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _recognizedText.isEmpty
                        ? Colors.grey
                        : (_itemStatus[_currentIndex] ? Colors.green : Colors.red),
                  ),
                  maxLines: 1,                   overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
    Widget _buildImageCaptureInput() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
                    Container(
            height: MediaQuery.of(context).size.height * 0.25,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha:0.5)),
            ),
            child: _imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Take a picture of your written sentence',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          
          const SizedBox(height: 8),
          
                    ElevatedButton.icon(
            onPressed: () => _captureImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F5377),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(80, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
                    Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _recognizedText.isEmpty
                    ? Colors.grey.withValues(alpha:0.1)
                    : (_itemStatus[_currentIndex] ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _recognizedText.isEmpty
                      ? Colors.grey
                      : (_itemStatus[_currentIndex] ? Colors.green : Colors.red),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Recognized Text:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_recognizedText.isNotEmpty)
                        Icon(
                          _itemStatus[_currentIndex] ? Icons.check_circle : Icons.error,
                          color: _itemStatus[_currentIndex] ? Colors.green : Colors.red,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _recognizedText.isEmpty
                            ? 'Take a picture to scan text'
                            : _recognizedText,
                        style: TextStyle(
                          fontSize: 14,
                          color: _recognizedText.isEmpty
                              ? Colors.grey
                              : (_itemStatus[_currentIndex] ? Colors.green[800] : Colors.red[800]),
                        ),
                      ),
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
  
    Future<void> _captureImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessingDrawing = true;       });
      
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedFile == null) {
        setState(() {
          _isProcessingDrawing = false;
        });
        return;
      }
      
      final File imageFile = File(pickedFile.path);
      setState(() {
        _imageFile = imageFile;
      });
      
            await _processImageWithOCR(imageFile);
      
    } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: ${e.toString()}')),
        );
        setState(() {
          _isProcessingDrawing = false;
        });
      
      _showFeedbackPopup(FeedbackState.noText);
    }
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


class MyCustomPainter extends CustomPainter {
  final List<DrawingArea?> points;

  MyCustomPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
        Paint background = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

        for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.areaPaint);
      } else if (points[i] != null && points[i + 1] == null) {
                canvas.drawCircle(points[i]!.point, points[i]!.areaPaint.strokeWidth / 2, points[i]!.areaPaint);
      }
    }
  }

  @override
  bool shouldRepaint(MyCustomPainter oldDelegate) {
        return true;
  }
}