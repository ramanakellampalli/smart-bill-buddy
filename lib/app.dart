import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';

import 'data/models/bill_model.dart';
import 'data/repositories/bills_repository.dart';
import 'data/repositories/budgets_repository.dart';
import 'data/repositories/dues_repository.dart';
import 'data/repositories/expenses_repository.dart';
import 'presentation/state/app_settings_provider.dart';
import 'presentation/state/bills_provider.dart';
import 'presentation/state/budgets_provider.dart';
import 'presentation/state/dues_provider.dart';
import 'presentation/state/expenses_provider.dart';
import 'presentation/state/user_provider.dart';
import 'presentation/screens/auth_wrapper.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/add_bill_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/about_screen.dart';

class SmartBillApp extends StatelessWidget {
  const SmartBillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        Provider(create: (_) => BillsRepository()),
        Provider(create: (_) => BudgetsRepository()),
        Provider(create: (_) => DuesRepository()),
        Provider(create: (_) => ExpensesRepository()),
        ChangeNotifierProvider(
          create: (ctx) => BillsProvider(ctx.read<BillsRepository>(), ctx.read<ExpensesRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => BudgetsProvider(ctx.read<BudgetsRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DuesProvider(ctx.read<DuesRepository>(), ctx.read<ExpensesRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ExpensesProvider(ctx.read<ExpensesRepository>()),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
        title: 'Bill Buddy',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: ThemeData(
          useMaterial3: false,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.bg,
          primaryColor: AppColors.primary,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.green,
            surface: AppColors.surface,
            error: AppColors.red,
            onPrimary: AppColors.textPrimary,
            onSecondary: Colors.white,
            onSurface: AppColors.textPrimary,
            onError: Colors.white,
          ),
          textTheme: GoogleFonts.spaceGroteskTextTheme(
            ThemeData.light().textTheme,
          ).apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            titleTextStyle: GoogleFonts.spaceGrotesk(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.heroCard,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.heroCard,
            foregroundColor: Colors.white,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? AppColors.primary : null),
            checkColor: WidgetStateProperty.all(AppColors.textPrimary),
          ),
          dividerTheme: const DividerThemeData(
            color: AppColors.border,
            thickness: 2,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: AppColors.surface,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: AppColors.surface,
          ),
        ),
        home: AuthWrapper(),
        routes: {
          '/home': (_) => const HomeShell(),
          '/register': (_) => const RegisterScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/add-bill': (ctx) => AddBillScreen(
                bill: ModalRoute.of(ctx)!.settings.arguments as BillModel?,
              ),
          '/settings': (_) => const SettingsScreen(),
          '/about': (_) => const AboutScreen(),
        },
        ),
      ),
    );
  }
}
