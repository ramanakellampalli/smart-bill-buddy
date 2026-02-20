import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models/bill_model.dart';
import 'data/repositories/bills_repository.dart';
import 'data/repositories/budgets_repository.dart';
import 'data/repositories/dues_repository.dart';
import 'presentation/state/app_settings_provider.dart';
import 'presentation/state/bills_provider.dart';
import 'presentation/state/budgets_provider.dart';
import 'presentation/state/dues_provider.dart';
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
        ChangeNotifierProvider(
          create: (ctx) => BillsProvider(ctx.read<BillsRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => BudgetsProvider(ctx.read<BudgetsRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DuesProvider(ctx.read<DuesRepository>()),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
        title: 'Bill Buddy',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: ThemeData(
          useMaterial3: false,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFAF8F5),
          primaryColor: const Color(0xFFF97316),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF97316),
            secondary: Color(0xFF16A34A),
            surface: Colors.white,
            background: Color(0xFFFAF8F5),
            error: Color(0xFFDC2626),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF1C1917),
            onBackground: Color(0xFF1C1917),
            onError: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFAF8F5),
            elevation: 0,
            foregroundColor: Color(0xFF1C1917),
            titleTextStyle: TextStyle(
              color: Color(0xFF1C1917),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Color(0xFF1C1917)),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFF97316),
            foregroundColor: Colors.white,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? const Color(0xFFF97316)
                    : null),
          ),
          dividerTheme:
              const DividerThemeData(color: Color(0xFFEDE6DC), thickness: 1),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFF1C1917)),
            bodyMedium: TextStyle(color: Color(0xFF1C1917)),
            bodySmall: TextStyle(color: Color(0xFF78716C)),
            titleMedium: TextStyle(
                color: Color(0xFF1C1917), fontWeight: FontWeight.w600),
            titleLarge: TextStyle(
                color: Color(0xFF1C1917), fontWeight: FontWeight.w700),
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Colors.white,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: false,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: const Color(0xFFF97316),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF97316),
            secondary: Color(0xFF4ADE80),
            surface: Color(0xFF1E1E1E),
            background: Color(0xFF121212),
            error: Color(0xFFEF4444),
            onPrimary: Colors.white,
            onSecondary: Colors.black,
            onSurface: Color(0xFFF5F5F4),
            onBackground: Color(0xFFF5F5F4),
            onError: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            elevation: 0,
            foregroundColor: Color(0xFFF5F5F4),
            titleTextStyle: TextStyle(
              color: Color(0xFFF5F5F4),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Color(0xFFF5F5F4)),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E1E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFF97316),
            foregroundColor: Colors.white,
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFF2E2E2E),
            thickness: 1,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFF5F5F4)),
            bodyMedium: TextStyle(color: Color(0xFFF5F5F4)),
            bodySmall: TextStyle(color: Color(0xFFA8A29E)),
            titleMedium: TextStyle(
                color: Color(0xFFF5F5F4), fontWeight: FontWeight.w600),
            titleLarge: TextStyle(
                color: Color(0xFFF5F5F4), fontWeight: FontWeight.w700),
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF1E1E1E),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF1E1E1E),
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
