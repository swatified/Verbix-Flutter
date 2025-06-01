import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:verbix/services/audio_service.dart';
import 'auth_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  
  int _selectedAvatarIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  // Audio settings
  String _selectedMusicTrack = 'desert';
  bool _musicEnabled = true;
  bool _soundEffectsEnabled = true;
  final AudioService _audioService = AudioService();
  
  // List of avatar images to choose from
  final List<String> _avatarImages = [
    'assets/images/avatar1.webp',
    'assets/images/avatar2.webp',
    'assets/images/avatar3.webp',
    'assets/images/avatar4.webp',
    'assets/images/avatar5.webp',
    'assets/images/avatar6.webp',
    'assets/images/avatar7.webp',
    'assets/images/avatar8.webp',
    'assets/images/avatar9.webp',
  ];
  
  // Music track options
  final List<Map<String, dynamic>> _musicTracks = [
    {'id': 'desert', 'name': 'Desert Vibes', 'icon': Icons.beach_access},
    {'id': 'lofi', 'name': 'Lo-Fi Study', 'icon': Icons.headphones},
    {'id': 'funny', 'name': 'Funny Tunes', 'icon': Icons.mood},
    {'id': 'funky', 'name': 'Funky Beats', 'icon': Icons.music_note},
    {'id': 'chill-gaming', 'name': 'Chill Gaming', 'icon': Icons.sports_esports},
    {'id': 'blue', 'name': 'Blue Mood', 'icon': Icons.nights_stay},
    {'id': 'spring', 'name': 'Spring Morning', 'icon': Icons.eco},
    {'id': 'coffee', 'name': 'Coffee Shop', 'icon': Icons.coffee},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
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
          .get();
      
      if (docSnapshot.exists) {
        setState(() {
          _userData = docSnapshot.data();
          _firstNameController.text = _userData?['firstName'] ?? '';
          _lastNameController.text = _userData?['lastName'] ?? '';
          _ageController.text = _userData?['age']?.toString() ?? '';
          _selectedAvatarIndex = _userData?['avatarIndex'] ?? 0;
          
          // Load audio settings
          _selectedMusicTrack = _userData?['musicTrack'] ?? 'desert';
          _musicEnabled = _userData?['musicEnabled'] ?? true;
          _soundEffectsEnabled = _userData?['soundEffectsEnabled'] ?? true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveUserDetails() async {
    // Validate inputs
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    
    // Parse age
    int? age;
    try {
      age = int.parse(_ageController.text.trim());
      if (age <= 0 || age > 120) {
        throw FormatException('Invalid age range');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      // Update user details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'age': age,
        'avatarIndex': _selectedAvatarIndex,
        'musicTrack': _selectedMusicTrack,
        'musicEnabled': _musicEnabled,
        'soundEffectsEnabled': _soundEffectsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update audio service settings
      await _audioService.changeMusicTrack(_selectedMusicTrack);
      await _audioService.setMusicEnabled(_musicEnabled);
      await _audioService.setSoundEffectsEnabled(_soundEffectsEnabled);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated successfully')),
      );
      
      // Return to previous screen
      Navigator.pop(context, true); // Pass true to indicate changes were made
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving details: ${e.toString()}')),
      );
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF324259)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                        // Profile header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Your Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 16),
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF324259),
                                child: CircleAvatar(
                                  radius: 47,
                                  backgroundImage: AssetImage(
                                    _avatarImages[_selectedAvatarIndex],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userData?['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Avatar selection
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
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
                                'Change Avatar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _avatarImages.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedAvatarIndex = index;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _selectedAvatarIndex == index
                                                ? const Color(0xFF324259)
                                                : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.asset(
                                            _avatarImages[index],
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Personal information
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
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
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _ageController,
                                decoration: const InputDecoration(
                                  labelText: 'Age',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Music selection
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
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
                                'Music Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Music toggle
                              SwitchListTile(
                                title: const Text(
                                  'Enable Background Music',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF324259),
                                  ),
                                ),
                                subtitle: const Text(
                                  'Play music while using the app',
                                ),
                                value: _musicEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _musicEnabled = value;
                                  });
                                  // Preview the change
                                  if (_musicEnabled) {
                                    _audioService.playBackgroundMusic();
                                  } else {
                                    _audioService.pauseBackgroundMusic();
                                  }
                                },
                                activeColor: const Color(0xFF1F5377),
                              ),
                              
                              // Sound effects toggle
                              SwitchListTile(
                                title: const Text(
                                  'Enable Sound Effects',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF324259),
                                  ),
                                ),
                                subtitle: const Text(
                                  'Play sounds for correct/incorrect answers',
                                ),
                                value: _soundEffectsEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _soundEffectsEnabled = value;
                                  });
                                },
                                activeColor: const Color(0xFF1F5377),
                              ),
                              
                              const Divider(),
                              const SizedBox(height: 8),
                              
                              // Music selection heading
                              const Text(
                                'Choose Music Track',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324259),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Music tracks list
                              ...List.generate(_musicTracks.length, (index) {
                                final track = _musicTracks[index];
                                return RadioListTile<String>(
                                  title: Text(
                                    track['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF324259),
                                    ),
                                  ),
                                  secondary: Icon(
                                    track['icon'],
                                    color: const Color(0xFF1F5377),
                                  ),
                                  value: track['id'],
                                  groupValue: _selectedMusicTrack,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedMusicTrack = value;
                                      });
                                      // Preview the music change
                                      _audioService.changeMusicTrack(value);
                                    }
                                  },
                                  activeColor: const Color(0xFF1F5377),
                                  selected: _selectedMusicTrack == track['id'],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveUserDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F5377),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            // Sign Out Button (positioned at the bottom left)
                            Positioned(
                              left: 0,
                              bottom: 110,
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                    if (!mounted) return;
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) => const AuthScreen(),
                                      ),
                                        (route) => false,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error signing out: ${e.toString()}')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(213, 186, 65, 57),
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 68),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Lexi Mascot (overlapping from the right)
                            Container(
                              width: 180,
                              height: 180,
                              child: Image.asset(
                                'assets/images/lexi_floating.webp',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
            ),
    );
  }
}