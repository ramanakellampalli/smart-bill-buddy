import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final String timezone;
  final String currency;
  final bool notificationsEnabled;
  final bool emailNotificationsEnabled;
  final bool pushNotificationsEnabled;
  final bool dueRemindersEnabled;
  final int totalBillsCreated;
  final int totalBillsPaid;
  final double totalAmountSpent;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastActiveAt,
    this.timezone = 'UTC',
    this.currency = '₹',
    this.notificationsEnabled = true,
    this.emailNotificationsEnabled = true,
    this.pushNotificationsEnabled = true,
    this.dueRemindersEnabled = true,
    this.totalBillsCreated = 0,
    this.totalBillsPaid = 0,
    this.totalAmountSpent = 0.0,
  });

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? timezone,
    String? currency,
    bool? notificationsEnabled,
    bool? emailNotificationsEnabled,
    bool? pushNotificationsEnabled,
    bool? dueRemindersEnabled,
    int? totalBillsCreated,
    int? totalBillsPaid,
    double? totalAmountSpent,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotificationsEnabled: emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      dueRemindersEnabled: dueRemindersEnabled ?? this.dueRemindersEnabled,
      totalBillsCreated: totalBillsCreated ?? this.totalBillsCreated,
      totalBillsPaid: totalBillsPaid ?? this.totalBillsPaid,
      totalAmountSpent: totalAmountSpent ?? this.totalAmountSpent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt?.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'timezone': timezone,
      'currency': currency,
      'notificationsEnabled': notificationsEnabled,
      'emailNotificationsEnabled': emailNotificationsEnabled,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'dueRemindersEnabled': dueRemindersEnabled,
      'totalBillsCreated': totalBillsCreated,
      'totalBillsPaid': totalBillsPaid,
      'totalAmountSpent': totalAmountSpent,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'] as String) 
          : null,
      lastActiveAt: map['lastActiveAt'] != null 
          ? DateTime.parse(map['lastActiveAt'] as String) 
          : null,
      timezone: map['timezone'] as String? ?? 'UTC',
      currency: map['currency'] as String? ?? '₹',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      emailNotificationsEnabled: map['emailNotificationsEnabled'] as bool? ?? true,
      pushNotificationsEnabled: map['pushNotificationsEnabled'] as bool? ?? true,
      dueRemindersEnabled: map['dueRemindersEnabled'] as bool? ?? true,
      totalBillsCreated: map['totalBillsCreated'] as int? ?? 0,
      totalBillsPaid: map['totalBillsPaid'] as int? ?? 0,
      totalAmountSpent: (map['totalAmountSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory UserProfile.fromFirebaseUser(User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  String get displayNameOrEmail => displayName?.isNotEmpty == true ? displayName! : email;
  
  String get initials {
    final name = displayNameOrEmail;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  double get paymentCompletionRate => 
      totalBillsCreated > 0 ? (totalBillsPaid / totalBillsCreated) * 100 : 0.0;
}
