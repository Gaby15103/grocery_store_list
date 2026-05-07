import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/socket_service.dart';
import '../utils/ui_helpers.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../views/list_selection_view.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<GroupController>().loadGroups();
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final groupCtrl = context.read<GroupController>();
    final authCtrl = context.read<AuthController>();
    bool isShared = false;

    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Create New Group'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Group Name (e.g., Camping Trip)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('Share this group'),
                      value: isShared,
                      onChanged: (val) =>
                          setDialogState(() => isShared = val ?? false),
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  if (isShared && !authCtrl.isLoggedIn) {
                    UIHelpers.showNotification(
                        "Login required to share groups.");
                    return;
                  }

                  try {
                    await groupCtrl.createGroup(
                        name);
                    if (mounted) Navigator.pop(ctx);
                    UIHelpers.showNotification(
                        "Group created!", isError: false);
                  } catch (e) {
                    UIHelpers.showNotification("Error: $e");
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void showReceivedInvitationsDialog(BuildContext context) {
    final authCtrl = context.read<AuthController>();
    final groupCtrl = context.read<GroupController>();

    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Pending Invitations'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: authCtrl.pendingInvites.length,
                itemBuilder: (context, index) {
                  final invite = authCtrl.pendingInvites[index];
                  return ListTile(
                    title: Text(invite['GroupName']),
                    subtitle: Text("From: ${invite['OwnerEmail']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        await authCtrl.acceptGroupInvitation(invite['groupId']);
                        await groupCtrl
                            .loadGroups(); // Refresh groups to see the new one
                        if (mounted) Navigator.pop(ctx);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  void _showSendInvitationsDialog(BuildContext context, String activeGroupId) {
    final List<String> selectedEmails = [];
    final TextEditingController manualEmailController = TextEditingController();
    String searchQuery = "";

    final authCtrl = context.read<AuthController>();

    showDialog(
      context: context,
      builder: (ctx) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Invite to Group'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Invite by Email",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: manualEmailController,
                              decoration: const InputDecoration(
                                hintText: "Enter email address...",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors
                                .blue),
                            onPressed: () {
                              final val = manualEmailController.text.trim();
                              if (val.contains('@') &&
                                  !selectedEmails.contains(val)) {
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
                      const Text("Recent Contacts",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: "Search recent...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) =>
                            setDialogState(() =>
                            searchQuery = val.toLowerCase()),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8)),
                        child: authCtrl.recentContacts.isEmpty
                            ? const Center(child: Text("No recent contacts"))
                            : ListView(
                          children: authCtrl.recentContacts
                              .where((e) =>
                              e.toLowerCase().contains(searchQuery))
                              .map((email) {
                            final isSelected = selectedEmails.contains(email);
                            return CheckboxListTile(
                              title: Text(
                                  email, style: const TextStyle(fontSize: 14)),
                              value: isSelected,
                              onChanged: (bool? val) {
                                setDialogState(() {
                                  val!
                                      ? selectedEmails.add(email)
                                      : selectedEmails.remove(email);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      if (selectedEmails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Selected to Invite:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0, // Gap between chips
                          runSpacing: 4.0, // Gap between lines
                          children: selectedEmails.map((email) {
                            return InputChip(
                              label: Text(
                                email,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () {
                                // Remove from the list when the 'X' is clicked
                                setDialogState(() {
                                  selectedEmails.remove(email);
                                });
                              },
                              deleteIconColor: Colors.redAccent,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: selectedEmails.isEmpty ? null : () async {
                      try {
                        for (String email in selectedEmails) {
                          await authCtrl.sendInvitation(activeGroupId, email);
                        }
                        if (mounted) Navigator.pop(ctx);
                        UIHelpers.showNotification(
                            "Invitations sent!", isError: false);
                      } catch (e) {
                        UIHelpers.showNotification("Failed to send: $e");
                      }
                    },
                    child: Text("Invite (${selectedEmails.length})"),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _handleShareAction(BuildContext context, GroceryGroup group,
      String activeGroupId) {
    final authCtrl = context.read<AuthController>();
    final groupCtrl = context.read<GroupController>();

    if (!group.isShared) {
      showDialog(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: const Text("Share Group?"),
              content: const Text(
                  "To invite people, this group needs to be synced with the server. Make it public?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (!authCtrl.isLoggedIn) {
                      UIHelpers.showNotification(
                          "You must be signed in to share groups.");
                      return;
                    }

                    try {
                      // This replaces repository.makeGroupPublic
                      // You'll need to add a makeGroupPublic method to your GroupController!
                      await groupCtrl.makeGroupPublic(group.id);

                      if (mounted) {
                        Navigator.pop(ctx);
                        UIHelpers.showNotification(
                            "Group is now public!", isError: false);
                      }
                    } catch (e) {
                      UIHelpers.showNotification("Error: $e");
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
    final groupCtrl = context.watch<GroupController>();
    final authCtrl = context.watch<AuthController>();

    final activeGroup = groupCtrl.groups.firstWhere(
          (g) => g.id == groupCtrl.activeGroupId,
      orElse: () => GroceryGroup(id: '', name: 'None'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            activeGroup.id.isNotEmpty ? activeGroup.name : widget.title),
        bottom: groupCtrl.isLoading
            ? const PreferredSize(
            preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
        leading: (widget.showBackButton && Navigator.canPop(context))
            ? IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          if (activeGroup.id.isNotEmpty)
            IconButton(
              icon: Icon(activeGroup.isShared ? Icons.person_add : Icons.share,
                  color: activeGroup.isShared ? Colors.blue : null),
              tooltip: activeGroup.isShared ? 'Invite People' : 'Share Group',
              onPressed: () =>
                  _handleShareAction(
                      context, activeGroup, groupCtrl.activeGroupId!),
            ),
          ...?widget.actions,
        ],
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme
                  .of(context)
                  .colorScheme
                  .primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.shopping_cart_checkout, color: Colors.white,
                      size: 40),
                  const SizedBox(height: 10),
                  const Text('Grocery Master',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                  if (authCtrl.isLoggedIn)
                    Text(authCtrl.userProfile?.email ?? "",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context); // Ferme le drawer
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
              },
            ),

            const Divider(),
            const ListTile(
                leading: Icon(Icons.group_work),
                title: Text('Active Group',
                    style: TextStyle(fontWeight: FontWeight.bold))
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: activeGroup.id.isNotEmpty ? activeGroup.id : null,
                    hint: const Text("Select Group"),
                    items: groupCtrl.groups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group.id,
                        child: Row(
                          children: [
                            Text(group.name),
                            if (group.isShared) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.cloud_queue, size: 16,
                                  color: Colors.blue),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        await groupCtrl.changeActiveGroup(newValue);
                        if (mounted) {
                          Navigator.pop(context);
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) =>
                                ListSelectionView(groupId: newValue),
                          ));
                        }
                      }
                    },
                  ),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(
                  Icons.add_circle_outline, color: Colors.green),
              title: const Text('Create New Group'),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog(context);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.mail_outline, color: Colors.orange),
              title: const Text('Received Invitations'),
              trailing: authCtrl.pendingInvites.isNotEmpty
                  ? CircleAvatar(
                radius: 11,
                backgroundColor: Colors.red,
                child: Text('${authCtrl.pendingInvites.length}',
                    style: const TextStyle(fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              )
                  : null,
              onTap: () {
                Navigator.pop(context);
                showReceivedInvitationsDialog(context);
              },
            ),

            // 5. FORCE SYNC
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Force Sync'),
              subtitle: Text(
                  'Account: ${authCtrl.userProfile?.email ?? "Not Linked"}'),
              onTap: () {
                Navigator.pop(context);
                groupCtrl.loadGroups(); // Trigger reload global
              },
            ),

            // 6. SETTINGS
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}