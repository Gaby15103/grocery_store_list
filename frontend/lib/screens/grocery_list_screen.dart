import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart'; // Import localization tool

class GroceryListScreen extends StatefulWidget {
  final GroceryRepository repository;
  final String? sessionId;

  const GroceryListScreen({super.key, required this.repository, this.sessionId});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      widget.repository.setCurrentlyViewedList(widget.sessionId!);
      widget.repository.getItemsForList(widget.sessionId!);
    }
  }

  @override
  void dispose() {
    widget.repository.setCurrentlyViewedList(null);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_controller.text.isNotEmpty && widget.sessionId != null) {
      final activeGroupId = widget.repository.getActiveGroupId();

      await widget.repository.addItemToList(
          _controller.text,
          widget.sessionId!,
          activeGroupId
      );

      _controller.clear();
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context, 'add_to_list')),
        content: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _handleSave(),
          decoration: InputDecoration(
              hintText: L10n.of(context, 'item_hint'),
              border: const OutlineInputBorder()
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context, 'cancel'))),
          ElevatedButton(onPressed: _handleSave, child: Text(L10n.of(context, 'add'))),
        ],
      ),
    );
  }

  TextStyle _getItemStyle(ItemStatus status) {
    switch (status) {
      case ItemStatus.bought:
        return const TextStyle(
          decoration: TextDecoration.lineThrough,
          color: Colors.grey,
          fontSize: 16,
        );
      case ItemStatus.discarded:
        return const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.orange,
          decoration: TextDecoration.lineThrough,
          fontSize: 16,
        );
      default:
        return const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          // Removed hardcoded white to adapt to Light/Dark themes
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Box<GroceryItem> itemBox = Hive.box<GroceryItem>('items');

    if (widget.sessionId == null) {
      return MainLayout(
          title: 'Error',
          repository: widget.repository,
          child: Center(child: Text(L10n.of(context, 'error_no_list')))
      );
    }

    return MainLayout(
      title: L10n.of(context, 'items_title'),
      repository: widget.repository,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_shopping_cart),
      ),
      child: ValueListenableBuilder(
        valueListenable: itemBox.listenable(),
        builder: (context, Box<GroceryItem> box, _) {
          final items = box.values.where((i) => i.listId == widget.sessionId).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (items.isEmpty) {
            return Center(child: Text(L10n.of(context, 'no_items'), style: const TextStyle(color: Colors.grey)));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final isDiscarded = item.status == ItemStatus.discarded;

              return ListTile(
                tileColor: isDiscarded ? Colors.orange.withOpacity(0.05) : null,
                leading: isDiscarded
                    ? const Icon(Icons.delete_sweep, color: Colors.orange)
                    : Checkbox(
                  value: item.status == ItemStatus.bought,
                  onChanged: (val) {
                    widget.repository.updateItemStatus(
                      item,
                      val! ? ItemStatus.bought : ItemStatus.pending,
                    );
                  },
                ),
                title: Text(item.name, style: _getItemStyle(item.status)),
                subtitle: isDiscarded
                    ? Text(L10n.of(context, 'item_discarded'), style: const TextStyle(color: Colors.orange, fontSize: 12))
                    : null,
                trailing: PopupMenuButton<ItemStatus>(
                  onSelected: (status) => widget.repository.updateItemStatus(item, status),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: ItemStatus.pending, child: Text(L10n.of(context, 'mark_pending'))),
                    PopupMenuItem(value: ItemStatus.discarded, child: Text(L10n.of(context, 'discard'))),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      onTap: () => widget.repository.deleteItem(item),
                      child: Text(L10n.of(context, 'delete'), style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              );
            },
          );
        },
      ),
    );
  }
}