import 'dart:convert';
import 'package:http/http.dart' as http;

// ── Groq config ────────────────────────────────────────────────────────────────
// Key is injected at build time — never hardcoded here.
// Get your FREE key (no credit card) at https://console.groq.com
// Free tier: 14,400 requests/day, 30 requests/minute
//
// Local dev:
//   flutter run --dart-define=GROQ_API_KEY=your_key_here
//
// Release build:
//   flutter build appbundle --release --dart-define=GROQ_API_KEY=your_key_here
//
// CI (GitHub Actions): store as a repo secret, then pass via:
//   --dart-define=GROQ_API_KEY=${{ secrets.GROQ_API_KEY }}
const _kGroqApiKey = String.fromEnvironment('GROQ_API_KEY');

const _kSystemPrompt =
    'You are a concise, friendly support assistant for Bill Buddy, a personal '
    'finance app. Only answer questions about the app. Keep every answer to '
    '2-3 sentences maximum. If asked about anything unrelated, politely say '
    'you can only help with Bill Buddy.\n\n'
    'App features:\n'
    '• Bills tab — Add recurring bills (utilities, rent, EMI, credit card, '
    'subscriptions, education). Mark paid with one tap, swipe to delete (4-second undo), '
    'set reminders 5 days/2 days/day-of. Bills roll over automatically each cycle.\n'
    '• Dues tab — Track informal money lent to or borrowed from people. '
    'Add transactions, mark settled, settle all at once, export a PDF statement.\n'
    '• Budgets tab — Set monthly spending limits per category. '
    'Spend is tracked live from this month\'s bills. Resets automatically each month.\n'
    '• Dashboard — Snapshot of overdue/upcoming bills, dues balance (who owes you), '
    'budget health with top worst-performing categories.\n'
    '• Profile tab — Change currency (INR/USD/EUR/GBP/JPY/AUD), toggle push '
    'notifications/due reminders, view spending insights, sign out.';

// ── FAQ data ───────────────────────────────────────────────────────────────────

class FaqItem {
  final String question;
  final String answer;
  final List<String> keywords;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.keywords,
  });
}

const kFaqs = <FaqItem>[
  // Bills
  FaqItem(
    question: 'How do I add a bill?',
    answer:
        'Tap the + button on the Bills tab. Fill in the name, amount, due date, category, and how often it repeats. You can also turn on reminders before saving.',
    keywords: ['add', 'create', 'new', 'bill'],
  ),
  FaqItem(
    question: 'How do I mark a bill as paid?',
    answer:
        'On the Bills tab, tap the status badge next to any unpaid bill to toggle it paid. Paid bills move to the Paid section at the bottom.',
    keywords: ['mark', 'paid', 'pay', 'toggle', 'complete'],
  ),
  FaqItem(
    question: 'How do I delete a bill?',
    answer:
        'Swipe the bill card from right to left to delete it. A brief Undo toast appears so you can reverse it if needed.',
    keywords: ['delete', 'remove', 'swipe', 'erase'],
  ),
  FaqItem(
    question: 'What bill categories are available?',
    answer:
        'Bill Buddy supports Utilities, Rent, EMI, Credit Card, Subscriptions, Education, and Other.',
    keywords: ['categories', 'category', 'type', 'kind', 'types'],
  ),
  FaqItem(
    question: 'How do recurring bills work?',
    answer:
        'When you mark a recurring bill as paid, it automatically rolls over to the next due date based on the frequency you chose — Monthly, Quarterly, Half-yearly, or Yearly.',
    keywords: ['recurring', 'repeat', 'rollover', 'automatic', 'frequency', 'cycle'],
  ),
  FaqItem(
    question: 'How do reminders work?',
    answer:
        'When adding or editing a bill, enable reminders for 5 days before, 2 days before, or on the due date. These appear as push notifications.',
    keywords: ['reminder', 'notification', 'alert', 'remind', 'notify'],
  ),
  FaqItem(
    question: 'How do I edit a bill?',
    answer:
        'Tap on any bill card to open its detail view, then tap the edit icon to modify any field.',
    keywords: ['edit', 'update', 'change', 'modify', 'bill'],
  ),

  // Dues
  FaqItem(
    question: 'What is the Dues tab?',
    answer:
        'Dues lets you track informal money you\'ve lent to or borrowed from friends and family — like splitting a dinner or lending cash. You can record transactions, mark them settled, and export a PDF.',
    keywords: ['dues', 'what', 'lending', 'borrowing', 'borrow', 'lend', 'money', 'owe'],
  ),
  FaqItem(
    question: 'How do I add a due transaction?',
    answer:
        'On the Dues tab, tap + and choose the person. Select whether they owe you or you owe them, enter the amount and an optional description.',
    keywords: ['add', 'due', 'transaction', 'record', 'entry'],
  ),
  FaqItem(
    question: 'How do I settle a due?',
    answer:
        'Tap a person\'s card to open their detail screen. You can mark individual transactions as settled, or tap "Settle All" to clear everything with that person at once.',
    keywords: ['settle', 'settled', 'clear', 'resolve', 'done', 'paid'],
  ),
  FaqItem(
    question: 'Can I export a dues statement as PDF?',
    answer:
        'Yes — open a person\'s detail screen and tap the export icon to generate and share a PDF statement of all transactions with that person.',
    keywords: ['export', 'pdf', 'share', 'statement', 'print', 'download'],
  ),

  // Budgets
  FaqItem(
    question: 'How do budgets work?',
    answer:
        'In the Budgets tab, set a monthly spending limit for any bill category. The app tracks your actual bill spend for that category this month and shows a color-coded progress bar — green under 75%, orange approaching, red over limit.',
    keywords: ['budget', 'how', 'work', 'limit', 'spending', 'track'],
  ),
  FaqItem(
    question: 'Do budgets reset every month?',
    answer:
        'Yes — your budget limits stay permanently, but the spend resets automatically each month since it\'s calculated from that month\'s bills.',
    keywords: ['reset', 'month', 'budget', 'refresh', 'new month'],
  ),
  FaqItem(
    question: 'How do I add or edit a budget?',
    answer:
        'On the Budgets tab, tap + to add a new category limit, or tap an existing budget card to edit the limit amount.',
    keywords: ['add', 'edit', 'budget', 'set', 'create', 'change limit'],
  ),

  // Dashboard
  FaqItem(
    question: 'What does the dashboard show?',
    answer:
        'The home screen shows your bills snapshot (overdue count, upcoming in 7 days), dues snapshot (net balance with active people), and budget health for the month — all in one place.',
    keywords: ['dashboard', 'home', 'screen', 'shows', 'overview', 'main'],
  ),

  // Profile & Settings
  FaqItem(
    question: 'How do I change the currency?',
    answer:
        'Go to Profile → Your Preferences → Currency and choose from INR, USD, EUR, GBP, JPY, or AUD.',
    keywords: ['currency', 'change', 'dollar', 'rupee', 'inr', 'usd', 'eur', 'symbol'],
  ),
  FaqItem(
    question: 'How do I turn off notifications?',
    answer:
        'Go to Profile → Your Preferences and toggle off Push Notifications or Due Reminders.',
    keywords: ['notification', 'turn off', 'disable', 'stop', 'mute', 'silence'],
  ),
  FaqItem(
    question: 'How do I update my profile photo?',
    answer:
        'Tap your avatar photo on the Profile tab to open the image picker and choose a new photo from your gallery.',
    keywords: ['photo', 'picture', 'profile', 'avatar', 'image', 'update', 'change'],
  ),
  FaqItem(
    question: 'How do I sign out?',
    answer: 'Scroll to the bottom of the Profile tab and tap Sign Out.',
    keywords: ['sign out', 'logout', 'log out', 'signout', 'exit', 'account'],
  ),
];

