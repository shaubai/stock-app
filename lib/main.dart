import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/stock_list_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/login_screen.dart';
import 'providers/watchlist_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/stock_provider.dart';
import 'services/storage_service_factory.dart';
import 'services/storage_service_firestore.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // 在 Android/iOS，若有 google-services.json / GoogleService-Info.plist，
  // native 層會在 main() 執行前自動建立 [DEFAULT] app，導致 Dart 端再次呼叫
  // initializeApp() 時丟出 [core/duplicate-app]。Firebase.apps 在此情境下
  // 不一定會同步反映 native 端已存在的 app，因此改以 catch 例外的方式忽略，
  // 避免例外未被攔截導致 App 啟動失敗（畫面全白）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Initialize with local storage first (will switch to Firestore after login)
  final watchlistProvider = WatchlistProvider(createStorageService());

  runApp(MyApp(watchlistProvider: watchlistProvider));
}

class MyApp extends StatelessWidget {
  final WatchlistProvider watchlistProvider;

  const MyApp({super.key, required this.watchlistProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: watchlistProvider),
        ChangeNotifierProvider(create: (_) => StockProvider()),
      ],
      child: MaterialApp(
        title: 'Stock App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);

    // Listen to auth changes
    authProvider.addListener(() async {
      final userId = authProvider.userId;
      if (userId != null) {
        // User logged in - switch to Firestore storage
        final firestoreStorage = StorageServiceFirestore(userId);
        watchlistProvider.updateStorageService(firestoreStorage);
        await watchlistProvider.init();
      } else {
        // User logged out - switch back to local storage
        watchlistProvider.updateStorageService(createStorageService());
        await watchlistProvider.init();
      }
    });

    // Initialize based on current auth state
    if (authProvider.isSignedIn) {
      final userId = authProvider.userId!;
      final firestoreStorage = StorageServiceFirestore(userId);
      watchlistProvider.updateStorageService(firestoreStorage);
      await watchlistProvider.init();
    } else {
      await watchlistProvider.init();
    }

    // Check for updates (Android only: downloadUrl currently points to an
    // APK, which is meaningless on iOS/Web — iOS updates go through the
    // App Store instead)
    if (!kIsWeb && Platform.isAndroid) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdate();

    if (updateInfo != null && mounted) {
      // Wait a bit for the UI to settle before showing the dialog
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        UpdateDialog.show(context, updateInfo);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isSignedIn) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

/// 決定 MainScreen 開啟時該停在哪個分頁（0=股票看板, 1=自選股）。
///
/// 回傳 null 表示這次不該有任何變動（尚未初始化，或已經判斷過一次）；
/// 只在 [isInitialized] 剛變成 true、且 [hasSetInitialTab] 仍是 false 時
/// 才會回傳非 null 值，且僅回傳一次——之後使用者手動切分頁或自選股
/// 數量變動，都不應該再被自動跳轉打斷。
///
/// 抽成獨立的純函式（不依賴 State/BuildContext）方便直接單元測試，
/// 不需要渲染 MainScreen 底下會發出真實網路請求的 StockListScreen /
/// WatchlistScreen。
int? resolveInitialTabIndex({
  required bool hasSetInitialTab,
  required bool isInitialized,
  required int watchlistCount,
}) {
  if (hasSetInitialTab || !isInitialized) return null;
  return watchlistCount > 0 ? 1 : 0;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // WatchlistProvider 的資料是非同步載入的（見 AuthWrapper._initializeAuth
  // 對 watchlistProvider.init() 的 await），MainScreen build() 當下不保證
  // 已經載入完成，因此不能只在 initState 判斷一次 count。改為監聽
  // isInitialized 由 false 變 true 的那一刻才決定初始分頁，且只做一次——
  // 之後使用者手動切分頁或自選股數量變動，都不應該再被自動跳轉打斷。
  bool _hasSetInitialTab = false;

  final List<Widget> _screens = const [
    StockListScreen(),
    WatchlistScreen(),
    ProfileScreen(),
  ];

  void _maybeSetInitialTab(WatchlistProvider watchlistProvider) {
    final newIndex = resolveInitialTabIndex(
      hasSetInitialTab: _hasSetInitialTab,
      isInitialized: watchlistProvider.isInitialized,
      watchlistCount: watchlistProvider.count,
    );
    if (newIndex == null) return;
    _hasSetInitialTab = true;
    if (newIndex != _currentIndex) {
      // 用 microtask 避免在 build 過程中呼叫 setState
      Future.microtask(() {
        if (mounted) setState(() => _currentIndex = newIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    _maybeSetInitialTab(watchlistProvider);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: '股票看板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: '自選股',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '個人',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資訊'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              authProvider.displayName.isNotEmpty
                  ? authProvider.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              authProvider.displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          if (authProvider.userEmail != null)
            Center(
              child: Text(
                authProvider.userEmail!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          if (authProvider.isAnonymous)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '匿名用戶',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認登出'),
                  content: const Text('確定要登出嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('確定'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await authProvider.signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}

