import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'bills_screen.dart';
import 'dues_screen.dart';
import 'budgets_screen.dart';
import 'profile_screen.dart';

const _navBg = Colors.white;
const _navBorder = Color(0xFFEDE6DC);
const _navSelected = Color(0xFFF97316);
const _navUnselected = Color(0xFFA8A29E);

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
    _screens = [
      DashboardScreen(
        onNavigateToBills: () => setState(() => _currentIndex = 1),
        onNavigateToDues: () => setState(() => _currentIndex = 2),
        onNavigateToBudgets: () => setState(() => _currentIndex = 3),
      ),
      const BillsScreen(),
      const DuesScreen(),
      const BudgetsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Bills'),
    _NavItem(
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt_rounded,
        label: 'Dues'),
    _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Budgets'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _navBg,
        border: Border(top: BorderSide(color: _navBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Orange top indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2.5,
                        width: selected ? 24 : 0,
                        decoration: BoxDecoration(
                          color: _navSelected,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        size: 22,
                        color: selected ? _navSelected : _navUnselected,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? _navSelected : _navUnselected,
                        ),
                      ),
                      const Spacer(),
                    ],
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
  final IconData activeIcon;
  final String label;

  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}
