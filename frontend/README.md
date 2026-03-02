# Bajaj Document Processing System - Flutter Frontend

A cross-platform mobile and web application for the Bajaj Document Processing System.

## Features

- Document upload and submission
- Real-time processing status tracking
- Approval workflow for ASM users
- Analytics dashboard for HQ users
- Conversational AI chat assistant
- In-app notifications

## Architecture

This project follows Clean Architecture principles with feature-based organization:

```
lib/
├── core/                 # Core functionality
│   ├── constants/       # App constants
│   ├── error/          # Error handling
│   ├── network/        # HTTP client
│   ├── router/         # Navigation
│   ├── theme/          # Theming
│   └── utils/          # Utilities
├── features/           # Feature modules
│   ├── auth/          # Authentication
│   ├── submission/    # Document submission
│   ├── approval/      # Approval workflow
│   ├── analytics/     # Analytics dashboard
│   ├── chat/          # Chat assistant
│   └── notifications/ # Notifications
└── main.dart          # App entry point
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2.0 or higher
- Dart SDK 3.2.0 or higher

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run code generation:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run the app:
```bash
flutter run
```

### Running Tests

```bash
# Unit and widget tests
flutter test

# Integration tests
flutter test integration_test
```

## State Management

This project uses Riverpod for state management with code generation for type-safe providers.

## API Configuration

Update the base URL in `lib/core/constants/api_constants.dart` to point to your backend API.

## Bajaj Branding

The app follows Bajaj brand guidelines:
- Primary Color: Dark Blue (#003087)
- Secondary Color: Light Blue (#00A3E0)
- Background: White (#FFFFFF)
