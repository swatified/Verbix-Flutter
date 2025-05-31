import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentDetailsScreen extends StatefulWidget {
  const ParentDetailsScreen({super.key});

  @override
  State<ParentDetailsScreen> createState() => _ParentDetailsScreenState();
}

class _ParentDetailsScreenState extends State<ParentDetailsScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }
  
  Future<void> _checkExistingData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // If no user is signed in, redirect to login
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // Check if parent data already exists
      final parentDoc = await FirebaseFirestore.instance.collection('parents').doc(user.uid).get();
      
      if (parentDoc.exists) {
        // If data exists, redirect to parent dashboard
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/parent_dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking data: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _saveParentDetails() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      // Create parent profile using the same email as the child account
      await FirebaseFirestore.instance.collection('parents').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Navigate to parent dashboard
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/parent_dashboard');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving details: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading && _errorMessage == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/lexi_rest.webp',
                      height: 130,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Parent Account Setup',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324259),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete your profile to monitor your child\'s progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                    
                    // Parent details form
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 40),
                    
                    // Continue button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveParentDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D8AA8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Complete Setup',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
} 