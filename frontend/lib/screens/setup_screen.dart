import 'package:flutter/material.dart';
import '../repositories/grocery_repository.dart';

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
      // 1. Save to Hive via Repository
      await widget.repository.setUserDetails(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      // 2. Sync to Postgres
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Sync Code or Connection Error")),
        );
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
            Text(_isSyncing ? "Sync Your Account" : "Welcome to Grocery Master",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

            if (!_isSyncing) ...[
              const Text("Enter your details to start sharing lists."),
              const SizedBox(height: 30),
              TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address')),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _submit, child: const Text("Get Started")),
              TextButton(
                onPressed: () => setState(() => _isSyncing = true),
                child: const Text("Already have an account? Sync here"),
              ),
            ] else ...[
              const Text("Enter the Sync Code from your other device."),
              const SizedBox(height: 30),
              TextField(
                  controller: _syncCodeController,
                  decoration: const InputDecoration(
                      labelText: 'Sync Code',
                      hintText: 'Paste code here',
                      border: OutlineInputBorder()
                  )
              ),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _syncAccount, child: const Text("Sync Now")),
              TextButton(
                onPressed: () => setState(() => _isSyncing = false),
                child: const Text("Back to Registration"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}