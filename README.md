# Verbix 📚
[![Copyright](https://img.shields.io/badge/License-All_Rights_Reserved-red.svg)](LICENSE.md)
[![Vertex AI](https://img.shields.io/badge/Vertex_AI-Google_Cloud-4285F4.svg)](https://cloud.google.com/vertex-ai)
[![Gemini](https://img.shields.io/badge/Gemini-AI-8E44AD.svg)](https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/gemini)
[![Platform](https://img.shields.io/badge/Platform-Flutter-02569B.svg)](https://docs.flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.7.0+-0175C2.svg)](https://dart.dev/)
[![IDX](https://img.shields.io/badge/IDX-Cloud_Platform-4285F4.svg)](https://idx.google.com/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth_&_Firestore-FFCA28.svg)](https://firebase.google.com)
[![OCR](https://img.shields.io/badge/OCR-Google_ML_Kit-4285F4.svg)](https://developers.google.com/ml-kit)

> <br/>Verbix is an innovative cross-platform application designed to support children with learning disabilities, particularly focusing on dyslexia which affects [5-10% of children worldwide](https://pmc.ncbi.nlm.nih.gov/articles/PMC6099274/#:~:text=Given%20that%20an%20estimated%205,and%20informed%20understandings%20of%20dyslexia.). The app utilizes advanced OCR through Google ML Kit, speech recognition technology, and Google's Vertex AI with Gemini models to analyze handwriting patterns and speech, providing personalized exercises and real-time feedback for improved learning outcomes. Developed entirely on Google's IDX cloud development platform.

<br/>

![image](https://github.com/user-attachments/assets/79f3d5d3-2e0d-46da-aef5-293c8244bc76)
<br/><br/>

## Key Features

### 📝 *Advanced Handwriting Analysis*
- Real-time OCR recognition using Google ML Kit for precise text analysis
- Smart detection of letter confusions, inversions, and omissions common in dyslexia
- Pattern recognition that identifies recurring mistakes across multiple exercises
- Interactive doodling exercises for letter and word formation practice
- Capture and analysis of paper-written sentences with instant feedback

### 🗣️ *Comprehensive Speech Pattern Recognition*
- Advanced speech-to-text analysis powered by cutting-edge recognition technology
- Detailed pronunciation feedback highlighting sound confusions
- Speech pattern tracking to identify improvement areas
- Word-by-word breakdown of pronunciation accuracy
- Vocal exercise modules targeting specific phonetic challenges

### 💡 *Personalized Learning Journey*
- AI-generated daily practice sets based on individual performance metrics
- 5 tailored exercises refreshed daily to target specific improvement areas
- Pre-built practice modules focusing on common dyslexia challenges
- Progress visualization through intuitive dashboard charts and graphs
- User profile customization with avatars and personal details

### 🧠 *Vertex AI & Gemini-Powered Insights*
- Sophisticated analysis of test results using Google's Vertex AI
- Gemini AI models deliver personalized recommendations based on performance patterns
- Adaptive difficulty scaling based on user improvement
- Cross-modal learning patterns detection (comparing speech vs. writing performance)
- Intelligent exercise generation that evolves with the user's progress
<br/><br/>

## App Flow

![image](https://github.com/user-attachments/assets/601fcb33-ca7e-4d12-bb32-56b6c22d7cbd)
<br/><br/><br/>

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
│   │   ├── auth_screen.dart       # Authentication interface
│   │   ├── dashboard.dart         # Analytics and progress overview
│   │   ├── home_page.dart         # Main landing page after login
│   │   ├── main_scaffold.dart     # App structure wrapper
│   │   ├── module_details.dart    # Specific module information
│   │   ├── practice_modules.dart  # Exercise collection interface
│   │   ├── practice_screen.dart   # Active practice environment
│   │   ├── splash_screen.dart     # App initialization screen
│   │   ├── tests.dart             # Assessment tools
│   │   ├── user_details.dart      # Profile and settings
│   │   └── user_settings.dart     # Configuration options
│   ├── services/
│   │   ├── custom_practice_service.dart  # Personalized exercise generation
│   │   ├── drawing_utils.dart            # Handwriting capture utilities
│   │   ├── practice_module_service.dart  # Module management
│   │   └── practice_stats_service.dart   # Progress tracking analytics
│   ├── theme/
│   │   ├── firebase_options.dart         # Firebase configuration
│   │   └── main.dart                     # App entry point
│   └── linux/                            # Platform-specific code
├── assets/
│   ├── images/
│   └── vertex-credentials.json           # Vertex AI authentication
└── .env                                  # Environment configuration
```

<br/>

## 🔧 Installation & Setup

### Prerequisites
- Flutter SDK 3.7.0 or higher
- Dart 3.7.0 or higher
- Android Studio or VS Code
- Google Cloud account with Vertex AI and Gemini API enabled
- Firebase project

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/verbix.git
   ```

2. Navigate to the project directory:
   ```bash
   cd verbix
   ```

3. Create a `.env` file in the root directory based on this template:
   ```
   GEMINI_API_KEY=your_gemini_api_key
   VERTEX_PROJECT_ID=your_google_cloud_project_id
   VERTEX_LOCATION=us-central1  # or your preferred region
   VERTEX_CREDENTIALS_PATH=assets/vertex-credentials.json
   VERTEX_API_KEY=your_vertex_api_key
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

## 👥 App Navigation & Usage


### 🚀 Initial Setup
1. Launch the app and complete the authentication process
2. Create your profile by entering your name, age, and selecting a personalized avatar
3. All profile information is securely stored in Firestore for a personalized experience

### 🏠 Home Page Navigation
The home page serves as your learning hub with access to:
- **Custom Daily Exercises**: 5 personalized activities refreshed daily based on your test results
- **Pre-made Practice Modules**: Structured learning exercises targeting common dyslexia challenges
- **Quick Test Access**: Start a new assessment to refresh your personalized learning plan
- **Profile Settings**: Access your profile via the avatar icon in the top right corner

### 🧭 Bottom Navigation Bar
The app features an intuitive navigation system with four main sections:
1. **Home**: Your personalized dashboard with daily exercises
2. **Tests**: Assessment center to evaluate your current skills
3. **Practice Modules**: Library of pre-built learning exercises
4. **Dashboard**: Visual representation of your progress and achievements

### 📊 Testing Process
1. Navigate to the Tests section and tap the "+" icon to begin a new assessment
2. You'll be presented with a test sentence to complete in two ways:
   - Write the sentence on paper and submit a photo
   - Record yourself speaking the same sentence
3. Vertex AI analyzes both inputs to identify specific improvement areas
4. Based on test results, your daily practice exercises will be automatically updated
5. Test history and progress are stored for ongoing comparison

### 🎯 Exercise Types
The app offers multiple interactive exercise formats:
- **Doodle Writing**: Practice letter and word formation using touch input
- **Paper Writing**: Write sentences on paper and capture for analysis
- **Speech Exercises**: Speak words and sentences for pronunciation feedback
- **Combined Modules**: Multi-modal exercises that integrate writing and speaking

### 👤 Profile Management
Access your profile settings through the avatar icon to:
* Update personal information (name, age)
* Change your avatar
* View achievement statistics
* Log out from your account
  
<br/>

## 👥 Team

- [**Swati Sharma**](https://github.com/swatified) - Project Lead & Developer
- [**Garima Srivastav**](https://github.com/techy4shri) - Lead UI Designer and Illustrator
- [**Abdul Wahid Khan**](https://github.com/Wahid7852) - Cloud Specialist
<br/><br/>

## License 
Copyright © 2024 Swati Sharma. All rights reserved.
See [LICENSE](LICENSE.md) for details.
<br/><br/>
