import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';

class HomeScreen extends StatefulWidget {
  final GroceryRepository repository;
  // This is now mandatory for the home screen to know which list to display
  final String? sessionId;

  const HomeScreen({super.key, required this.repository, this.sessionId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  // If sessionId is null, we are likely in an error state or default view.
  // In your new flow, sessionId should always be passed from the ListSelectionScreen.
  bool get isHistoryMode => widget.sessionId == null;

  void _handleSave() {
    if (_controller.text.isNotEmpty && widget.sessionId != null) {
      final activeGroupId = widget.repository.getActiveGroupId();
      widget.repository.addItemToList(
          _controller.text,
          widget.sessionId!,
          activeGroupId
      );
      _controller.clear();
      Navigator.pop(context);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to List'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Milk, Eggs, Rust Book',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _handleSave(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handleSave,
            child: const Text('Add'),
          ),
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
        );
      case ItemStatus.discarded:
        return const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.orangeAccent,
          decoration: TextDecoration.lineThrough,
        );
      default:
        return const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Box<GroceryItem> itemBox = Hive.box<GroceryItem>('items');

    // Fallback if somehow accessed without a list ID
    if (widget.sessionId == null) {
      return MainLayout(
        title: 'Error',
        repository: widget.repository,
        child: const Center(child: Text('No list selected.')),
      );
    }

    return MainLayout(
      title: 'Items',
      repository: widget.repository,
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome_motion),
          tooltip: 'Finish & Carry Over',
          onPressed: () async {
            // Logic to archive current list and move items to a new one
            await widget.repository.carryOverToNewList(
                widget.sessionId!,
                "Carried Over List"
            );
            if (mounted) Navigator.pop(context); // Go back to List selection
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_shopping_cart),
      ),
      child: ValueListenableBuilder(
        valueListenable: itemBox.listenable(),
        builder: (context, Box<GroceryItem> box, _) {
          // Use the new repository method to get items for this specific list
          final items = widget.repository.getItemsForList(widget.sessionId!);

          if (items.isEmpty) {
            return const Center(
              child: Text('No items found.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];

              return ListTile(
                leading: Checkbox(
                  value: item.status == ItemStatus.bought,
                  onChanged: (val) {
                    widget.repository.updateItemStatus(
                      item,
                      val! ? ItemStatus.bought : ItemStatus.pending,
                    );
                  },
                ),
                title: Text(item.name, style: _getItemStyle(item.status)),
                subtitle: item.status == ItemStatus.discarded
                    ? const Text('Discarded')
                    : null,
                trailing: PopupMenuButton<ItemStatus>(
                  onSelected: (status) =>
                      widget.repository.updateItemStatus(item, status),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ItemStatus.pending,
                      child: Text('Mark Pending'),
                    ),
                    const PopupMenuItem(
                      value: ItemStatus.discarded,
                      child: Text('Discard'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      onTap: () => widget.repository.deleteItem(item),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
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