import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group_list.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart';
import '../controllers/list_controller.dart';
import '../controllers/group_controller.dart';
import 'grocery_list_view.dart';

class ListSelectionView extends StatefulWidget {
  final String groupId;

  const ListSelectionView({
    super.key,
    required this.groupId,
  });

  @override
  State<ListSelectionView> createState() => _ListSelectionViewState();
}

class _ListSelectionViewState extends State<ListSelectionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isShared = context.read<GroupController>().isCurrentGroupShared;
      context.read<ListController>().loadLists(widget.groupId, isShared);
    });
  }

  void _showCreateListDialog(BuildContext context) {
    final controller = TextEditingController();
    final listCtrl = context.read<ListController>();
    final isShared = context.read<GroupController>().isCurrentGroupShared;

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context, 'cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await listCtrl.createList(controller.text, widget.groupId, isShared);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(L10n.of(context, 'create')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context) {
    final groupCtrl = context.read<GroupController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context, 'delete_group_title') ?? 'Delete Group'),
        content: Text(L10n.of(context, 'delete_group_warning') ?? 'Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context, 'cancel'))),
          TextButton(
            onPressed: () async {
              try {
                await groupCtrl.deleteGroup(widget.groupId);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(L10n.of(context, 'delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listCtrl = context.watch<ListController>();
    final groupCtrl = context.watch<GroupController>();

    return MainLayout(
      title: L10n.of(context, 'my_lists'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          onPressed: () => _confirmDeleteGroup(context),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListDialog(context),
        child: const Icon(Icons.add),
      ),
      child: listCtrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListContent(context, listCtrl),
    );
  }

  Widget _buildListContent(BuildContext context, ListController listCtrl) {
    if (listCtrl.lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.list_alt, size: 64, color: Colors.grey),
            Text(L10n.of(context, 'no_lists_found')),
            ElevatedButton(
              onPressed: () => _showCreateListDialog(context),
              child: Text(L10n.of(context, 'create_first_list')),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: listCtrl.lists.length,
      itemBuilder: (context, index) {
        final groceryList = listCtrl.lists[index];
        final dateStr = "${groceryList.createdAt.day}/${groceryList.createdAt.month}/${groceryList.createdAt.year}";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.shopping_basket_outlined),
            title: Text(groceryList.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${L10n.of(context, 'created_on')} $dateStr"),
            trailing: const Icon(Icons.chevron_right),
            onLongPress: () => _confirmDeleteList(context, groceryList),
            onTap: () {
              listCtrl.setOpenedList(groceryList.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroceryListView(sessionId: groceryList.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDeleteList(BuildContext context, GroceryList list) {
    final listCtrl = context.read<ListController>();
    final isShared = context.read<GroupController>().isCurrentGroupShared;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context, 'delete_list_title') ?? 'Delete List'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context, 'cancel'))),
          TextButton(
            onPressed: () async {
              await listCtrl.deleteList(list.id, widget.groupId, isShared);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(L10n.of(context, 'delete')),
          ),
        ],
      ),
    );
  }
}