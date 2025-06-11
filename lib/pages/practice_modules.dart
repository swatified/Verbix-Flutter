import 'package:flutter/material.dart';
import 'package:verbix/services/practice_module_service.dart';

import 'module_details.dart';

class PracticeModulesScreen extends StatefulWidget {
  const PracticeModulesScreen({super.key});

  @override
  PracticeModulesScreenState createState() => PracticeModulesScreenState();
}

class PracticeModulesScreenState extends State<PracticeModulesScreen> {
  List<PracticeModule> modules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();

    PracticeModuleService.moduleStream.listen((updatedModules) {
      setState(() {
        modules = updatedModules;
      });
    });
  }

  Future<void> _loadModules() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedModules = await PracticeModuleService.getModules();
      setState(() {
        modules = loadedModules;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading modules: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Practice Modules',
          style: TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return ModuleCard(
                    module: module,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ModuleDetailScreen(
                                module: module,
                                onProgressUpdate: (completed) {
                                  PracticeModuleService.updateModuleProgress(
                                    module.id,
                                    completed,
                                  );
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

class ModuleCard extends StatelessWidget {
  final PracticeModule module;
  final VoidCallback onTap;

  const ModuleCard({super.key, required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
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
                      color:
                          module.type == ModuleType.written
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      module.type == ModuleType.written ? "Written" : "Speech",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            module.type == ModuleType.written
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
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
