import 'package:flutter/material.dart';
import 'package:grocery_list/services/socket_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group_list.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart'; // Import localization tool
import 'grocery_list_screen.dart';

class SessionsScreen extends StatelessWidget {
  final GroceryRepository repository;
  final String groupId;
  final SocketService socketService;

  const SessionsScreen({
    super.key,
    required this.repository,
    required this.groupId,
    required this.socketService,
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: L10n.of(context, 'archived_lists'),
      repository: repository,
      socketService: socketService,
      child: ValueListenableBuilder(
        valueListenable: Hive.box<GroceryList>('lists').listenable(),
        builder: (context, Box<GroceryList> box, _) {
          final archivedLists = repository.getListsForGroup(groupId)
              .where((l) => l.isArchived)
              .toList();

          if (archivedLists.isEmpty) {
            return Center(
              child: Text(
                L10n.of(context, 'no_archived_trips'),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: archivedLists.length,
            itemBuilder: (context, index) {
              final groceryList = archivedLists[index];
              final date = groceryList.createdAt;

              // Localized date and time string
              final dateStr = "${date.day}/${date.month}/${date.year}";
              final timeStr = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(
                    groceryList.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${L10n.of(context, 'completed_on')} $dateStr ${L10n.of(context, 'at_time')} $timeStr',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroceryListScreen(
                          repository: repository,
                          sessionId: groceryList.id,
                          socketService: socketService,
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