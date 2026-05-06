import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/l10n.dart';

class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _syncCodeController = TextEditingController();

  bool _isSyncingMode = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _syncCodeController.dispose();
    super.dispose();
  }

  void _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isNotEmpty && lastName.isNotEmpty && email.contains('@')) {
      final authCtrl = context.read<AuthController>();

      try {
        await authCtrl.register(firstName, lastName, email);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Registration failed: $e")),
          );
        }
      }
    }
  }

  void _syncAccount() async {
    final code = _syncCodeController.text.trim();
    if (code.isNotEmpty) {
      final authCtrl = context.read<AuthController>();
      try {
        await authCtrl.linkWithCode(code);
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
    final authLoading = context.select<AuthController, bool>((ctrl) => ctrl.isLoading);

    return Scaffold(
      body: authLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.shopping_basket, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              _isSyncingMode ? L10n.of(context, 'sync_title') : L10n.of(context, 'setup_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            if (!_isSyncingMode) ...[
              Text(L10n.of(context, 'setup_subtitle')),
              const SizedBox(height: 30),
              TextField(controller: _firstNameController, decoration: InputDecoration(labelText: L10n.of(context, 'first_name'))),
              TextField(controller: _lastNameController, decoration: InputDecoration(labelText: L10n.of(context, 'last_name'))),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: L10n.of(context, 'email_address'))),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _submit, child: Text(L10n.of(context, 'get_started'))),
              TextButton(
                onPressed: () => setState(() => _isSyncingMode = true),
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
                onPressed: () => setState(() => _isSyncingMode = false),
                child: Text(L10n.of(context, 'back_to_reg')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}