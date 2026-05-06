import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/l10n.dart';

class SettingsView extends StatefulWidget {

  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _fnameController;
  late TextEditingController _lnameController;
  late TextEditingController _emailController;
  final TextEditingController _syncCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _fnameController = TextEditingController(text: auth.userProfile?.firstName);
    _lnameController = TextEditingController(text: auth.userProfile?.lastName);
    _emailController = TextEditingController(text: auth.userProfile?.email);
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
    final auth = context.read<AuthController>();
    try {
      await auth.updateProfile(
        firstName: _fnameController.text.trim(),
        lastName: _lnameController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context, 'profile_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context, 'update_error'))),
        );
      }
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context, 'connect_existing')),
        content: TextField(
          controller: _syncCodeController,
          decoration: InputDecoration(
            hintText: L10n.of(context, 'sync_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context, 'cancel'))),
          ElevatedButton(
            onPressed: () async {
              final code = _syncCodeController.text.trim();
              if (code.isNotEmpty) {
                await context.read<AuthController>().linkWithCode(code);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: Text(L10n.of(context, 'sync_now')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
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
              label: Text(L10n.of(context, 'save_profile'))),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'notification_settings'), color: Colors.blue),
          _buildNotifSwitch(box, 'notify_invitations', L10n.of(context, 'notif_invites')),
          _buildNotifSwitch(box, 'notify_list_created', L10n.of(context, 'notif_list_created')),
          _buildNotifSwitch(box, 'notify_carry_over', L10n.of(context, 'notif_carry_over')),
          _buildNotifSwitch(box, 'notify_item_changes', L10n.of(context, 'notif_items')),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'sync_header')),
          ListTile(
            title: Text(L10n.of(context, 'your_sync_code')),
            subtitle: Text(
              auth.syncCode,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey
              ),
            ),
            trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: auth.syncCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context, 'copy_clipboard'))));
                }),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(L10n.of(context, 'connect_existing')),
            onTap: _showSyncDialog,
          ),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'appearance_header')),
          // Language Dropdown... (kept same as your logic)
          _buildThemeDropdown(box, context),

          const Divider(height: 40),
          _sectionHeader(L10n.of(context, 'danger_zone'), color: Colors.red),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(L10n.of(context, 'factory_reset')),
            onTap: () => _handleReset(context),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeDropdown(Box<String> box, BuildContext context) {
    return DropdownButtonFormField<String>(
      value: box.get('themeMode', defaultValue: 'system'),
      decoration: InputDecoration(
        labelText: L10n.of(context, 'theme_mode'),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.brightness_6),
      ),
      items: [
        DropdownMenuItem(
          value: 'system',
          child: Text(L10n.of(context, 'follow_system')),
        ),
        DropdownMenuItem(
          value: 'light',
          child: Text(L10n.of(context, 'light_mode')),
        ),
        DropdownMenuItem(
          value: 'dark',
          child: Text(L10n.of(context, 'dark_mode')),
        ),
      ],
      onChanged: (val) {
        if (val != null) {
          // This triggers the ValueListenableBuilder in main.dart
          box.put('themeMode', val);
        }
      },
    );
  }

  Widget _buildNotifSwitch(Box<String> box, String key, String label) {
    return SwitchListTile(
      title: Text(label),
      value: box.get(key, defaultValue: 'true') == 'true',
      onChanged: (val) => setState(() => box.put(key, val.toString())),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context, 'cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context, 'wipe_all'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AuthController>().logout(); // Controller handles the data wipe
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }
}