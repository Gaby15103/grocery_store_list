import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../repositories/grocery_repository.dart';
import '../screens/list_selection_screen.dart';
import '../services/socket_service.dart';
import '../utils/ui_helpers.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final GroceryRepository repository;
  final SocketService socketService;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.repository,
    required this.socketService,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = true,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncData(); // Initial cold-start sync
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncData(); // Sync every time the user returns to the app
    }
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);

    try {
      await widget.repository.initialize();
    } catch (e) {
      debugPrint("Background Sync failed: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- RESTORED ORIGINAL METHODS ---

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isShared = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Group'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Group Name (e.g., Camping Trip)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Share this group'),
                  subtitle: const Text('Syncs with the server for everyone'),
                  value: isShared,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      isShared = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              final email = widget.repository.getUserEmail();

              if (name.isEmpty) {
                UIHelpers.showNotification("Please enter a group name");
                return;
              }
              if (isShared && (email == null || email.isEmpty)) {
                UIHelpers.showNotification("Cannot share group: No account linked.");
                return;
              }

              try {
                await widget.repository.createGroup(name, isShared: isShared);
                if (mounted) Navigator.pop(ctx);
                UIHelpers.showNotification("Group created!", isError: false);
                _syncData();
              } catch (e) {
                UIHelpers.showNotification("Failed to create group: $e");
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void showReceivedInvitationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pending Invitations'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<dynamic>>(
            future: widget.repository.getPendingInvitations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No new invitations", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final invite = snapshot.data![index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(invite['GroupName']),
                    subtitle: Text("From: ${invite['OwnerEmail']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        await widget.repository.acceptInvitation(invite['groupId']);
                        if (mounted) Navigator.pop(ctx);
                        _syncData();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  void _showSendInvitationsDialog(BuildContext context, String activeGroupId) {
    final List<String> selectedEmails = [];
    final TextEditingController manualEmailController = TextEditingController();
    String searchQuery = "";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Invite to Group'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Invite by Email", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: manualEmailController,
                            decoration: const InputDecoration(
                              hintText: "Enter email address...",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () {
                            final val = manualEmailController.text.trim();
                            if (val.contains('@') && !selectedEmails.contains(val)) {
                              setDialogState(() {
                                selectedEmails.add(val);
                                manualEmailController.clear();
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Recent Contacts", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Search recent...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val.toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<String>>(
                      future: widget.repository.getRecentContacts(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        final filtered = snapshot.data!.where((e) => e.toLowerCase().contains(searchQuery)).toList();
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: filtered.isEmpty
                              ? const Center(child: Text("No recent contacts found"))
                              : ListView(
                            children: filtered.map((email) {
                              final isSelected = selectedEmails.contains(email);
                              return CheckboxListTile(
                                title: Text(email, style: const TextStyle(fontSize: 14)),
                                value: isSelected,
                                onChanged: (bool? val) {
                                  setDialogState(() {
                                    val! ? selectedEmails.add(email) : selectedEmails.remove(email);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    if (selectedEmails.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        children: selectedEmails.map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 10)),
                          onDeleted: () => setDialogState(() => selectedEmails.remove(e)),
                        )).toList(),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: selectedEmails.isEmpty ? null : () async {
                    try {
                      for (String email in selectedEmails) await widget.repository.sendInvitation(email, activeGroupId);
                      if (mounted) Navigator.pop(ctx);
                      UIHelpers.showNotification("Invitations sent!", isError: false);
                    } catch (e) {
                      UIHelpers.showNotification("Failed to send: $e");
                    }
                  },
                  child: Text("Invite (${selectedEmails.length})"),
                ),
              ],
            );
          }
      ),
    );
  }

  void _handleShareAction(BuildContext context, GroceryGroup group, String activeGroupId) {
    if (!group.isShared) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Share Group?"),
          content: const Text("To invite people, this group needs to be synced with the server. Make it public?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final email = widget.repository.getUserEmail();
                if (email == null || email.isEmpty) {
                  UIHelpers.showNotification("You must be signed in to share groups.");
                  return;
                }
                await widget.repository.makeGroupPublic(group.id);
                if (mounted) {
                  Navigator.pop(ctx);
                  UIHelpers.showNotification("Group is now public!", isError: false);
                }
              },
              child: const Text("Make Public"),
            ),
          ],
        ),
      );
    } else {
      _showSendInvitationsDialog(context, activeGroupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String activeGroupId = widget.repository.getActiveGroupId();
    final allGroups = widget.repository.getAllGroups();
    final activeGroup = allGroups.firstWhere(
          (g) => g.id == activeGroupId,
      orElse: () => GroceryGroup(id: '', name: 'None'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(activeGroup.id.isNotEmpty ? activeGroup.name : widget.title),
        // SYNC INDICATOR
        bottom: _isSyncing
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
        leading: (widget.showBackButton && Navigator.canPop(context))
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          if (activeGroup.id.isNotEmpty)
            IconButton(
              icon: Icon(activeGroup.isShared ? Icons.person_add : Icons.share, color: activeGroup.isShared ? Colors.blue : null),
              tooltip: activeGroup.isShared ? 'Invite People' : 'Share Group',
              onPressed: () => _handleShareAction(context, activeGroup, activeGroupId),
            ),
          ...?widget.actions,
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('Grocery Master', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
            const Divider(),
            const ListTile(leading: Icon(Icons.group_work), title: Text('Active Group', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: Hive.box<GroceryGroup>('groups').listenable(),
                builder: (context, Box<GroceryGroup> box, _) {
                  final groups = widget.repository.getAllGroups();
                  final effectiveValue = groups.any((g) => g.id == activeGroupId)
                      ? activeGroupId
                      : (groups.isNotEmpty ? groups.first.id : null);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: effectiveValue,
                        hint: const Text("Select Group"),
                        items: groups.map((group) {
                          return DropdownMenuItem<String>(
                            value: group.id,
                            child: Row(
                              children: [
                                Text(group.name),
                                if (group.isShared) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.cloud_queue, size: 16, color: Colors.blue),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            await widget.repository.setActiveGroup(newValue);

                            widget.socketService.joinGroup(newValue);

                            if (mounted) {
                              Navigator.pop(context);
                              Navigator.pushReplacement(context, MaterialPageRoute(
                                builder: (context) => ListSelectionScreen(
                                  repository: widget.repository,
                                  socketService: widget.socketService, // Pass it along
                                  groupId: newValue,
                                ),
                              ));
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.green),
              title: const Text('Create New Group'),
              onTap: () => _showCreateGroupDialog(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.mail_outline, color: Colors.orange),
              title: const Text('Received Invitations'),
              trailing: FutureBuilder<List<dynamic>>(
                future: widget.repository.getPendingInvitations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                  return CircleAvatar(
                    radius: 11, backgroundColor: Colors.red,
                    child: Text('${snapshot.data!.length}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              onTap: () => showReceivedInvitationsDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Force Sync'),
              subtitle: Text('Account: ${widget.repository.getUserEmail() ?? "Not Linked"}'),
              onTap: () { Navigator.pop(context); _syncData(); },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/settings'); },
            ),
          ],
        ),
      ),
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}