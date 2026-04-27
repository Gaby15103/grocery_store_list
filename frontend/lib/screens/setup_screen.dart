import 'package:flutter/material.dart';
import '../repositories/grocery_repository.dart';
import '../utils/l10n.dart'; // Import your new tool

class SetupScreen extends StatefulWidget {
  final GroceryRepository repository;
  final VoidCallback onComplete;

  const SetupScreen({super.key, required this.repository, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _syncCodeController = TextEditingController();
  bool _isSyncing = false;

  void _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isNotEmpty && lastName.isNotEmpty && email.contains('@')) {
      await widget.repository.setUserDetails(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      await widget.repository.syncUserToServer();
      widget.onComplete();
    }
  }

  void _syncAccount() async {
    final code = _syncCodeController.text.trim();
    if (code.isNotEmpty) {
      try {
        await widget.repository.linkAccount(code);
        widget.onComplete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context, 'sync_error'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.shopping_basket, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              _isSyncing ? L10n.of(context, 'sync_title') : L10n.of(context, 'setup_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            if (!_isSyncing) ...[
              Text(L10n.of(context, 'setup_subtitle')),
              const SizedBox(height: 30),
              TextField(controller: _firstNameController, decoration: InputDecoration(labelText: L10n.of(context, 'first_name'))),
              TextField(controller: _lastNameController, decoration: InputDecoration(labelText: L10n.of(context, 'last_name'))),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: L10n.of(context, 'email_address'))),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _submit, child: Text(L10n.of(context, 'get_started'))),
              TextButton(
                onPressed: () => setState(() => _isSyncing = true),
                child: Text(L10n.of(context, 'already_account')),
              ),
            ] else ...[
              Text(L10n.of(context, 'sync_subtitle')),
              const SizedBox(height: 30),
              TextField(
                  controller: _syncCodeController,
                  decoration: InputDecoration(
                      labelText: L10n.of(context, 'sync_code'),
                      hintText: L10n.of(context, 'sync_hint'),
                      border: const OutlineInputBorder()
                  )
              ),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _syncAccount, child: Text(L10n.of(context, 'sync_now'))),
              TextButton(
                onPressed: () => setState(() => _isSyncing = false),
                child: Text(L10n.of(context, 'back_to_reg')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}