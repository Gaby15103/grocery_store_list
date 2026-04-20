import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group_list.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import 'home_screen.dart';

class SessionsScreen extends StatelessWidget {
  final GroceryRepository repository;
  final String groupId;

  const SessionsScreen({super.key, required this.repository, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Archived Lists',
      repository: repository,
      child: ValueListenableBuilder(
        // We listen to the lists box now, as that's our primary record of "trips"
        valueListenable: Hive.box<GroceryList>('lists').listenable(),
        builder: (context, Box<GroceryList> box, _) {
          // Get archived lists for this group from the repository
          final archivedLists = repository.getListsForGroup(groupId)
              .where((l) => l.isArchived)
              .toList();

          if (archivedLists.isEmpty) {
            return const Center(
              child: Text(
                'No archived trips yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: archivedLists.length,
            itemBuilder: (context, index) {
              final groceryList = archivedLists[index];
              final date = groceryList.createdAt;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(groceryList.name),
                  subtitle: Text(
                    'Completed on ${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Open the specific archived list in the Home Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
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