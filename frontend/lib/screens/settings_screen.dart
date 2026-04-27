import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/grocery_repository.dart';
import '../utils/l10n.dart';

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
          SnackBar(content: Text(L10n.of(context, 'profile_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(L10n.of(context, 'update_failed')),
            content: Text(e.toString().contains("409")
                ? L10n.of(context, 'email_conflict')
                : L10n.of(context, 'update_error')),
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
        title: Text(L10n.of(context, 'connect_existing')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L10n.of(context, 'sync_subtitle')),
            const SizedBox(height: 16),
            TextField(
              controller: _syncCodeController,
              decoration: InputDecoration(
                hintText: L10n.of(context, 'sync_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context, 'cancel'))),
          ElevatedButton(
              onPressed: () async {
                // await widget.repository.linkAccount(_syncCodeController.text);
                Navigator.pop(ctx);
              },
              child: Text(L10n.of(context, 'sync_now'))
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
      appBar: AppBar(title: Text(L10n.of(context, 'settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(L10n.of(context, 'profile_header')),
          TextField(controller: _fnameController, decoration: InputDecoration(labelText: L10n.of(context, 'first_name'))),
          TextField(controller: _lnameController, decoration: InputDecoration(labelText: L10n.of(context, 'last_name'))),
          TextField(controller: _emailController, decoration: InputDecoration(labelText: L10n.of(context, 'email_address'))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _updateProfile,
              icon: const Icon(Icons.save),
              label: Text(L10n.of(context, 'save_profile'))
          ),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'sync_header')),
          ListTile(
            title: Text(L10n.of(context, 'your_sync_code')),
            subtitle: Text(syncCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: syncCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context, 'copy_clipboard'))));
                }
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(L10n.of(context, 'sync_description'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(L10n.of(context, 'connect_existing')),
            subtitle: Text(L10n.of(context, 'sync_phone_subtitle')),
            onTap: _showSyncDialog,
          ),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'appearance_header')),
          DropdownButtonFormField<String>(
            value: box.get('language', defaultValue: 'fr'),
            decoration: InputDecoration(
              labelText: L10n.of(context, 'language_label'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.language),
            ),
            items: [
              DropdownMenuItem(value: 'fr', child: Text(L10n.of(context, 'lang_fr'))),
              DropdownMenuItem(value: 'en', child: Text(L10n.of(context, 'lang_en'))),
            ],
            onChanged: (val) {
              if (val != null) {
                box.put('language', val);
                // Note: You may need a ValueListenableBuilder in main.dart
                // to rebuild the app with the new Locale immediately.
              }
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: box.get('themeMode', defaultValue: 'system'),
            decoration: InputDecoration(labelText: L10n.of(context, 'theme_mode'), border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'system', child: Text(L10n.of(context, 'follow_system'))),
              DropdownMenuItem(value: 'light', child: Text(L10n.of(context, 'light_mode'))),
              DropdownMenuItem(value: 'dark', child: Text(L10n.of(context, 'dark_mode'))),
            ],
            onChanged: (val) {
              if (val != null) box.put('themeMode', val);
            },
          ),
          const SizedBox(height: 20),
          Text(L10n.of(context, 'primary_color'), style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Colors.green, Colors.blue, Colors.red, Colors.orange,
              Colors.purple, Colors.teal, Colors.pink
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
          _sectionHeader(L10n.of(context, 'danger_zone'), color: Colors.red),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(L10n.of(context, 'factory_reset')),
            subtitle: Text(L10n.of(context, 'reset_subtitle')),
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
        title: Text(L10n.of(context, 'reset_confirm_title')),
        content: Text(L10n.of(context, 'reset_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context, 'cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context, 'wipe_all'), style: const TextStyle(color: Colors.red))
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