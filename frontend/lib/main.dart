import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:grocery_list/services/api/base_api.dart';
import 'package:grocery_list/services/sync_manager.dart';
import 'package:grocery_list/utils/l10n.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';

// Your existing imports
import 'config.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'models/sync_task.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';

// Your New MVC imports
import 'services/api/auth_api_client.dart';
import 'services/api/group_api_client.dart';
import 'services/api/list_api_client.dart';
import 'services/api/item_api_client.dart';
import 'repositories/auth_repository.dart';
import 'repositories/group_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/item_repository.dart';
import 'controllers/auth_controller.dart';
import 'controllers/group_controller.dart';
import 'controllers/list_controller.dart';
import 'controllers/item_controller.dart';

// Views
import 'views/home_view.dart';
import 'views/setup_view.dart';
import 'views/settings_view.dart';
import 'views/list_selection_view.dart';
import 'views/grocery_list_view.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // 1. MUST be the very first call
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // 2. Use debugPrint - it's more reliable for Logcat on your Pixel 7a
  debugPrint("🔥 FCM Isolate Started: ${message.messageId}");

  try {
    if (!Hive.isBoxOpen('metadata')) {
      await Hive.initFlutter();
      await Hive.openBox<String>('metadata');
    }

    final metaBox = Hive.box<String>('metadata');
    final String lang = metaBox.get('language') ?? 'fr';

    await NotificationService.init();

    final String type = message.data['type'] ?? 'item_added';
    final String itemName = message.data['itemName'] ?? '';
    final String senderName = message.data['senderName'] ?? 'Quelqu\'un';

    // 5. SAFETY FALLBACK: If L10n fails, use hardcoded defaults
    String title;
    String body;

    try {
      title = L10n.getStatic(type, lang);
      body = L10n.getStatic('${type}_body', lang)
          .replaceAll('{user}', senderName)
          .replaceAll('{item}', itemName);
    } catch (e) {
      debugPrint("⚠️ L10n failed in background, using fallbacks");
      title = (lang == 'fr') ? "Mise à jour" : "Update";
      body = (lang == 'fr')
          ? "$senderName a acheté $itemName"
          : "$senderName purchased $itemName";
    }

    await NotificationService.showPhoneNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: message.data['listId'],
    );

    debugPrint("✅ Notification dispatched from background");
  } catch (e) {
    // Catch-all to prevent the isolate from crashing silently
    debugPrint("❌ BACKGROUND CRASH: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  if (WidgetsBinding.instance.platformDispatcher.views.isEmpty) {
    debugPrint("IDLE: Background Isolate detected. Skipping full app initialization.");
    return;
  }

  await AppConfig.init();

  try {
    await dotenv.load();
  } catch (e) {
    debugPrint("Dotenv load failed: $e");
  }



  await Hive.initFlutter();
  Hive.registerAdapter(ItemStatusAdapter());
  Hive.registerAdapter(GroceryItemAdapter());
  Hive.registerAdapter(GroceryGroupAdapter());
  Hive.registerAdapter(GroceryListAdapter());
  Hive.registerAdapter(SyncTaskAdapter());

  final box = await Hive.openBox<String>('metadata');
  final savedLang = box.get('language') ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final bool isFrench = savedLang == 'fr';

  // --- KEEPING YOUR MOBILE LOGIC ---
  if (!kIsWeb) {
    await NotificationService.init(
      channelName: isFrench ? 'Mises à jour des courses' : 'Grocery Updates',
      channelDesc: isFrench ? 'Changements dans les listes' : 'List changes',
    );
  }

  await Future.wait([
    Hive.openBox<GroceryGroup>('groups'),
    Hive.openBox<GroceryItem>('items'),
    Hive.openBox<GroceryList>('lists'),
    Hive.openBox<SyncTask>('sync_queue'),
  ]);

  // --- INITIALIZE SERVICES & REPOS ---
  final socketService = SocketService();
  final authRepo = AuthRepository(AuthApiClient());
  final groupRepo = GroupRepository(GroupApiClient());
  final listRepo = ListRepository(ListApiClient());
  final itemRepo = ItemRepository(ItemApiClient(), GroupApiClient());

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: socketService),
        ChangeNotifierProvider(create: (_) => AuthController(repository: authRepo)),
        ChangeNotifierProvider(create: (_) => GroupController(repository: groupRepo, socketService: socketService)),
        ChangeNotifierProvider(create: (_) => ListController(repository: listRepo)),
        ChangeNotifierProvider(create: (_) => ItemController(repository: itemRepo)),
      ],
      child: const GroceryApp(),
    ),
  );
}

class GroceryApp extends StatefulWidget {
  const GroceryApp({super.key});

  @override
  State<GroceryApp> createState() => _GroceryAppState();
}

class _GroceryAppState extends State<GroceryApp> with WidgetsBindingObserver {
  bool _isSocketInitialized = false;
  late final SyncManager _syncManager;


