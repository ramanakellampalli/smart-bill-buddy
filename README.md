# Bill Buddy

A Flutter app to track, manage, and get reminded about your recurring bills — built with Firebase and a warm neutral design.

---

## Features

- **Dashboard** — overview of upcoming bills, total due, and quick stats
- **Bill tracking** — add bills with category, amount, frequency, and due date
- **Categories** — Utilities, Rent, EMI, Credit Card, Subscriptions, Education, and more — each with a distinct gradient logo
- **Smart filters** — view All / Unpaid / Paid bills with live counts
- **Mark as paid** — one-tap to toggle paid state with visual feedback
- **Overdue detection** — unpaid bills past due date are flagged automatically
- **Reminders** — configurable push notifications (5 days before, 2 days before, on due day)
- **Budgets & Insights** — budget tracking and spending breakdown screens
- **Authentication** — email/password sign-up and sign-in via Firebase Auth
- **Per-user data** — all bills are scoped to the signed-in user in Firestore
- **Swipe to delete** — swipe a bill card left to remove it

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart) |
| State management | Provider |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Push notifications | Firebase Cloud Messaging |
| Architecture | Repository pattern, ChangeNotifier |

---

## Project Structure

```
lib/
├── app.dart                        # MaterialApp, theme, routes
├── main.dart                       # Entry point, Firebase init
├── core/
│   └── utils/auth_bootstrap.dart   # Auth initialisation helper
├── data/
│   ├── models/
│   │   ├── bill_model.dart         # Bill data model + Firestore serialisation
│   │   └── user_model.dart         # User profile model
│   └── repositories/
│       └── bills_repository.dart   # Firestore CRUD + real-time stream
└── presentation/
    ├── screens/
    │   ├── auth_wrapper.dart        # Routes to login or home based on auth state
    │   ├── home_shell.dart          # Bottom nav shell (Dashboard / Bills / Budgets)
    │   ├── dashboard_screen.dart    # Home overview with upcoming bills
    │   ├── bills_screen.dart        # Full bill list with filters
    │   ├── add_bill_screen.dart     # Add / edit bill form
    │   ├── budgets_screen.dart      # Budget overview
    │   ├── insights_screen.dart     # Spending insights
    │   ├── profile_screen.dart      # User profile
    │   ├── settings_screen.dart     # App settings
    │   ├── about_screen.dart        # About page
    │   ├── login_screen.dart        # Sign in
    │   └── register_screen.dart     # Sign up
    ├── state/
    │   ├── bills_provider.dart      # Bills state, auth-aware Firestore subscription
    │   └── user_provider.dart       # User profile state
    └── widgets/
        ├── auth_guard.dart          # Redirects unauthenticated users
        └── category_logo.dart       # Gradient category badge widget
```

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.0`
- A Firebase project with **Authentication** (email/password) and **Firestore** enabled

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/YOUR_USERNAME/bill-buddy.git
   cd bill-buddy
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Add Firebase config files** (not committed — kept out of version control)

   | Platform | File | Location |
   |---|---|---|
   | Android | `google-services.json` | `android/app/` |
   | iOS | `GoogleService-Info.plist` | `ios/Runner/` |
   | All | `firebase_options.dart` | `lib/` |

   Generate these by running:
   ```bash
   flutterfire configure
   ```

4. **Set Firestore security rules**
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/bills/{billId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Sensitive Files (never committed)

The following are listed in `.gitignore` and must be added locally after cloning:

```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

---

## Dependencies

```yaml
provider: ^6.1.2
firebase_core: ^2.30.0
cloud_firestore: ^4.17.0
firebase_auth: ^4.19.0
firebase_messaging: ^14.9.0
intl: ^0.19.0
uuid: ^4.4.0
```
