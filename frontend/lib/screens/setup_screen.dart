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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_basket, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text("Welcome to Grocery Master", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Enter your details to start sharing lists."),
            const SizedBox(height: 30),
            TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address')),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: const Text("Get Started")),
          ],
        ),
      ),
    );
  }
}