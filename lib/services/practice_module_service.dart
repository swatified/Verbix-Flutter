import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// Enum for module types
enum ModuleType { written, speech }

// Practice module model class
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

// PracticeModuleService to manage modules across the app
class PracticeModuleService {
  static const String _modulesKey = 'practice_modules';
  static List<PracticeModule>? _cachedModules;
  static final StreamController<List<PracticeModule>> _moduleStreamController = 
      StreamController<List<PracticeModule>>.broadcast();
  
  // Get stream for reactive UI updates
  static Stream<List<PracticeModule>> get moduleStream => _moduleStreamController.stream;
  
  // Get default modules
  static List<PracticeModule> getDefaultModules() {
    return [
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
        id: 'reading_comprehension',
        title: 'Reading Comprehension',
        description: 'Read and answer questions about short texts',
        type: ModuleType.written,
        totalExercises: 5,
        completedExercises: 0,
      ),
    ];
  }
  
  // Initialize the service
  static Future<void> initialize() async {
    await getModules();
  }

  // Get modules from SharedPreferences
  static Future<List<PracticeModule>> getModules() async {
    // Return cached modules if available
    if (_cachedModules != null) {
      return _cachedModules!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final savedModules = prefs.getString(_modulesKey);
    
    if (savedModules != null) {
      try {
        final List<dynamic> decodedModules = json.decode(savedModules);
        _cachedModules = decodedModules
            .map((moduleJson) => PracticeModule.fromJson(moduleJson))
            .toList();
        
        // Make sure all existing modules are included
        final defaultModules = getDefaultModules();
        for (final defaultModule in defaultModules) {
          final existingModuleIndex = _cachedModules!.indexWhere((m) => m.id == defaultModule.id);
          if (existingModuleIndex == -1) {
            _cachedModules!.add(defaultModule);
          }
        }
      } catch (e) {
        print('Error loading saved modules: $e');
        _cachedModules = getDefaultModules();
        // Save the default modules to fix corrupt data
        await _saveModules(_cachedModules!);
      }
    } else {
      _cachedModules = getDefaultModules();
      // Save the default modules for first-time initialization
      await _saveModules(_cachedModules!);
    }
    
    // Notify listeners
    _moduleStreamController.add(_cachedModules!);
    
    return _cachedModules!;
  }
  
  // Get popular modules (subset of all modules)
  static Future<List<PracticeModule>> getPopularModules() async {
    final allModules = await getModules();
    // Return first 4 modules as popular
    return allModules.take(4).toList();
  }
  
  // Get a single module by ID
  static Future<PracticeModule?> getModuleById(String id) async {
    final modules = await getModules();
    final moduleIndex = modules.indexWhere((m) => m.id == id);
    
    if (moduleIndex != -1) {
      return modules[moduleIndex];
    }
    return null;
  }
  
  // Update a module's progress
  static Future<void> updateModuleProgress(String moduleId, int completedExercises) async {
    if (_cachedModules == null) {
      await getModules();
    }
    
    final moduleIndex = _cachedModules!.indexWhere((m) => m.id == moduleId);
    
    if (moduleIndex != -1) {
      // Only update if the new completion count is higher than the current one
      if (completedExercises > _cachedModules![moduleIndex].completedExercises) {
        _cachedModules![moduleIndex] = _cachedModules![moduleIndex].copyWith(
          completedExercises: completedExercises
        );
        
        await _saveModules(_cachedModules!);
        // Notify listeners
        _moduleStreamController.add(_cachedModules!);
        
        print('Module "$moduleId" progress updated: $completedExercises');
      }
    }
  }
  
  // Reset a module's progress
  static Future<void> resetModuleProgress(String moduleId) async {
    if (_cachedModules == null) {
      await getModules();
    }
    
    final moduleIndex = _cachedModules!.indexWhere((m) => m.id == moduleId);
    
    if (moduleIndex != -1) {
      _cachedModules![moduleIndex] = _cachedModules![moduleIndex].copyWith(
        completedExercises: 0
      );
      
      await _saveModules(_cachedModules!);
      // Notify listeners
      _moduleStreamController.add(_cachedModules!);
      
      print('Module "$moduleId" progress reset');
    }
  }
  
  // Save modules to SharedPreferences
  static Future<void> _saveModules(List<PracticeModule> modules) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final modulesJson = modules.map((module) => module.toJson()).toList();
      await prefs.setString(_modulesKey, json.encode(modulesJson));
      print('Modules saved successfully: ${modulesJson.length} modules');
    } catch (e) {
      print('Error saving modules: $e');
    }
  }
  
  // Dispose resources
  static void dispose() {
    _moduleStreamController.close();
  }
}