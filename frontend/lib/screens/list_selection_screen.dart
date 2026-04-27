import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group_list.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart'; // Import l10n
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
        title: Text(L10n.of(context, 'new_list_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context, 'list_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.of(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await repository.createList(controller.text, groupId);
                await repository.getListsForGroup(groupId);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(L10n.of(context, 'create')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: L10n.of(context, 'my_lists'),
      repository: repository,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListDialog(context),
        tooltip: L10n.of(context, 'add_list_tooltip'),
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
                  Text(L10n.of(context, 'no_lists_found')),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showCreateListDialog(context),
                    child: Text(L10n.of(context, 'create_first_list')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final groceryList = lists[index];
              // Simple date formatting
              final dateStr = "${groceryList.createdAt.day}/${groceryList.createdAt.month}/${groceryList.createdAt.year}";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined),
                  title: Text(
                    groceryList.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${L10n.of(context, 'created_on')} $dateStr"),
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