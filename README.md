# Verbix 📚
[![Copyright](https://img.shields.io/badge/License-All_Rights_Reserved-red.svg)](LICENSE.md)
[![Vertex AI](https://img.shields.io/badge/Vertex_AI-Google_Cloud-4285F4.svg)](https://cloud.google.com/vertex-ai)
[![Gemini](https://img.shields.io/badge/Gemini-AI-8E44AD.svg)](https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/gemini)
[![Platform](https://img.shields.io/badge/Platform-Flutter-02569B.svg)](https://docs.flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.7.0+-0175C2.svg)](https://dart.dev/)
[![IDX](https://img.shields.io/badge/IDX-Cloud_Platform-4285F4.svg)](https://idx.google.com/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth_&_Firestore-FFCA28.svg)](https://firebase.google.com)
[![OCR](https://img.shields.io/badge/OCR-Google_ML_Kit-4285F4.svg)](https://developers.google.com/ml-kit)

> <br/> Dyslexia is a learning disability which affects [5-10% of children worldwide](https://pmc.ncbi.nlm.nih.gov/articles/PMC6099274/#:~:text=Given%20that%20an%20estimated%205,and%20informed%20understandings%20of%20dyslexia.). Verbix is a cross-platform app that uses OCR and speech recognition to help children with dyslexia improve their reading and writing skills through personalized exercises and real-time feedback. Built with Flutter, it runs seamlessly on Android, iOS, and Web while maintaining an optimized APK despite rich multimedia features and advanced AI capabilities.

<br/>

![mockup](https://github.com/user-attachments/assets/5727de7a-f60a-4ba7-887c-352a00b201b7)
<br/><br/>

## Key Features 🌟

### *Advanced Handwriting Analysis*

- Real-time OCR detects dyslexia-specific letter confusions and patterns
- Interactive doodling and paper analysis with animated mascot feedback

### *Comprehensive Speech Pattern Recognition*

- Speech-to-text identifies pronunciation challenges and sound confusions
- Targeted vocal exercises with fun sound effects and animations

### *Gamified Learning Experience*

- Progressive level system with character interactions and audio feedback
- Multiple background music options for immersive learning environment

### *Personalized Learning Journey*

- 5 daily AI-generated exercises based on individual performance
- Visual progress tracking with adaptive difficulty adjustment

### *Custom-Tuned Vertex AI & Gemini Integration*

- Specialized Gemini model optimized for dyslexia patterns
- Cross-modal analysis comparing speech and writing with adaptive recommendations

### *Parent Dashboard & Monitoring*

- Comprehensive analytics tracking child's progress and improvement areas
- Real-time activity monitoring with recurring mistake analysis and reports

<br/>

## App Flow

![process_flow](https://github.com/user-attachments/assets/30237e72-19bf-4eb7-a778-7e85a5f5069c)

**Process Flow at a Glance:**
- **Dual Authentication**: Separate flows for children and parents
- **Personalized Onboarding**: Custom setup based on user type and needs
- **Integrated Monitoring**: Parents can track child progress in real-time
- **Adaptive Learning Path**: AI-driven exercise selection based on performance data
- **Multi-Modal Practice**: Speech, writing, and combined exercise formats

<br/>

<h3 style="text-decoration: underline;">🛠️ Technical Architecture</h3>

<table>
  <tr>
    <td><b>🔷 Core Framework</b></td>
    <td>
      • Flutter (cross-platform UI toolkit)</br>
      • Dart 3.7.0+ programming language</br>
      • Material Design components
    </td>
  </tr>
  <tr>
    <td><b>☁️ Backend & Storage</b></td>
    <td>
      • Firebase (backend-as-a-service)</br>
      • Cloud Firestore (NoSQL database)</br>
      • Firebase Authentication</br>
      • Firebase Storage (for user assets)
    </td>
  </tr>
  <tr>
    <td><b>🧠 AI & Intelligence</b></td>
    <td>
      • Google ML Kit (text recognition)</br>
      • Vertex AI (advanced analysis)</br>
      • Gemini AI Models (personalized insights)</br>
      • Speech-to-Text API
    </td>
  </tr>
  <tr>
    <td><b>📊 Data & Analytics</b></td>
    <td>
      • FL Chart (data visualization)</br>
      • Firebase Analytics (usage metrics)</br>
      • Custom analytics engine
    </td>
  </tr>
  <tr>
    <td><b>🔧 Development Tools</b></td>
    <td>
      • Google IDX Platform (cloud development)</br>
      • Git version control</br>
      • Flutter DevTools</br>
      • Firebase CLI
    </td>
  </tr>
  <tr>
    <td><b>📱 Device Capabilities</b></td>
    <td>
      • Camera integration</br>
      • Microphone access</br>
      • Local storage</br>
      • Push notifications
    </td>
  </tr>
</table>
<br/><br/>

## Project Structure

```
verbix/
├── lib/
│   ├── pages/
│   │   ├── auth_screen.dart              # Authentication interface
│   │   ├── dashboard.dart                # Analytics and progress overview
│   │   ├── home_page.dart                # Main landing page with level system
│   │   ├── main_scaffold.dart            # App structure wrapper
│   │   ├── module_details.dart           # Specific module information
│   │   ├── parent_child_dashboard.dart   # Child monitoring from parent view
│   │   ├── parent_dashboard.dart         # Parent monitoring interface
│   │   ├── parent_details.dart           # Parent profile and settings
│   │   ├── practice_modules.dart         # Exercise collection interface
│   │   ├── practice_screen.dart          # Active practice environment
│   │   ├── splash_screen.dart            # App initialization screen
│   │   ├── tests.dart                    # Assessment tools
│   │   ├── user_details.dart             # Profile and settings
│   │   ├── user_settings.dart            # Configuration options
│   │   ├── user_type_selection.dart      # Child/Parent selection screen
│   │   └── wrong_word_details.dart       # Mistake analysis interface
│   ├── services/
│   │   ├── audio_service.dart            # Background music & SFX manager
│   │   ├── custom_practice_service.dart  # Personalized exercise generation
│   │   ├── daily_scoring_service.dart    # Daily progress tracking
│   │   ├── drawing_utils.dart            # Handwriting capture utilities
│   │   ├── firebase_service.dart         # Firebase integration
│   │   ├── practice_module_service.dart  # Module management
│   │   └── practice_stats_service.dart   # Progress tracking analytics
│   ├── main.dart                         # App entry point
│   ├── firebase_options.dart             # Firebase configuration
│   └── linux/                            # Platform-specific code
├── assets/
│   ├── images/
│   ├── gifs/                             # Mascot animation files
│   ├── audio/                            # Background music & sound effects
│   └── vertex-credentials.json           # Vertex AI authentication
└── .env                                  # Environment configuration
```

<br/>

## 🔧 *Installation & Setup*

### Prerequisites
- Flutter SDK 3.7.0 or higher
- Dart 3.7.0 or higher
- Android Studio or VS Code
- Google Cloud account with Vertex AI and Gemini API enabled
- Firebase project

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/swatified/Verbix-Flutter
   ```

2. Navigate to the project directory:
   ```bash
   cd Verbix-Flutter
   ```

3. Create a `.env` file in the root directory based on this template:
   ```
   GEMINI_API_KEY=your_gemini_api_key
   VERTEX_PROJECT_ID=your_google_cloud_project_id
   VERTEX_LOCATION=us-central1  # or your preferred region
   VERTEX_CREDENTIALS_PATH=assets/vertex-credentials.json
   VERTEX_API_KEY=your_vertex_api_key
   TUNED_MODEL_ID=your_tuned_gemini_model_id
   ```

4. Firebase Setup:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password and Google Sign-In)
   - Create a Firestore database with appropriate security rules
   - Download your `google-services.json` for Android or `GoogleService-Info.plist` for iOS
   - Place the configuration files in their respective platform folders

5. Vertex AI Setup:
   - Visit [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable Vertex AI API and Gemini API
   - Create a service account with appropriate permissions
   - Download the service account key as JSON
   - Save it as `vertex-credentials.json` in the assets folder

6. Install dependencies:
   ```bash
   flutter pub get
   ```

7. Run the app in debug mode:
   ```bash
   flutter run
   ```

8. Build the APK:
   ```bash
   # For debug APK
   flutter build apk --debug
   
   # For release APK (requires signing configuration)
   flutter build apk --release
   ```
   The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`
   
<br/>

## 📱 *App Navigation & Usage*

<table>
  <tr>
    <td width="20%"><b>Setup</b></td>
    <td>Authenticate, create profile with avatar and preferences</td>
  </tr>
  <tr>
    <td><b>Home Page</b></td>
    <td>Access personalized exercises with level progression, practice modules, tests, and profile settings</td>
  </tr>
  <tr>
    <td><b>Navigation</b></td>
    <td>Four sections: Home, Tests, Practice Modules, and Dashboard with animated mascot guide</td>
  </tr>
  <tr>
    <td><b>Testing</b></td>
    <td>Complete written and spoken tests for custom-tuned Vertex AI analysis and personalized recommendations</td>
  </tr>
  <tr>
    <td><b>Exercises</b></td>
    <td>Interactive formats with background music, sound effects, and animations for doodle writing, paper analysis, speech practice, and combined modules</td>
  </tr>
  <tr>
    <td><b>Profile</b></td>
    <td>Manage personal details, avatar, view statistics, and account settings with audio preferences</td>
  </tr>
  <tr>
    <td><b>Parent Dashboard</b></td>
    <td>Monitor child's activity through comprehensive visualizations, track recurring mistakes, and view detailed progress reports</td>
  </tr>
</table>

<br/>

## 👥 Team

- [**Swati Sharma**](https://github.com/swatified) - Project Lead & Developer
- [**Garima**](https://github.com/techy4shri) - Lead Designer and Illustrator
- [**Abdul Wahid Khan**](https://github.com/Wahid7852) - Cloud Specialist
<br/><br/>

## 📄 License
Copyright © 2024 Swati Sharma. All rights reserved.
See [LICENSE](LICENSE.md) for details.
<br/><br/>