// ── Stop words ─────────────────────────────────────────────────────────────────

const _kStopWords = {
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'can', 'how', 'what', 'why', 'when', 'where',
  'who', 'which', 'this', 'that', 'these', 'those', 'my', 'your', 'our',
  'their', 'its', 'with', 'for', 'on', 'in', 'at', 'to', 'of', 'from',
  'by', 'and', 'or', 'not', 'but', 'if', 'so', 'get', 'use', 'want',
  'need', 'it', 'me', 'we', 'you', 'i', 'about', 'tell',
};

// ── Service ───────────────────────────────────────────────────────────────────

class HelpService {
  /// Keyword-match against the FAQ list. Returns the best match or null.
  static FaqItem? findFaqMatch(String query) {
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_kStopWords.contains(w))
        .toSet();

    if (words.isEmpty) return null;

    FaqItem? best;
    int bestScore = 0;

    for (final faq in kFaqs) {
      final matched = faq.keywords.where((k) => words.contains(k)).length;
      if (matched > bestScore) {
        bestScore = matched;
        best = faq;
      }
    }

    return bestScore >= 1 ? best : null;
  }

  /// Call Groq (llama-3.1-8b-instant) with conversation history as context.
  /// [history] is a list of prior turns in order: [{role:'user'|'model', text:'...'}]
  static Future<String> askGroq(
    String query,
    List<({String role, String text})> history,
  ) async {
    if (_kGroqApiKey.isEmpty) {
      return 'I couldn\'t find an answer to that. '
          'For more help, email us at info@ohyeahsaas.com';
    }

    try {
      // Last 6 turns max to limit token usage
      final recentHistory = history.length > 6
          ? history.sublist(history.length - 6)
          : history;

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _kSystemPrompt},
        ...recentHistory.map((m) => {
              'role': m.role == 'user' ? 'user' : 'assistant',
              'content': m.text,
            }),
        {'role': 'user', 'content': query},
      ];

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_kGroqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': messages,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            (data['choices'] as List?)?.first?['message']?['content'] as String?;
        return content?.trim() ?? 'Sorry, I didn\'t get a response. Try again.';
      }

      return 'I couldn\'t find an answer to that. '
          'For more help, email us at info@ohyeahsaas.com';
    } catch (_) {
      return 'I couldn\'t find an answer to that. '
          'For more help, email us at info@ohyeahsaas.com';
    }
  }
}
