# Samriddhi Flow

**Samriddhi Flow** is a premium personal finance and smart budgeting PWA built with Flutter. It focuses on privacy, smart syncing, and a beautiful Material 3 design.

## Key Features
- **Smart Budgeting**: Set monthly budgets and track expenses.
- **Privacy First**: Local-first architecture with optional secure cloud sync.
- **Google Authentication**: Seamless and secure login experience.
- **PWA Offline Resilience**: Bundled fonts and icon assets for 100% offline text visibility.
- **Installable**: Works on Android, iOS, and Desktop.

## Getting Started

### Prerequisites
1.  **Flutter SDK**: Ensure you have the latest stable version (3.38+ recommended).
2.  **Firebase Project**: You need a Firebase project with **Google Authentication** enabled.

### Setup
1.  Clone the repository.
2.  Run `flutter pub get`.
3.  Configure Firebase (generated `firebase_options.dart`).

### Running the App
```bash
flutter run -d chrome
```

## Deployment

### Recommended Build Command for PWA
To ensure your icons and fonts work perfectly offline on iOS and other platforms, use this command:

```bash
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons
```

See `.agent/workflows/deploy.md` for full deployment instructions.
