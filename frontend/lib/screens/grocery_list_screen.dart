import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart';
import '../models/item.dart';
import '../repositories/grocery_repository.dart';
import '../services/SocketService.dart';
import '../widgets/main_layout.dart';

class GroceryListScreen extends StatefulWidget {
  final GroceryRepository repository;
  final String? sessionId;

  const GroceryListScreen({super.key, required this.repository, this.sessionId});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final TextEditingController _controller = TextEditingController();
  late SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(widget.repository);

    if (widget.sessionId != null) {
      widget.repository.getItemsForList(widget.sessionId!);

      final email = widget.repository.getUserEmail() ?? 'guest';
      _socketService.connect(email);

      _socketService.socket.onConnect((_) {
        final activeGroupId = widget.repository.getActiveGroupId();
        _socketService.joinGroup(activeGroupId);
      });

      _setupSocketListeners();
    }
  }

  void _setupSocketListeners() {
    _socketService.socket.on('item_added', (data) {
      widget.repository.handleSocketItemAdded(data);
    });

    _socketService.socket.on('item_updated', (data) {
      widget.repository.handleSocketItemUpdated(data);
    });

    _socketService.socket.on('list_synced', (_) {
      widget.repository.getItemsForList(widget.sessionId!);
    });
  }

  @override
  void dispose() {
    _socketService.dispose();
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
        title: const Text('Add to List'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _handleSave(),
          decoration: const InputDecoration(hintText: 'e.g., Milk', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _handleSave, child: const Text('Add')),
        ],
      ),
    );
  }

  TextStyle _getItemStyle(ItemStatus status) {
    if (status == ItemStatus.bought) return const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey);
    if (status == ItemStatus.discarded) return const TextStyle(fontStyle: FontStyle.italic, color: Colors.orangeAccent, decoration: TextDecoration.lineThrough);
    return const TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
  }

  @override
  Widget build(BuildContext context) {
    final Box<GroceryItem> itemBox = Hive.box<GroceryItem>('items');

    if (widget.sessionId == null) {
      return MainLayout(title: 'Error', repository: widget.repository, child: const Center(child: Text('No list selected.')));
    }

    return MainLayout(
      title: 'Items',
      repository: widget.repository,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_shopping_cart),
      ),
      child: ValueListenableBuilder(
        valueListenable: itemBox.listenable(),
        builder: (context, Box<GroceryItem> box, _) {
          // Filter locally from the box
          final items = box.values.where((i) => i.listId == widget.sessionId).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (items.isEmpty) {
            return const Center(child: Text('No items found.', style: TextStyle(color: Colors.grey)));
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
                    if (mounted) {
                      setState(() {});
                    }
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