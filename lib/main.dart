import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';
import 'providers/inventory_provider.dart';
import 'services/sheets_service.dart';
import 'services/update_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/pos_screen.dart';
import 'ui/screens/inventory_screen.dart';
import 'ui/screens/orders_history_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/update_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaiShopApp());
}

class MaiShopApp extends StatelessWidget {
  const MaiShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp(
            title: 'MaiShop Plus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(lightDynamic),
            darkTheme: AppTheme.darkTheme(darkDynamic),
            themeMode: ThemeMode.system,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: const TextScaler.linear(0.82),
                ),
                child: child!,
              );
            },
            home: const MainNavigationShell(),
          );
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  int _historyKeyCounter = 0;
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SheetsService.instance.loadConfig();

    // Tự động kiểm tra bản cập nhật mới chạy ngầm sau khi mở app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCheckTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _checkAppUpdateSilently();
        }
      });
    });
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAppUpdateSilently() async {
    try {
      final info = await UpdateService.instance.checkForUpdate();
      if (info != null && info.hasUpdate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.new_releases_rounded, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã có bản cập nhật mới v${info.latestVersion}!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'XEM & TẢI',
              textColor: Colors.amberAccent,
              onPressed: () {
                UpdateDialog.show(context, info);
              },
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PosScreen(isActive: _currentIndex == 0),
          const InventoryScreen(),
          OrdersHistoryScreen(key: ValueKey('history_$_historyKeyCounter')),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 58,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 2) {
              _historyKeyCounter++;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined, size: 21),
            selectedIcon: Icon(Icons.point_of_sale_rounded, size: 21),
            label: 'Thu ngân',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, size: 21),
            selectedIcon: Icon(Icons.inventory_2_rounded, size: 21),
            label: 'Kho hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, size: 21),
            selectedIcon: Icon(Icons.receipt_long_rounded, size: 21),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, size: 21),
            selectedIcon: Icon(Icons.settings_rounded, size: 21),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
