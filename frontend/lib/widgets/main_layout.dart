import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../repositories/grocery_repository.dart';
import '../screens/sessions_screen.dart';
import '../screens/list_selection_screen.dart';
import '../utils/ui_helpers.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final GroceryRepository repository;
  final List<Widget>? actions;
  final Widget? floatingActionButton;


  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.repository,
    this.actions,
    this.floatingActionButton,
  });


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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              final email = repository.getUserEmail();

              if (name.isEmpty) {
                UIHelpers.showNotification("Please enter a group name");
                return;
              }

              // Check if user is "connected" before allowing a shared group
              if (isShared && (email == null || email.isEmpty)) {
                UIHelpers.showNotification("Cannot share group: No account linked.");
                return;
              }

              try {
                await repository.createGroup(name, isShared: isShared);
                if (context.mounted) Navigator.pop(ctx);
                UIHelpers.showNotification("Group created!", isError: false);
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

  void _showInvitationsDialog(BuildContext context, String activeGroupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group Invitations'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Pending Invites", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              FutureBuilder<List<dynamic>>(
                future: repository.getPendingInvitations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No new invitations", style: TextStyle(color: Colors.grey));
                  }
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final invite = snapshot.data![index];
                        return ListTile(
                          title: Text(invite['GroupName']),
                          subtitle: Text("From: ${invite['OwnerEmail']}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () async {
                              await repository.acceptInvitation(invite['groupId']);
                              if (context.mounted) Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const Divider(),
              const Text("Send Invitation", style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                decoration: const InputDecoration(hintText: "Enter friend's email"),
                onSubmitted: (email, ) async {
                  try {
                    // Pass the active group ID as the second argument
                    await repository.sendInvitation(email, activeGroupId);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      UIHelpers.showNotification("Invite sent to $email", isError: false);
                    }
                  } catch (e) {
                    UIHelpers.showNotification("Failed to send invite: $e");
                  }
                },
              ),
            ],
          ),
        ),
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
                final email = repository.getUserEmail();
                if (email == null || email.isEmpty) {
                  UIHelpers.showNotification("You must be signed in to share groups.");
                  return;
                }

                await repository.makeGroupPublic(group.id);
                if (context.mounted) {
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
      _showInvitationsDialog(context, activeGroupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String activeGroupId = repository.getActiveGroupId();
    final activeGroup = repository.getAllGroups().firstWhere(
          (g) => g.id == activeGroupId,
      orElse: () => GroceryGroup(id: '', name: 'None'),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(activeGroup.name ?? title),
        actions: [
          if (activeGroup.id.isNotEmpty)
            IconButton(
              icon: Icon(
                activeGroup.isShared ? Icons.person_add : Icons.share,
                color: activeGroup.isShared ? Colors.blue : null,
              ),
              tooltip: activeGroup.isShared ? 'Invite People' : 'Share Group',
              onPressed: () => _handleShareAction(context, activeGroup, activeGroupId),
            ),
          ...?actions, // Keep your other actions
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Grocery Master',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            // Dynamic Group Selection
            const ListTile(
              leading: Icon(Icons.group_work),
              title: Text('Active Group', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: Hive.box<GroceryGroup>('groups').listenable(),
                builder: (context, Box<GroceryGroup> box, _) {
                  final groups = repository.getAllGroups();

                  // Ensure activeGroupId exists in the list to avoid dropdown errors
                  final effectiveValue = groups.any((g) => g.id == activeGroupId)
                      ? activeGroupId
                      : (groups.isNotEmpty ? groups.first.id : null);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
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
                            await repository.setActiveGroup(newValue);
                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListSelectionScreen(
                                    repository: repository,
                                    groupId: newValue,
                                  ),
                                ),
                              );
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
              title: const Text('Invitations'),
              trailing: FutureBuilder<List<dynamic>>(
                future: repository.getPendingInvitations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final count = snapshot.data!.length;

                  return CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.red,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  );
                },
              ),
              onTap: () => _showInvitationsDialog(context, activeGroupId),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Force Sync'),
              subtitle: Text('Account: ${repository.getUserEmail() ?? "Not Linked"}'),
              onTap: () async {
                try {
                  await repository.initialize();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync successful!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sync failed: $e')),
                    );
                  }
                }
              },
            ),
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
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}