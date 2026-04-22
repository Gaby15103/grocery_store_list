import 'package:flutter/material.dart';
import 'package:frontend/screens/list_selection_screen.dart';
import 'package:frontend/screens/setup_screen.dart';
import 'package:frontend/screens/settings_screen.dart'; // Import your new screen
import 'package:hive_flutter/hive_flutter.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'repositories/grocery_repository.dart';
import 'screens/home_screen.dart';

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

  // Initialize repository (fetches remote groups if email exists)
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
    final String? userEmail = Hive.box<String>('metadata').get('userEmail');

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Grocery Master',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      // The 'home' property acts as our root/initial route logic
      home: userEmail == null
          ? SetupScreen(
        repository: widget.repository,
        onComplete: () => setState(() {}),
      )
          : ListSelectionScreen(
        repository: widget.repository,
        groupId: widget.repository.getActiveGroupId(),
      ),
      // Define routes for navigation (Settings, etc.)
      routes: {
        '/settings': (context) => SettingsScreen(repository: widget.repository),
      },
    );
  }
}