import 'package:flutter/material.dart';
import '../main.dart';
// Import these packages after adding them to pubspec.yaml
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    // When Firebase is implemented, this would be:
    // _signInWithEmailPassword();
    
    // For demo purposes, we'll just navigate to the home page
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Home Page')),
    );
  }

  // Firebase Email/Password Authentication
  // Future<void> _signInWithEmailPassword() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //   try {
  //     if (_isLogin) {
  //       // Sign In
  //       await FirebaseAuth.instance.signInWithEmailAndPassword(
  //         email: _emailController.text.trim(),
  //         password: _passwordController.text.trim(),
  //       );
  //     } else {
  //       // Sign Up
  //       await FirebaseAuth.instance.createUserWithEmailAndPassword(
  //         email: _emailController.text.trim(),
  //         password: _passwordController.text.trim(),
  //       );
  //     }
  //     
  //     // Navigate to home
  //     if (!mounted) return;
  //     Navigator.pushReplacement(
  //       context, 
  //       MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Home Page')),
  //     );
  //   } catch (e) {
  //     // Show error
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  // Google Sign In
  // Future<void> _signInWithGoogle() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //   try {
  //     // Begin interactive sign in process
  //     final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
  //     
  //     // Get auth details from request
  //     final GoogleSignInAuthentication gAuth = await gUser!.authentication;
  //     
  //     // Create new credential for user
  //     final credential = GoogleAuthProvider.credential(
  //       accessToken: gAuth.accessToken,
  //       idToken: gAuth.idToken,
  //     );
  //     
  //     // Sign in with credential
  //     await FirebaseAuth.instance.signInWithCredential(credential);
  //     
  //     // Navigate to home
  //     if (!mounted) return;
  //     Navigator.pushReplacement(
  //       context, 
  //       MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Home Page')),
  //     );
  //   } catch (e) {
  //     // Show error
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to sign in with Google: ${e.toString()}')),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/images/lexi_rain_temp.jpeg',
                  height: 100,
                ),
                const SizedBox(height: 40),
                Text(
                  _isLogin ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF324259),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () {
                    // When Firebase is implemented:
                    // _signInWithGoogle();
                    
                    // For demo:
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Home Page')),
                    );
                  },
                  icon: Image.asset(
                    'assets/images/google_logo.png', 
                    height: 24,
                  ),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin 
                        ? 'Don\'t have an account? Sign Up' 
                        : 'Already have an account? Sign In',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}