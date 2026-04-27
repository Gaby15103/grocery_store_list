import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../widgets/main_layout.dart';
import '../repositories/grocery_repository.dart';
import '../models/group.dart';
import '../utils/ui_helpers.dart';
import '../utils/l10n.dart'; // Ensure this utility exists
import 'list_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  final GroceryRepository repository;

  const HomeScreen({super.key, required this.repository});

  Future<void> _launchRecipeSite() async {
    final Uri url = Uri.parse('https://recipes.gaby15103.org/recipes');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      UIHelpers.showNotification("Error: Could not launch recipe site");
    }
  }

  void _showInvitations(BuildContext context) {
    if (repository.getUserEmail() == null) {
      UIHelpers.showNotification(L10n.of(context, 'no_account'));
      return;
    }
    MainLayout(
      repository: repository,
      title: L10n.of(context, 'invitations'),
      child: const SizedBox(),
    ).showReceivedInvitationsDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: L10n.of(context, 'dashboard'),
      repository: repository,
      child: CustomScrollView(
        slivers: [
          // 1. Welcome Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<User>(
                future: repository.getCurrentUser(),
                builder: (context, snapshot) {
                  String displayName = snapshot.hasData
                      ? "${snapshot.data!.firstName} ${snapshot.data!.lastName}"
                      : L10n.of(context, 'chef_fallback');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${L10n.of(context, 'welcome')} $displayName",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(L10n.of(context, 'kitchen_status')),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Recent Groups Carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                L10n.of(context, 'recent'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ValueListenableBuilder(
                valueListenable: Hive.box<GroceryGroup>('groups').listenable(),
                builder: (context, Box<GroceryGroup> box, _) {
                  final groups = repository.getAllGroups().take(5).toList();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: groups.length,
                    itemBuilder: (context, index) => _buildRecentCard(context, groups[index]),
                  );
                },
              ),
            ),
          ),

          // 3. System Status
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatusBanner(context),
            ),
          ),

          // 4. Functional Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                L10n.of(context, 'quick_access'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  L10n.of(context, 'recipes'),
                  Icons.menu_book,
                  Colors.orange,
                  _launchRecipeSite,
                ),
                _buildActionCard(
                  context,
                  L10n.of(context, 'invitations'),
                  Icons.mail,
                  Colors.blue,
                      () => _showInvitations(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, GroceryGroup group) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: () async {
          await repository.setActiveGroup(group.id);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListSelectionScreen(repository: repository, groupId: group.id),
              ),
            );
          }
        },
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(group.isShared ? Icons.cloud : Icons.home,
                  color: group.isShared ? Colors.blue : Colors.green, size: 20),
              Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(L10n.of(context, 'active_group_label'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final bool isOnline = repository.getUserEmail() != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOnline ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOnline ? Colors.blue : Colors.orange),
      ),
      child: Row(
        children: [
          Icon(isOnline ? Icons.check_circle : Icons.warning, color: isOnline ? Colors.blue : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? L10n.of(context, 'status_online') : L10n.of(context, 'status_offline'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isOnline ? L10n.of(context, 'sync_info') : L10n.of(context, 'sync_disabled'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}