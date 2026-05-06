import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart';
import '../controllers/list_controller.dart';
import '../controllers/group_controller.dart';
import 'grocery_list_view.dart';

class SessionsView extends StatefulWidget {
  final String groupId;

  const SessionsView({
    super.key,
    required this.groupId,
  });

  @override
  State<SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends State<SessionsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isShared = context.read<GroupController>().isCurrentGroupShared;
      context.read<ListController>().loadLists(widget.groupId, isShared);
    });
  }

  @override
  Widget build(BuildContext context) {
    final listCtrl = context.watch<ListController>();

    final archivedLists = listCtrl.lists.where((l) => l.isArchived).toList();

    return MainLayout(
      title: L10n.of(context, 'archived_lists'),
      child: listCtrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildArchiveContent(context, archivedLists),
    );
  }

  Widget _buildArchiveContent(BuildContext context, List archivedLists) {
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
                  builder: (context) => GroceryListView(
                    sessionId: groceryList.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}