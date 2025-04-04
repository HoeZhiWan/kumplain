# kumplain

A new Flutter project.

## Getting Started with Flutter

1. Download and install Flutter:
   - Follow the official Flutter installation guide for your operating system: [Flutter Installation](https://flutter.dev/docs/get-started/install).
   - Ensure that you have added Flutter to your system's PATH.

2. Verify the installation:
   ```bash
   flutter doctor
   ```
   - This command checks your environment and displays any missing dependencies.

3. Proceed with the steps in the "Installation" section below to set up the project.

## Features

- **User Authentication**: Secure login and registration using Firebase Authentication.
- **Complaint Submission**: Users can submit complaints with descriptions, images, and categories.
- **Real-Time Updates**: Receive notifications for complaint status updates using Firebase Cloud Messaging (FCM).
- **Complaint Tracking**: Track the status of submitted complaints in real-time.
- **Categorization**: Complaints are automatically categorized using AI for faster resolution.
- **Cross-Platform Support**: Available on Android, iOS, Web, Windows, Linux, and macOS.

## Technologies Used

- **Frontend**: Flutter
- **Backend**: Firebase (Firestore, Authentication, Cloud Storage)
- **AI Integration**: Gemini API for image analysis and categorization
- **Notifications**: Firebase Cloud Messaging (FCM)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/kumplain.git
   cd kumplain
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Adding fingerprint:
   - Retrieve the SHA-1 fingerprint for your project:
     ```bash
     cd .\\android\\
     ./gradlew signingReport
     ```
   - Copy the SHA-1 fingerprint and add it to the Firebase project settings under "Project Settings > Your Apps > Add Fingerprint".

4. Set up environmental variable:
   - Create a `.env` file at root directory with your Gemini API Key, the format is same
   as `.env.sample`.
    ```
    GEMINI_API_KEY=your_gemini_api_key
    ```

5. Run the app:
   ```bash
   flutter run
   ```

## Folder Structure

```
lib/
├── main.dart               # Entry point of the application
├── firebase_options.dart   # Firebase configuration
├── services/               # Backend services (e.g., Firestore, Auth)
├── models/                 # Data models (e.g., User, Complaint)
├── screens/                # UI screens
├── widgets/                # Reusable widgets
```

## Acknowledgments

- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/)
- [Gemini API](https://aistudio.google.com/)
