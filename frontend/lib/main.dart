import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/group_list.dart';
import 'models/item.dart';
import 'models/group.dart';
import 'repositories/grocery_repository.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 1. Register Adapters
  Hive.registerAdapter(ItemStatusAdapter());
  Hive.registerAdapter(GroceryItemAdapter());
  Hive.registerAdapter(GroceryGroupAdapter());
  Hive.registerAdapter(GroceryListAdapter());

  // 2. Open all boxes and WAIT for them
  await Future.wait([
    Hive.openBox<GroceryItem>('items'),
    Hive.openBox<GroceryGroup>('groups'),
    Hive.openBox<GroceryList>('lists'),
    Hive.openBox<String>('metadata'),
  ]);

  // 3. ONLY NOW create the repository
  final repository = GroceryRepository();

  runApp(GroceryApp(repository: repository));
}

class GroceryApp extends StatelessWidget {
  final GroceryRepository repository;

  const GroceryApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Master',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // Define the named route for the soft-restart logic in MainLayout
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(repository: repository),
      },
    );
  }
}