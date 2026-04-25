import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/grocery_repository.dart';

class SettingsScreen extends StatefulWidget {
  final GroceryRepository repository;

  const SettingsScreen({super.key, required this.repository});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _fnameController;
  late TextEditingController _lnameController;
  late TextEditingController _emailController;
  final TextEditingController _syncCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final box = Hive.box<String>('metadata');
    _fnameController = TextEditingController(text: box.get('firstName'));
    _lnameController = TextEditingController(text: box.get('lastName'));
    _emailController = TextEditingController(text: box.get('userEmail'));
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _lnameController.dispose();
    _emailController.dispose();
    _syncCodeController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    try {
      await widget.repository.updateProfile(
        firstName: _fnameController.text,
        lastName: _lnameController.text,
        email: _emailController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Update Failed"),
            content: Text(e.toString().contains("409")
                ? "This email is already linked to another account."
                : "Could not update profile. Check your connection."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
            ],
          ),
        );
      }
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sync to Existing Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the Sync Code from your primary device:"),
            const SizedBox(height: 16),
            TextField(
              controller: _syncCodeController,
              decoration: const InputDecoration(
                hintText: "Paste code here",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                // Implementation would call a repository method to link device IDs
                // await widget.repository.linkAccount(_syncCodeController.text);
                Navigator.pop(ctx);
              },
              child: const Text("Sync Now")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncCode = widget.repository.getSyncCode();
    final box = Hive.box<String>('metadata');

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("User Profile"),
          TextField(controller: _fnameController, decoration: const InputDecoration(labelText: "First Name")),
          TextField(controller: _lnameController, decoration: const InputDecoration(labelText: "Last Name")),
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _updateProfile,
              icon: const Icon(Icons.save),
              label: const Text("Save Profile Changes")
          ),

          const Divider(height: 40),
          _sectionHeader("Device Sync"),
          ListTile(
            title: const Text("Your Sync Code"),
            subtitle: Text(syncCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: syncCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied to clipboard")));
                }
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Use this code on another device to access your recipes and lists.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text("Connect to Existing Account"),
            subtitle: const Text("Sync this phone to another device"),
            onTap: _showSyncDialog,
          ),

          const Divider(height: 40),
          _sectionHeader("Appearance"),
          DropdownButtonFormField<String>(
            value: box.get('themeMode', defaultValue: 'system'),
            decoration: const InputDecoration(labelText: "Theme Mode", border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'system', child: Text("Follow System")),
              DropdownMenuItem(value: 'light', child: Text("Light Mode")),
              DropdownMenuItem(value: 'dark', child: Text("Dark Mode")),
            ],
            onChanged: (val) {
              if (val != null) box.put('themeMode', val);
            },
          ),
          const SizedBox(height: 20),
          const Text("Primary Color Theme", style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Colors.green,
              Colors.blue,
              Colors.red,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.pink
            ].map((color) {
              final isSelected = box.get('colorSeed') == color.value.toString();
              return GestureDetector(
                onTap: () => box.put('colorSeed', color.value.toString()),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: 20,
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),

          const Divider(height: 40),
          _sectionHeader("Danger Zone", color: Colors.red),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Factory Reset"),
            subtitle: const Text("Wipe all local data and preferences"),
            onTap: () => _handleReset(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Color color = Colors.green}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
    );
  }

  Future<void> _handleReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset App?"),
        content: const Text("This will permanently delete all local recipes, lists, and settings. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Wipe Everything", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.resetAppDatabase();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }
}