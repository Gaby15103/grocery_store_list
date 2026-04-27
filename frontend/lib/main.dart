import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/grocery_list_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_selection_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';
import 'config.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'repositories/grocery_repository.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'utils/l10n.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init();
  await dotenv.load();
  await Hive.initFlutter();

  // Initial boot check for Notification Channel localization
  final box = await Hive.openBox<String>('metadata');
  final savedLang = box.get('language') ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final bool isFrench = savedLang == 'fr';

  await NotificationService.init(
    channelName: isFrench ? 'Mises à jour des courses' : 'Grocery Updates',
    channelDesc: isFrench
        ? 'Notifications pour les changements dans les listes'
        : 'Notifications for grocery list changes',
  );

  Hive.registerAdapter(ItemStatusAdapter());
  Hive.registerAdapter(GroceryItemAdapter());
  Hive.registerAdapter(GroceryGroupAdapter());
  Hive.registerAdapter(GroceryListAdapter());

  await Future.wait([
    Hive.openBox<GroceryGroup>('groups'),
    Hive.openBox<GroceryItem>('items'),
    Hive.openBox<GroceryList>('lists'),
  ]);

  final repository = GroceryRepository();
  await repository.initialize();

  // Foreground service config
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'grocery_sync_service',
      channelName: 'Grocery Master Sync',
      channelDescription: 'Maintains connection for real-time updates.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  final socketService = SocketService(repository);

  runApp(GroceryApp(
    repository: repository,
    socketService: socketService,
  ));
}

class GroceryApp extends StatefulWidget {
  final GroceryRepository repository;
  final SocketService socketService;

  const GroceryApp({super.key, required this.repository, required this.socketService});

  @override
  State<GroceryApp> createState() => _GroceryAppState();
}

class _GroceryAppState extends State<GroceryApp> {
  bool _isSocketInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupGlobalListeners();
    _setupNotificationTapHandler();
  }

  void _setupNotificationTapHandler() {
    NotificationService.selectNotificationStream.stream.listen((String? listId) {
      if (listId != null) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => GroceryListScreen(
              repository: widget.repository,
              sessionId: listId,
            ),
          ),
              (route) => route.isFirst,
        );
      }
    });
  }

  void _setupGlobalListeners() {
    widget.repository.initSocketListener(widget.socketService.eventStream);

    // Foreground task setup
    if (!_isSocketInitialized) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Grocery Master',
        notificationText: 'Sync service is active',
      );
    }

    widget.socketService.eventStream.listen((event) {
      final String? incomingListId = event.data['listId'] ?? event.data['ListId'];
      final String? activeListId = widget.repository.currentOpenedListId;

      if (incomingListId != null && incomingListId == activeListId) return;

      // Handle translation for notifications
      final lang = Hive.box<String>('metadata').get('language', defaultValue: 'fr');

      if (event.type == 'item_added') {
        NotificationService.showPhoneNotification(
          id: 1,
          title: lang == 'fr' ? 'Nouvel article !' : 'New Item!',
          body: lang == 'fr'
              ? '${event.data['name']} a été ajouté à une liste.'
              : '${event.data['name']} was added to a list.',
          payload: incomingListId,
        );
      } else if (event.type == 'item_updated' && event.data['status'] == 'bought') {
        NotificationService.showPhoneNotification(
          id: 2,
          title: lang == 'fr' ? 'Article acheté' : 'Item Purchased',
          body: lang == 'fr'
              ? 'Quelqu\'un a acheté ${event.data['name']} !'
              : 'Someone bought ${event.data['name']}!',
          payload: incomingListId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      // CRITICAL: Listen to both theme and language changes
      valueListenable: Hive.box<String>('metadata').listenable(),
      builder: (context, Box<String> box, _) {
        final String? userEmail = box.get('userEmail');
        final String language = box.get('language') ?? 'fr';

        if (userEmail != null && !_isSocketInitialized) {
          widget.socketService.connect(userEmail);
          _isSocketInitialized = true;
        }

        // Theme Logic
        final String themeModePref = box.get('themeMode') ?? 'system';
        ThemeMode currentThemeMode = themeModePref == 'dark'
            ? ThemeMode.dark
            : themeModePref == 'light' ? ThemeMode.light : ThemeMode.system;

        final String? colorSeedHex = box.get('colorSeed');
        final Color seedColor = colorSeedHex != null ? Color(int.parse(colorSeedHex)) : Colors.green;

        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Grocery Master',

          // Localization
          locale: Locale(language),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          themeMode: currentThemeMode,
          theme: ThemeData(colorSchemeSeed: seedColor, useMaterial3: true, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: seedColor, useMaterial3: true, brightness: Brightness.dark),

          home: userEmail == null
              ? SetupScreen(repository: widget.repository, onComplete: () => setState(() {}))
              : HomeScreen(repository: widget.repository),

          routes: {
            '/settings': (context) => SettingsScreen(repository: widget.repository),
            '/home': (context) => HomeScreen(repository: widget.repository),
            '/groups': (context) => ListSelectionScreen(
              repository: widget.repository,
              groupId: widget.repository.getActiveGroupId(),
            ),
          },
        );
      },
    );
  }
}