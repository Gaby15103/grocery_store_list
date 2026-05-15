import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../controllers/list_controller.dart';
import '../models/item.dart';
import '../widgets/main_layout.dart';
import '../utils/l10n.dart';
import '../controllers/item_controller.dart';
import '../controllers/group_controller.dart';

class GroceryListView extends StatefulWidget {
  final String? sessionId;

  const GroceryListView({super.key, this.sessionId});

  @override
  State<GroceryListView> createState() => _GroceryListViewState();
}

class _GroceryListViewState extends State<GroceryListView> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  ItemController? _itemController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _itemController = Provider.of<ItemController>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();

    if (widget.sessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final groupCtrl = context.read<GroupController>();
        final itemCtrl = context.read<ItemController>();

        final String effectiveGroupId = groupCtrl.activeGroupId ?? 'default';

        itemCtrl.setOpenedList(widget.sessionId!);

        itemCtrl.loadItems(widget.sessionId!, effectiveGroupId).then((_) {
          itemCtrl.applySort();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    _itemController?.setOpenedList(null);
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, Function setDialogState) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 50);
      if (image != null) {
        setDialogState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _handleSave() async {
    if (_controller.text.trim().isEmpty || widget.sessionId == null) {
      return;
    }

    final itemCtrl = context.read<ItemController>();
    final groupCtrl = context.read<GroupController>();

    try {
      final String effectiveGroupId = groupCtrl.activeGroupId ?? 'default';

      await itemCtrl.addItem(
        name: _controller.text.trim(),
        listId: widget.sessionId!,
        groupId: effectiveGroupId,
        note: _noteController.text.trim(),
        imageFile: _selectedImage,
      );

      _controller.clear();
      _noteController.clear();

      setState(() => _selectedImage = null);

      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("❌ Error adding item to group: $e");
    }
  }

  void _showAddDialog() {
    _selectedImage = null;
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
                    IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(ImageSource.camera, setDialogState)),
                    IconButton(icon: const Icon(Icons.photo_library), onPressed: () => _pickImage(ImageSource.gallery, setDialogState)),
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
                TextField(controller: _controller, decoration: InputDecoration(hintText: L10n.of(context, 'item_hint'))),
                TextField(controller: _noteController, decoration: InputDecoration(hintText: L10n.of(context, 'note_hint'))),
                const SizedBox(height: 15),
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
                      IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setDialogState(() => clearImage = true)),
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
                        }),
                    IconButton(
                        icon: const Icon(Icons.photo_library),
                        onPressed: () async {
                          final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                          if (image != null) setDialogState(() { editImage = File(image.path); clearImage = false; });
                        }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context, 'cancel'))),
            ElevatedButton(
              onPressed: () async {
                await context.read<ItemController>().updateItemDetails(
                  item: item,
                  newName: _controller.text,
                  newNote: _noteController.text,
                  newImageFile: editImage,
                  shouldClearImage: clearImage,
                  groupId: context.read<GroupController>().activeGroupId,
                );
                _controller.clear();
                _noteController.clear();

                setState(() => _selectedImage = null);
                if (mounted) Navigator.pop(context);
              },
              child: Text(L10n.of(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveDialog() {
    final itemCtrl = context.read<ItemController>();
    final listCtrl = context.read<ListController>();
    final groupCtrl = context.read<GroupController>();

    final boughtCount = itemCtrl.currentItems.where((i) => i.status == ItemStatus.bought).length;
    final pendingCount = itemCtrl.currentItems.where((i) => i.status == ItemStatus.pending).length;
    
    final dateStr = "${DateTime.now().day}/${DateTime.now().month}";
    final defaultName = "${L10n.of(context, 'list_cont') ?? "List"} $dateStr";

    final TextEditingController nameController = TextEditingController(text: defaultName);

    String contentText = L10n.of(context, 'archive_content') ??
        "Archiving will move {bought} items to history.\n{pending} items will carry over to a new list.";

    contentText = contentText
        .replaceAll('{bought}', boughtCount.toString())
        .replaceAll('{pending}', pendingCount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context, 'archive_title') ?? "Finish Shopping?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contentText),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: L10n.of(context, 'new_list_name_hint') ?? "New list name",
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L10n.of(context, 'cancel') ?? "Cancel")
          ),
          ElevatedButton(
            onPressed: () async {
              final chosenName = nameController.text.trim();
              final finalName = chosenName.isNotEmpty ? chosenName : defaultName;

              Navigator.pop(ctx);

              final isShared = groupCtrl.isCurrentGroupShared;
              final groupId = groupCtrl.activeGroupId ?? 'default';

              try {
                await listCtrl.archiveList(widget.sessionId!, finalName, groupId, isShared);

                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroceryListView(sessionId: listCtrl.currentListId),
                    ),
                  );
                }
              } catch (e) {
                final errorPrefix = L10n.of(context, 'archive_failed') ?? "Failed to archive";
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$errorPrefix: $e"))
                );
              }
            },
            child: Text(L10n.of(context, 'archive_confirm') ?? "Archive"),
          ),
        ],
      ),
    );
  }

  TextStyle _getItemStyle(ItemStatus status) {
    if (status == ItemStatus.bought) {
      return const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 16);
    } else if (status == ItemStatus.discarded) {
      return const TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, decoration: TextDecoration.lineThrough, fontSize: 16);
    }
    return const TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
  }

  @override
  Widget build(BuildContext context) {
    final itemCtrl = context.watch<ItemController>();
    final groupCtrl = context.watch<GroupController>();

    if (widget.sessionId == null) {
      return MainLayout(
          title: 'Error',
          child: Center(child: Text(L10n.of(context, 'error_no_list')))
      );
    }

    final String effectiveGroupId = groupCtrl.activeGroupId ?? 'default';

    return MainLayout(
      title: L10n.of(context, 'items_title'),
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () => _showSortBottomSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: "Finish & Carry Over",
          onPressed: _showArchiveDialog,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_shopping_cart),
      ),
      child: Column(
        children: [
          if (itemCtrl.isLoading)
            const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: itemCtrl.currentItems.isEmpty && itemCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildItemList(itemCtrl, effectiveGroupId),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    final itemCtrl = context.read<ItemController>();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(L10n.of(context, 'inverse_order')),
              value: itemCtrl.isInverse,
              onChanged: (val) {
                itemCtrl.setSort(itemCtrl.currentSort, inverse: val);
                setSheetState(() {});
              },
            ),
            const Divider(),
            _sortTile(ctx, itemCtrl, ItemSortType.alphabetical, Icons.sort_by_alpha, L10n.of(context, 'alphabetical')),
            _sortTile(ctx, itemCtrl, ItemSortType.created, Icons.calendar_today, L10n.of(context, 'date_created')),
            _sortTile(ctx, itemCtrl, ItemSortType.hasNote, Icons.note, L10n.of(context, 'items_with_notes')),
            _sortTile(ctx, itemCtrl, ItemSortType.hasImage, Icons.image, L10n.of(context, 'items_with_images')),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext context, ItemController ctrl, ItemSortType type, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: ctrl.currentSort == type ? Colors.blue : null),
      title: Text(label),
      trailing: ctrl.currentSort == type ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        ctrl.setSort(type);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildItemList(ItemController itemCtrl, String groupId) {
    final items = itemCtrl.currentItems;

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
        final hasExtra = (item.note?.isNotEmpty ?? false) || (item.imagePath?.isNotEmpty ?? false);

        if (!hasExtra) {
          return ListTile(
            leading: _buildLeading(item, itemCtrl, groupId),
            title: Row(
              children: [
                Flexible(child: Text(item.name, style: _getItemStyle(item.status), overflow: TextOverflow.ellipsis)),
                if (item.note?.isNotEmpty ?? false)
                  const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.info_outline, size: 16, color: Colors.blueGrey)),
                if (item.imagePath?.isNotEmpty ?? false)
                  const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.image_outlined, size: 16, color: Colors.blueGrey)),
              ],
            ),
            subtitle: isDiscarded ? Text(L10n.of(context, 'item_discarded'), style: const TextStyle(color: Colors.orange, fontSize: 12)) : null,
            trailing: _buildTrailing(item, itemCtrl, groupId),
          );
        }

        return _buildExpansionTile(item, itemCtrl, groupId, isDiscarded);
      },
    );
  }

  Widget _buildLeading(GroceryItem item, ItemController itemCtrl, String groupId) {
    if (item.id == -1) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (item.status == ItemStatus.discarded) return const Icon(Icons.delete_sweep, color: Colors.orange);

    return Checkbox(
      value: item.status == ItemStatus.bought,
      onChanged: (_) => itemCtrl.toggleStatus(item, groupId),
    );
  }

  Widget _buildTrailing(GroceryItem item, ItemController itemCtrl, String groupId) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'edit') {
          _showEditDialog(item);
        } else {
          itemCtrl.toggleStatus(item, groupId, forceStatus: val);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'pending', child: Text(L10n.of(context, 'mark_pending'))),
        PopupMenuItem(value: 'discarded', child: Text(L10n.of(context, 'discard'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'edit', child: Text(L10n.of(context, 'edit'))),
        PopupMenuItem(onTap: () => itemCtrl.removeItem(item, groupId), child: Text(L10n.of(context, 'delete'), style: const TextStyle(color: Colors.red))),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Widget _buildExpansionTile(GroceryItem item, ItemController itemCtrl, String groupId, bool isDiscarded) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: _buildLeading(item, itemCtrl, groupId),
        title: Row(
          children: [
            Flexible(child: Text(item.name, style: _getItemStyle(item.status), overflow: TextOverflow.ellipsis)),
            if (item.note?.isNotEmpty ?? false)
              const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.info_outline, size: 16, color: Colors.blueGrey)),
            if (item.imagePath?.isNotEmpty ?? false)
              const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.image_outlined, size: 16, color: Colors.blueGrey)),
          ],
        ),
        trailing: _buildTrailing(item, itemCtrl, groupId),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.note?.isNotEmpty ?? false)
                  Text(item.note!, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                if (item.imagePath?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildItemImage(item.imagePath!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String path) {
    final bool isNetwork = path.startsWith('http') || !path.startsWith('/');

    if (isNetwork) {
      final String fullUrl = path.startsWith('http')
          ? path
          : '${AppConfig.apiUrl}/$path';

      return Image.network(
        fullUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
      );
    } else {
      return Image.file(
        File(path),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
      );
    }
  }
}