  @override
  void initState() {
    super.initState();
    _syncManager = SyncManager();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();

      if (auth.repository.getEmail() != null) {
        auth.syncTokenWithServer();
      }
    });

    _setupGlobalListeners();

    if (!kIsWeb) {
      _setupNotificationTapHandler();

      _setupConnectivityListener(_syncManager, AuthApiClient());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh groups and items when app comes back to focus
      context.read<GroupController>().loadGroups();
    }
  }

  void _setupNotificationTapHandler() {
    NotificationService.selectNotificationStream.stream.listen((String? listId) {
      if (listId != null) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => GroceryListView(
              sessionId: listId,
            ),
          ),
              (route) => route.isFirst,
        );
      }
    });
  }


  void _setupGlobalListeners() {
    final socket = context.read<SocketService>();
    final groupCtrl = context.read<GroupController>();
    final itemCtrl = context.read<ItemController>();

    // Handle incoming socket events globally
    socket.eventStream.listen((event) {
      final String? incomingListId = event.data['ListId'] ?? event.data['listId'];
      final String? incomingGroupId = event.data['GroupId'] ?? event.data['groupId'];

      if (incomingListId != null) {
        itemCtrl.syncFromSocket(incomingListId, incomingGroupId ?? 'default');

        if (incomingListId != itemCtrl.currentListId) {
          _handleBackgroundNotification(event);
        }
      }

      if (event.type == 'force_refresh' || event.type == 'group_deleted') {
        groupCtrl.loadGroups();
      }
    });
  }

  void _setupConnectivityListener(SyncManager syncManager, BaseApi api) {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        debugPrint("🌐 Internet restored, processing sync queue...");
        syncManager.processQueue(api);
      }
    });
  }

  void _handleBackgroundNotification(SocketEvent event) {
    if (kIsWeb) return;

    final box = Hive.box<String>('metadata');
    final lang = box.get('language', defaultValue: 'fr');
    final String? incomingListId = event.data['listId'] ?? event.data['ListId'];

    final itemCtrl = context.read<ItemController>();
    if (incomingListId != null && incomingListId == itemCtrl.currentListId) {
      debugPrint("🔇 Silencing notification: User is looking at list $incomingListId");
      return;
    }

    final bool notifyItems = box.get('notify_item_changes', defaultValue: 'true') == 'true';
    final bool notifyInvites = box.get('notify_invitations', defaultValue: 'true') == 'true';
    final bool notifyListCreated = box.get('notify_list_created', defaultValue: 'true') == 'true';
    final bool notifyCarryOver = box.get('notify_carry_over', defaultValue: 'true') == 'true';

    switch (event.type) {
      case 'item_added':
        if (!notifyItems) return;
        NotificationService.showPhoneNotification(
          id: 1,
          title: lang == 'fr' ? 'Nouvel article !' : 'New Item!',
          body: '${event.data['name']} ${lang == 'fr' ? 'ajouté' : 'added'}.',
          payload: incomingListId,
        );
        break;

      case 'item_updated':
        if (!notifyItems) return;
        if (event.data['status'] == 'bought') {
          NotificationService.showPhoneNotification(
            id: 2,
            title: lang == 'fr' ? 'Article acheté' : 'Item Purchased',
            body: lang == 'fr'
                ? 'Quelqu\'un a acheté ${event.data['name']} !'
                : 'Someone bought ${event.data['name']}!',
            payload: incomingListId,
          );
        }
        break;

      case 'invitation_received':
        if (!notifyInvites) return;
        NotificationService.showPhoneNotification(
          id: 3,
          title: lang == 'fr' ? 'Nouvelle invitation' : 'New Invitation',
          body: lang == 'fr'
              ? 'Vous avez été invité dans un groupe.'
              : 'You were invited to a group.',
        );
        break;

      case 'list_created':
        final bool isCarryOver = event.data['isCarryOver'] ?? false;
        if (isCarryOver && !notifyCarryOver) return;
        if (!isCarryOver && !notifyListCreated) return;

        NotificationService.showPhoneNotification(
          id: 4,
          title: lang == 'fr' ? 'Nouvelle liste' : 'New List',
          body: '${event.data['name']} ${lang == 'fr' ? 'est prête' : 'is ready'}.',
          payload: incomingListId,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return ValueListenableBuilder(
      valueListenable: Hive.box<String>('metadata').listenable(),
      builder: (context, Box<String> box, _) {
        final String language = box.get('language') ?? 'fr';
        final String themeModePref = box.get('themeMode') ?? 'system';

        final String? colorSeedValue = box.get('colorSeed');
        Color primaryColor = Colors.green; // Fallback
        if (colorSeedValue != null) {
          primaryColor = Color(int.parse(colorSeedValue));
        }

        // Connect Socket if logged in
        if (auth.isLoggedIn && !_isSocketInitialized) {
          context.read<SocketService>().connect(auth.repository.getEmail()!);
          _isSocketInitialized = true;
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          supportedLocales: const [
            Locale('en', ''),
            Locale('fr', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: _parseTheme(themeModePref),
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: primaryColor,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: primaryColor,
            brightness: Brightness.dark,
          ),
          home: auth.isLoggedIn ? const HomeView() : const SetupView(),
          routes: {
            '/settings': (context) => const SettingsView(),
            '/home': (context) => const HomeView(),
          },
        );
      },
    );
  }

  ThemeMode _parseTheme(String pref) {
    if (pref == 'dark') return ThemeMode.dark;
    if (pref == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }
}