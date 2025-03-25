import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PracticeModulesScreen extends StatefulWidget {
  const PracticeModulesScreen({Key? key}) : super(key: key);

  @override
  _PracticeModulesScreenState createState() => _PracticeModulesScreenState();
}

class _PracticeModulesScreenState extends State<PracticeModulesScreen> {
  List<PracticeModule> modules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeModules();
  }

  Future<void> _initializeModules() async {
    // Define the default modules
    final defaultModules = [
      PracticeModule(
        id: 'sentence_writing',
        title: 'Sentence Writing',
        description: 'Practice writing sentences with dyslexic challenges',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'word_formation',
        title: 'Word Formation',
        description: 'Form words from letters (OCR based)',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'speech_recognition',
        title: 'Speech Recognition',
        description: 'Practice speaking sentences clearly',
        type: ModuleType.speech,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'phonetic_awareness',
        title: 'Phonetic Awareness',
        description: 'Practice with phonetic rules and sounds',
        type: ModuleType.speech,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'visual_tracking',
        title: 'Visual Tracking',
        description: 'Improve visual tracking skills with exercises',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'memory_exercises',
        title: 'Memory Exercises',
        description: 'Strengthen working memory with exercises',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
      PracticeModule(
        id: 'reading_comprehension',
        title: 'Reading Comprehension',
        description: 'Read and answer questions about short texts',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
    ];

    // Load saved progress
    final prefs = await SharedPreferences.getInstance();
    final savedModules = prefs.getString('practice_modules');

    if (savedModules != null) {
      final List<dynamic> decodedModules = json.decode(savedModules);
      modules = decodedModules
          .map((moduleJson) => PracticeModule.fromJson(moduleJson))
          .toList();
    } else {
      modules = defaultModules;
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final modulesJson = modules.map((module) => module.toJson()).toList();
    await prefs.setString('practice_modules', json.encode(modulesJson));
  }

  void _updateProgress(PracticeModule module, int completed) {
    setState(() {
      final index = modules.indexWhere((m) => m.id == module.id);
      if (index != -1) {
        modules[index] = module.copyWith(completedExercises: completed);
        _saveProgress();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Practice Modules',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return ModuleCard(
                  module: module,
                  onTap: () {
                    // Navigate to the specific module screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModuleDetailScreen(
                          module: module,
                          onProgressUpdate: (completed) {
                            _updateProgress(module, completed);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

enum ModuleType { written, speech }

class PracticeModule {
  final String id;
  final String title;
  final String description;
  final ModuleType type;
  final int totalExercises;
  final int completedExercises;

  PracticeModule({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.totalExercises,
    required this.completedExercises,
  });

  double get progressPercentage => 
      totalExercises > 0 ? completedExercises / totalExercises : 0.0;

  PracticeModule copyWith({
    String? id,
    String? title,
    String? description,
    ModuleType? type,
    int? totalExercises,
    int? completedExercises,
  }) {
    return PracticeModule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      totalExercises: totalExercises ?? this.totalExercises,
      completedExercises: completedExercises ?? this.completedExercises,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'totalExercises': totalExercises,
      'completedExercises': completedExercises,
    };
  }

  factory PracticeModule.fromJson(Map<String, dynamic> json) {
    return PracticeModule(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: json['type'] == 'written' ? ModuleType.written : ModuleType.speech,
      totalExercises: json['totalExercises'],
      completedExercises: json['completedExercises'],
    );
  }
}

class ModuleCard extends StatelessWidget {
  final PracticeModule module;
  final VoidCallback onTap;

  const ModuleCard({
    Key? key,
    required this.module,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      module.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: module.type == ModuleType.written
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      module.type == ModuleType.written ? "Written" : "Speech",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: module.type == ModuleType.written
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                module.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${module.completedExercises}/${module.totalExercises}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(module.progressPercentage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: module.progressPercentage,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      module.progressPercentage == 1.0
                          ? Colors.green
                          : Colors.blue,
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleDetailScreen extends StatefulWidget {
  final PracticeModule module;
  final Function(int) onProgressUpdate;

  const ModuleDetailScreen({
    Key? key,
    required this.module,
    required this.onProgressUpdate,
  }) : super(key: key);

  @override
  _ModuleDetailScreenState createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  late int currentExercise;

  @override
  void initState() {
    super.initState();
    currentExercise = widget.module.completedExercises;
  }

  void _completeExercise() {
    if (currentExercise < widget.module.totalExercises) {
      setState(() {
        currentExercise += 1;
      });
      widget.onProgressUpdate(currentExercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
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
              value: widget.module.progressPercentage,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 24),
            // Exercise content would go here - for demonstration, we'll show a placeholder
            Expanded(
              child: _buildExerciseContent(widget.module.type),
            ),
            if (currentExercise < widget.module.totalExercises)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _completeExercise,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Complete Exercise'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseContent(ModuleType type) {
    // This would be replaced with actual exercise content based on module ID and type
    final isCompleted = currentExercise >= widget.module.totalExercises;

    if (isCompleted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Module Completed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Great job finishing all exercises',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Sample exercise content
    switch (type) {
      case ModuleType.written:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.edit, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Written Exercise',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Write the following sentence:\n\n"She sells seashells by the seashore."',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Upload image functionality would go here
                },
                child: const Text('Submit Image'),
              ),
            ],
          ),
        );

      case ModuleType.speech:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Speech Exercise',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Say the following phrase:\n\n"How much wood would a woodchuck chuck?"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.mic, size: 64),
                onPressed: () {
                  // Record audio functionality would go here
                },
              ),
              const SizedBox(height: 8),
              const Text('Press to record'),
            ],
          ),
        );
    }
  }
}
