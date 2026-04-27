import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:frontend/screens/grocery_list_screen.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/list_selection_screen.dart';
import 'package:frontend/screens/setup_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'repositories/grocery_repository.dart';
import 'services/socket_service.dart'; // Import your new service
import 'services/notification_service.dart'; // Import the notification service
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init();
  await dotenv.load();
  await NotificationService.init();

  await Hive.initFlutter();


  Hive.registerAdapter(ItemStatusAdapter());
  Hive.registerAdapter(GroceryItemAdapter());
  Hive.registerAdapter(GroceryGroupAdapter());
  Hive.registerAdapter(GroceryListAdapter());


  await Future.wait([
    Hive.openBox<GroceryGroup>('groups'),
    Hive.openBox<GroceryItem>('items'),
    Hive.openBox<GroceryList>('lists'),
    Hive.openBox<String>('metadata'),
  ]);

  final repository = GroceryRepository();
  await repository.initialize();

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

  // --- FIX: Correct Permission Check (v6+) ---
  NotificationPermission notificationPermission =
  await FlutterForegroundTask.checkNotificationPermission();
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

  const GroceryApp({
    super.key,
    required this.repository,
    required this.socketService,
  });

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
        _navigateToSpecificList(listId);
      }
    });
  }

  void _navigateToSpecificList(String listId) {
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

  Future<void> _startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Grocery Master',
      notificationText: 'Sync service is active in background',
    );
  }

  void _setupGlobalListeners() {
    widget.repository.initSocketListener(widget.socketService.eventStream);

    _startForegroundTask();

    widget.socketService.eventStream.listen((event) {
      final String? incomingListId = event.data['listId'] ?? event.data['ListId'];
      final String? activeListId = widget.repository.currentOpenedListId;

      if (incomingListId != null && incomingListId == activeListId) {
        print("🔇 Muting notification: User is already looking at list $incomingListId");
        return;
      }

      if (event.type == 'item_added') {
        NotificationService.showPhoneNotification(
          id: 1,
          title: 'New Item!',
          body: '${event.data['name']} was added to a list.',
          payload: incomingListId,
        );
      } else if (event.type == 'item_updated' && event.data['status'] == 'bought') {
        NotificationService.showPhoneNotification(
          id: 2,
          title: 'Item Purchased',
          body: 'Someone bought ${event.data['name']}!',
          payload: incomingListId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<String>('metadata').listenable(),
      builder: (context, Box<String> box, _) {
        final String? userEmail = box.get('userEmail');

        if (userEmail != null && !_isSocketInitialized) {
          widget.socketService.connect(userEmail);
          _isSocketInitialized = true;
        }

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
          themeMode: currentThemeMode,
          theme: ThemeData(
              colorSchemeSeed: seedColor,
              useMaterial3: true,
              brightness: Brightness.light
          ),
          darkTheme: ThemeData(
              colorSchemeSeed: seedColor,
              useMaterial3: true,
              brightness: Brightness.dark
          ),
          home: userEmail == null
              ? SetupScreen(
            repository: widget.repository,
            onComplete: () => setState(() {}),
          )
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