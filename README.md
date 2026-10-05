# Pet Hotel Booking System

A Flutter-based pet hotel management system for CCE106 course project.

## Overview

The Pet Hotel Booking System is a comprehensive mobile and web application designed for managing pet hotel operations. It provides separate interfaces for customers and administrators to handle bookings, pet management, and hotel operations.

## Features

### Customer Features
- User registration and authentication (Email/Password + Google Sign-in)
- Pet profile management with vaccination records
- Room browsing with real-time availability
- Booking system with date selection and add-on services
- QR code-based check-in passes
- Payment processing (cash and simulated e-wallet)
- Booking history and reviews

### Admin Features
- Dashboard with operational metrics
- Booking approval and management
- Pet vaccination record validation
- QR code scanning for check-in/check-out
- Payment recording and tracking
- Room and service management
- Customer review moderation

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Authentication, Firestore, Cloud Storage)
- **State Management**: Provider
- **Architecture**: Multi-tier with service layer pattern
- **Security**: Firebase Security Rules for data protection

## Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Firebase CLI
- Android Studio / VS Code
- Firebase project setup

### Installation

1. Clone the repository:
```bash
git clone https://github.com/jmansaludo560022-coder/cce106-pethotelsystem.git
cd cce106-pethotelsystem
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Set up your Firebase project
   - Add your `google-services.json` for Android
   - Add your `GoogleService-Info.plist` for iOS
   - Deploy Firestore security rules

4. Run the application:
```bash
flutter run
```

## Project Structure

```
lib/
├── core/           # Core utilities, constants, and widgets
├── features/       # Feature-specific screens and components
├── models/         # Data models
├── providers/      # State management
├── services/       # Business logic and Firebase integration
└── main.dart       # Application entry point
```

## Firebase Configuration

The app uses Firebase for:
- Authentication (Email/Password + Google)
- Firestore for real-time database
- Cloud Storage for file uploads
- Security rules for data protection

## Course Information

- **Course**: CCE 106 - Applications Development & Emerging Technologies
- **Institution**: University of Mindanao, College of Computing Education
- **Term**: 1st Term SY 2026-2027

## License

This project is created for educational purposes as part of CCE106 coursework.

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
