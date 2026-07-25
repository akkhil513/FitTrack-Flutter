# FitTrack

FitTrack is a Flutter mobile app for a 100-day fitness challenge. It guides users through authentication, onboarding, AI-generated training plans, daily checklists, workout logging, and progress tracking.

## Features
- Sign in / sign up flow with AWS Cognito
- Onboarding questionnaire for goals, training, nutrition, and supplements
- AI-generated plan creation and polling for plan readiness
- Dashboard with Today, Plan, Log, and Profile screens
- Light/dark theme support and progress-based UI

## Tech Stack
- Flutter
- Dart
- Provider for state management
- HTTP client for API integration

## Project Structure
- lib/main.dart — app bootstrap and providers
- lib/screens/ — auth, onboarding, and dashboard screens
- lib/providers/ — auth, user, plan, and theme providers
- lib/services/ — Cognito auth and backend API services
- lib/widgets/ — shared UI helpers

## Getting Started
1. Install Flutter SDK (version used in this project: 3.12.2+)
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Notes
- The app uses backend endpoints and Cognito credentials configured in the services layer.
- If you are working against a different backend, update the URLs in lib/services/api_service.dart and lib/services/auth_service.dart.
