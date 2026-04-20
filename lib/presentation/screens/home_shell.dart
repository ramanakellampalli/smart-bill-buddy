import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/promo_modal_service.dart';
import '../state/user_provider.dart';
import '../widgets/welcome_promo_sheet.dart';
import 'dashboard_screen.dart';
import 'bills_screen.dart';
import 'dues_screen.dart';
import 'expenses_screen.dart';
import 'budgets_screen.dart';
import 'profile_screen.dart';
import '../widgets/help_chat_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPromo());
    _screens = [
      DashboardScreen(
        onNavigateToBills: () => setState(() => _currentIndex = 1),
        onNavigateToDues: () => setState(() => _currentIndex = 2),
        onNavigateToExpenses: () => setState(() => _currentIndex = 3),
        onNavigateToBudgets: () => setState(() => _currentIndex = 4),
      ),
      const BillsScreen(),
      const DuesScreen(),
      const ExpensesScreen(),
      const BudgetsScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _maybeShowPromo() async {
    if (!mounted) return;
    final should = await PromoModalService.shouldShow();
    if (!should || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final name = context.read<UserProvider>().profile?.displayName?.split(' ').first;
    await PromoModalService.markShown();
    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    await WelcomePromoSheet.show(context, firstName: name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          const Positioned(
            right: 16,
            bottom: 16,
            child: HelpFloatingButton(),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: FontAwesomeIcons.house,            label: 'Home'),
    _NavItem(icon: FontAwesomeIcons.fileInvoiceDollar, label: 'Bills'),
    _NavItem(icon: FontAwesomeIcons.handshake,         label: 'Dues'),
    _NavItem(icon: FontAwesomeIcons.wallet,            label: 'Expenses'),
    _NavItem(icon: FontAwesomeIcons.piggyBank,         label: 'Budgets'),
    _NavItem(icon: FontAwesomeIcons.circleUser,        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.navBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navActive : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          item.icon,
                          size: 18,
                          color: selected
                              ? AppColors.navBg
                              : AppColors.navInactive,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.navBg
                                : AppColors.navInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
