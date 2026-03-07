# Bill Buddy

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0.2-orange?style=for-the-badge)

**A smart companion for bills, budgets, and informal money tracking**

[Features](#features) • [Architecture](#architecture) • [Tech Stack](#tech-stack) • [Getting Started](#getting-started)

</div>

---

## Overview

Bill Buddy is a personal finance management app built with Flutter and Firebase. It helps users track recurring bills, set category budgets, manage informal money lending/borrowing between people, and stay on top of due dates through smart notifications — all in a clean, warm-toned UI.

---

## Features

### Dashboard
The home screen gives a financial snapshot at a glance:
- **Greeting card** with today's date and month context
- **Bills summary** — total month spend, overdue count, upcoming bills in the next 7 days
- **Dues snapshot** — net informal money position (owed to you vs. you owe), showing up to 3 active people
- **Budgets snapshot** — overall monthly budget progress bar with health indicator (On track / Approaching limit / Over budget) and top 2 worst-performing categories
- **Overdue bills section** — direct view of unpaid bills past their due date
- **Upcoming bills** — next 7 days timeline with amounts
- **Notifications bell** — sheet showing all overdue and today-due bills

### Bills
Full bill lifecycle management:
- **Categories** — Utilities, Rent, EMI, Credit Card, Subscriptions, Education, Other
- **Recurring schedules** — Monthly, Quarterly, Half-yearly, Yearly with automatic due date rollover
- **Smart reminders** — configurable per-bill notifications (5 days before, 2 days before, on due day) via local notifications
- **Month-scoped view** — shows current month's bills split into Unpaid and Paid sections
- **One-tap mark paid** with visual feedback
- **Swipe to delete** with 4-second undo toast
- **Add / Edit bill** — full form with category picker, amount, notes, frequency, reminder toggles

### Dues
Track informal money lending and borrowing between people:
- **Add transactions** — "They owe me" or "I owe them" with optional description, date, and due date
- **Person cards** — grouped by person with net balance, color-coded (green = owed to you, red = you owe), gradient initials avatar
- **Filter pills** — All / Owe Me / I Owe
- **Summary card** — total to receive, total to pay, net position
- **Person detail screen** — full transaction history for one person, unsettled first then settled, overdue badges, "Mark Settled" per transaction, swipe to delete
- **Settle all** — one-tap to mark all transactions with a person as settled
- **PDF export** — generate and share a dues statement PDF per person
- **Collapsible settled history** section

### Budgets
Monthly spending limits per category:
- Set a limit for any bill category
- Spend is computed live from current month's bills
- Progress bars with color-coded thresholds (green < 75%, orange ≥ 75%, red = exceeded)
- Automatically resets each month (limits are persistent; spend is derived from bills)

### Insights
Spending analytics accessible from Profile:
- Monthly category breakdown
- Trend comparisons across months

### Profile
- Display name, email, profile photo (stored in Firebase Storage)
- Account information section
- **Your Preferences** — push notifications, email notifications, due reminders, timezone, currency (INR / USD / EUR / GBP / JPY / AUD)
- Navigate to Insights from profile
- Sign out

### Settings
- Currency preference
- Notification toggles
- Privacy Policy (rendered in-app)
- About screen (version, build, contact, legal links)

### Authentication & Security
- Email / password sign-in and registration via Firebase Auth
- Biometric authentication (fingerprint / Face ID) via `local_auth`
- Auth guard on all protected routes
- Each user's data is fully isolated under `users/{uid}/` in Firestore

---

## Architecture

```
lib/
├── app.dart                        # MaterialApp, providers, routes
├── main.dart                       # Firebase init, notification setup, entry point
│
├── data/
│   ├── models/
│   │   ├── bill_model.dart         # Bill entity with copyWith, toMap, fromMap
│   │   ├── budget_model.dart       # Budget limit entity
│   │   ├── due_model.dart          # Due transaction entity
│   │   └── user_model.dart         # User profile entity
│   └── repositories/
│       ├── bills_repository.dart   # Firestore CRUD + recurring rollover logic
│       ├── budgets_repository.dart # Firestore CRUD for budgets
│       ├── dues_repository.dart    # Firestore CRUD + settle logic for dues
│       └── user_repository.dart    # Firestore + Storage for user profile
│
├── presentation/
│   ├── state/
│   │   ├── app_settings_provider.dart  # Currency preference (SharedPreferences)
│   │   ├── bills_provider.dart         # Auth-scoped real-time bill stream
│   │   ├── budgets_provider.dart       # Auth-scoped real-time budget stream
│   │   ├── dues_provider.dart          # Auth-scoped real-time dues stream
│   │   └── user_provider.dart          # Auth-scoped user profile stream
│   ├── screens/
│   │   ├── auth_wrapper.dart           # Auth state routing
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── home_shell.dart             # 5-tab bottom nav shell
│   │   ├── dashboard_screen.dart       # Home tab
│   │   ├── bills_screen.dart           # Bills tab
│   │   ├── add_bill_screen.dart        # Add / edit bill form
│   │   ├── dues_screen.dart            # Dues tab
│   │   ├── person_dues_screen.dart     # Per-person transaction detail
│   │   ├── due_analytics_screen.dart   # Dues PDF export and analytics
│   │   ├── budgets_screen.dart         # Budgets tab
│   │   ├── insights_screen.dart        # Spending analytics
│   │   ├── profile_screen.dart         # Profile tab
│   │   ├── settings_screen.dart        # App settings
│   │   └── about_screen.dart           # App info, legal
│   └── widgets/
│       ├── auth_guard.dart             # Redirects unauthenticated routes
│       └── category_logo.dart          # Category icon widget
│
└── services/
    └── notification_service.dart       # Local notification scheduling/cancellation
```

**State management pattern:** Each provider subscribes to Firebase Auth state changes. When the user signs in, the provider opens a real-time Firestore stream scoped to that `uid`. On sign-out, streams are cancelled and local state is cleared. This means providers are always in sync with the authenticated user and clean up automatically.

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **UI Framework** | Flutter 3.11+ / Dart 3+ | Cross-platform (Android, iOS) |
| **State Management** | Provider 6 | Reactive, scoped state |
| **Authentication** | Firebase Auth | Email/password + session management |
| **Database** | Cloud Firestore | Real-time sync, offline support |
| **File Storage** | Firebase Storage | Profile photos |
| **Push Notifications** | Firebase Cloud Messaging | Remote notification delivery |
| **Local Notifications** | flutter_local_notifications | Scheduled bill reminders |
| **Biometric Auth** | local_auth | Fingerprint / Face ID |
| **PDF Generation** | pdf + printing | Dues statement export |
| **Persistence** | shared_preferences | Currency preference |
| **Utilities** | intl, uuid, timezone, url_launcher, share_plus | Formatting, IDs, links, sharing |

---

## Data Model

### Firestore structure
```
users/
  {uid}/
    bills/          # Bill documents (recurring, with due date rollover)
    budgets/        # Per-category monthly limits
    dues/           # Informal money transactions
    profile         # User display name, photo URL, preferences
```

### Firestore security rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.0`
- A Firebase project with Auth, Firestore, Storage, and Cloud Messaging enabled

### Setup

```bash
# 1. Clone and install
git clone https://github.com/ramanakellampalli/smart_bill_reminder.git
cd smart_bill_reminder
flutter pub get

# 2. Configure Firebase
npm install -g firebase-tools
flutterfire configure

# 3. Run
flutter run
flutter run --dart-define-from-file=.env  # Run with env vars
```

**Required Firebase services:**
- Authentication (Email/Password)
- Cloud Firestore
- Firebase Storage
- Cloud Messaging

### Build

```bash
flutter build apk          # Android release APK
flutter build appbundle    # Android App Bundle (Play Store)
flutter build ios          # iOS (requires macOS + Xcode)
flutter clean && flutter build appbundle --release --dart-define-from-file=.env  # Build with env vars
```

---

## Design

The app uses a warm, neutral palette designed to feel calm and approachable for a finance tool.

| Token | Value | Usage |
|---|---|---|
| Primary | `#F97316` | Orange — actions, highlights, active states |
| Background | `#FAF8F5` | Warm off-white — screen backgrounds |
| Card | `#FFFFFF` | White — card surfaces |
| Border | `#EDE6DC` | Warm grey — card borders, dividers |
| Text Primary | `#1C1917` | Near-black — headings, primary text |
| Text Secondary | `#78716C` | Warm grey — subtitles, labels |
| Text Tertiary | `#A8A29E` | Light grey — hints, metadata |
| Green | `#16A34A` | Success, paid, positive balance |
| Red | `#DC2626` | Overdue, over budget, negative balance |

---

## Contact

- **Email:** info@ohyeahsaas.com
- **Privacy Policy:** https://ohyeahsaas.com/privacy/bill-buddy/policy
- **Issues:** GitHub Issues

---

<div align="center">
Made with love in India
</div>
