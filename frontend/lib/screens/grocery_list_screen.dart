import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../models/item.dart';
import '../repositories/grocery_repository.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart';

class GroceryListScreen extends StatefulWidget {
  final GroceryRepository repository;
  final String? sessionId;

  const GroceryListScreen({super.key, required this.repository, this.sessionId});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

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
    _noteController.dispose();
    super.dispose();
  }

  ItemStatus _statusFromSocketString(String status) {
    return ItemStatus.values.firstWhere(
          (e) => e.name == status,
      orElse: () => ItemStatus.pending,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _handleSave() async {
    if (_controller.text.isNotEmpty && widget.sessionId != null) {
      final activeGroupId = widget.repository.getActiveGroupId();

      await widget.repository.addItemToList(
          _controller.text,
          widget.sessionId!,
          activeGroupId,
          _noteController.text,
          _selectedImage,
      );

      _controller.clear();
      _noteController.clear();
      setState(() => _selectedImage = null);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(L10n.of(context, 'add_to_list')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(hintText: L10n.of(context, 'item_hint')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(hintText: L10n.of(context, 'note_hint')),
                ),
                const SizedBox(height: 15),
                if (_selectedImage != null)
                  Image.file(_selectedImage!, height: 100, width: 100, fit: BoxFit.cover),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        await _pickImage(ImageSource.camera);
                        setDialogState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () async {
                        await _pickImage(ImageSource.gallery);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context, 'cancel'))),
            ElevatedButton(onPressed: _handleSave, child: Text(L10n.of(context, 'add'))),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(GroceryItem item) {
    _controller.text = item.name;
    _noteController.text = item.note ?? '';
    File? editImage;
    bool clearImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(L10n.of(context, 'edit_item')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: L10n.of(context, 'item_hint')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(hintText: L10n.of(context, 'note_hint')),
                ),
                const SizedBox(height: 15),

                // Image Preview logic
                if (!clearImage && (editImage != null || item.imagePath != null))
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: editImage != null
                            ? Image.file(editImage!, height: 100, width: 100, fit: BoxFit.cover)
                            : Image.network('${AppConfig.apiUrl}/${item.imagePath}', height: 100, width: 100, fit: BoxFit.cover),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => setDialogState(() => clearImage = true),
                      ),
                    ],
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                        if (image != null) setDialogState(() { editImage = File(image.path); clearImage = false; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                        if (image != null) setDialogState(() { editImage = File(image.path); clearImage = false; });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context, 'cancel'))),
            ElevatedButton(
              onPressed: () async {
                await widget.repository.updateItemDetails(
                  item: item,
                  newName: _controller.text,
                  newNote: _noteController.text,
                  newImageFile: editImage,
                  shouldClearImage: clearImage,
                );
                if (mounted) Navigator.pop(context);
                _controller.clear();
                _noteController.clear();
              },
              child: Text(L10n.of(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCarryOverDialog() {
    final TextEditingController nameController = TextEditingController(
      text: "${L10n.of(context, 'groceries')} ${DateTime.now().day}/${DateTime.now().month}",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context, 'finish_shopping_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L10n.of(context, 'carry_over_warning')),
            const SizedBox(height: 15),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: L10n.of(context, 'new_list_name_hint')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L10n.of(context, 'cancel'))
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && widget.sessionId != null) {
                final String? newListId = await widget.repository.carryOverToNewList(
                    widget.sessionId!,
                    newName
                );

                if (!mounted) return;

                if (newListId != null) {
                  Navigator.pop(context);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroceryListScreen(
                        repository: widget.repository,
                        sessionId: newListId,
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(L10n.of(context, 'archive_and_carry')),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: "Finish & Carry Over",
          onPressed: _showCarryOverDialog,
        ),
      ],
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

              // 1. Check if there is actually content to show
              final hasNote = item.note != null && item.note!.trim().isNotEmpty;
              final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;
              final hasExtra = hasNote || hasImage;

              // 2. Define shared widgets to keep code clean
              Widget leading = isDiscarded
                  ? const Icon(Icons.delete_sweep, color: Colors.orange)
                  : Checkbox(
                value: item.status == ItemStatus.bought,
                onChanged: (val) {
                  widget.repository.updateItemStatus(
                    item,
                    val! ? ItemStatus.bought : ItemStatus.pending,
                  );
                },
              );

              Widget title = Row(
                children: [
                  Expanded(child: Text(item.name, style: _getItemStyle(item.status))),
                  if (hasExtra)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.info_outline, size: 14, color: Colors.blueAccent),
                    ),
                ],
              );

              Widget trailing = PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditDialog(item);
                  } else {
                    widget.repository.updateItemStatus(item, _statusFromSocketString(value));
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'pending', child: Text(L10n.of(context, 'mark_pending'))),
                  PopupMenuItem(value: 'discarded', child: Text(L10n.of(context, 'discard'))),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'edit', child: Text(L10n.of(context, 'edit'))),
                  PopupMenuItem(
                    onTap: () => widget.repository.deleteItem(item),
                    child: Text(L10n.of(context, 'delete'), style: const TextStyle(color: Colors.red)),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              );

              // 3. Conditional Rendering: Only use ExpansionTile if there is a note or image
              if (!hasExtra) {
                return ListTile(
                  leading: leading,
                  title: title,
                  subtitle: isDiscarded ? Text(L10n.of(context, 'item_discarded'), style: const TextStyle(color: Colors.orange, fontSize: 12)) : null,
                  trailing: trailing,
                );
              }

              return Theme(
                // This removes the default borders that ExpansionTile adds
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: isDiscarded ? Colors.orange.withOpacity(0.05) : null,
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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(item.name, style: _getItemStyle(item.status)),
                      ),
                      if (hasExtra)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.info_outline, size: 14, color: Colors.blueAccent),
                        ),
                    ],
                  ),
                  subtitle: isDiscarded
                      ? Text(L10n.of(context, 'item_discarded'),
                      style: const TextStyle(color: Colors.orange, fontSize: 12))
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(item);
                      } else {
                        widget.repository.updateItemStatus(item, _statusFromSocketString(value));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'pending', child: Text(L10n.of(context, 'mark_pending'))),
                      PopupMenuItem(value: 'discarded', child: Text(L10n.of(context, 'discard'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'edit', child: Text(L10n.of(context, 'edit'))),
                      PopupMenuItem(
                        onTap: () => widget.repository.deleteItem(item),
                        child: Text(L10n.of(context, 'delete'), style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),

                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // Forces children to start on the left
                          children: [
                            if (item.note != null && item.note!.isNotEmpty)
                              Text(
                                item.note!,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                              ),
                            if (item.imagePath != null && item.imagePath!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  // Use the server URL for synced items
                                  '${AppConfig.apiUrl}/${item.imagePath}',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  // Fallback to local file if network fails (useful for offline adds)
                                  errorBuilder: (ctx, err, stack) => Image.file(
                                    File(item.imagePath!),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}