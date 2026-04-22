import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../models/group_list.dart';
import '../models/item.dart';
import '../repositories/grocery_repository.dart';

class SettingsScreen extends StatelessWidget {
  final GroceryRepository repository;

  const SettingsScreen({super.key, required this.repository});

  Future<void> _handleReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset App?"),
        content: const Text("This will wipe all local data and your user profile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Reset", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repository.resetAppDatabase();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = repository.getUserEmail() ?? "Not set";

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text("Email"),
            subtitle: Text(email),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Danger Zone", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Factory Reset"),
            subtitle: const Text("Wipe all local settings and cache"),
            onTap: () => _handleReset(context),
          ),
        ],
      ),
    );
  }
}