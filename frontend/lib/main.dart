import 'package:flutter/material.dart';
import 'package:frontend/screens/list_selection_screen.dart';
import 'package:frontend/screens/setup_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'repositories/grocery_repository.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(GroceryApp(repository: repository));
}

class GroceryApp extends StatefulWidget {
  final GroceryRepository repository;
  const GroceryApp({super.key, required this.repository});

  @override
  State<GroceryApp> createState() => _GroceryAppState();
}

class _GroceryAppState extends State<GroceryApp> {
  @override
  Widget build(BuildContext context) {
    // We listen to the 'metadata' box for theme or profile changes
    return ValueListenableBuilder(
      valueListenable: Hive.box<String>('metadata').listenable(),
      builder: (context, Box<String> box, _) {
        final String? userEmail = box.get('userEmail');

        // 1. Get Theme Mode (System, Light, Dark)
        final String themeModePref = box.get('themeMode') ?? 'system';
        ThemeMode currentThemeMode = ThemeMode.system;
        if (themeModePref == 'light') currentThemeMode = ThemeMode.light;
        if (themeModePref == 'dark') currentThemeMode = ThemeMode.dark;

        // 2. Get Color Seed (Saved as String of hex or integer in Settings)
        // Default to Green if not set
        final String? colorSeedHex = box.get('colorSeed');
        final Color seedColor = colorSeedHex != null
            ? Color(int.parse(colorSeedHex))
            : Colors.green;

        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Grocery Master',

          // Theme Logic
          themeMode: currentThemeMode,
          theme: ThemeData(
            colorSchemeSeed: seedColor,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: seedColor,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),

          home: userEmail == null
              ? SetupScreen(
            repository: widget.repository,
            onComplete: () => setState(() {}),
          )
              : ListSelectionScreen(
            repository: widget.repository,
            groupId: widget.repository.getActiveGroupId(),
          ),
          routes: {
            '/settings': (context) => SettingsScreen(repository: widget.repository),
          },
        );
      },
    );
  }
}