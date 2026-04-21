import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../repositories/grocery_repository.dart';
import '../screens/sessions_screen.dart';
import '../screens/list_selection_screen.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final GroceryRepository repository;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.repository,
    this.actions,
    this.floatingActionButton,
  });

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isShared = false; // Local state for the dialog

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Group'),
        content: StatefulBuilder( // Allows the checkbox to update inside the dialog
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Group Name (e.g., Camping Trip)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Share this group'),
                  subtitle: const Text('Syncs with the server for everyone'),
                  value: isShared,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      isShared = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // Pass the isShared value to your repository
                await repository.createGroup(
                    controller.text,
                    isShared: isShared
                );
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String activeGroupId = repository.getActiveGroupId();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Grocery Master',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            // Dynamic Group Selection
            const ListTile(
              leading: Icon(Icons.group_work),
              title: Text('Active Group', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: Hive.box<GroceryGroup>('groups').listenable(),
                builder: (context, Box<GroceryGroup> box, _) {
                  final groups = repository.getAllGroups();

                  // Ensure activeGroupId exists in the list to avoid dropdown errors
                  final effectiveValue = groups.any((g) => g.id == activeGroupId)
                      ? activeGroupId
                      : (groups.isNotEmpty ? groups.first.id : null);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: effectiveValue,
                        hint: const Text("Select Group"),
                        items: groups.map((group) {
                          return DropdownMenuItem<String>(
                            value: group.id,
                            child: Row(
                              children: [
                                Text(group.name),
                                if (group.isShared) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.cloud_queue, size: 16, color: Colors.blue),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            await repository.setActiveGroup(newValue);
                            if (context.mounted) {
                              Navigator.pop(context); // Close drawer
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListSelectionScreen(
                                    repository: repository,
                                    groupId: newValue,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.green),
              title: const Text('Create New Group'),
              onTap: () => _showCreateGroupDialog(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('My Lists'),
              selected: title == 'My Lists',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListSelectionScreen(
                      repository: repository,
                      groupId: activeGroupId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Trip History'),
              selected: title == 'Archived Lists',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionsScreen(
                      repository: repository,
                      groupId: activeGroupId,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}