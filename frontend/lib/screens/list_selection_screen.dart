import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group_list.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import 'grocery_list_screen.dart';

class ListSelectionScreen extends StatelessWidget {
  final GroceryRepository repository;
  final String groupId;

  const ListSelectionScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });

  void _showCreateListDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Grocery List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Weekly Groceries, BBQ Party',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await repository.createList(controller.text, groupId);
                await repository.getListsForGroup(groupId);
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
    return MainLayout(
      title: 'My Lists',
      repository: repository,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListDialog(context),
        tooltip: 'Add New List',
        child: const Icon(Icons.add),
      ),
      child: ValueListenableBuilder(
        valueListenable: Hive.box<GroceryList>('lists').listenable(),
        builder: (context, Box<GroceryList> box, _) {
          final lists = repository.getListsForGroup(groupId);

          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.list_alt, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No lists found for this group.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showCreateListDialog(context),
                    child: const Text('Create your first list'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final groceryList = lists[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined),
                  title: Text(
                    groceryList.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Created on ${groceryList.createdAt.day}/${groceryList.createdAt.month}/${groceryList.createdAt.year}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroceryListScreen(
                          repository: repository,
                          sessionId: groceryList.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}