import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/group.dart';
import '../widgets/main_layout.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../utils/ui_helpers.dart';
import '../utils/l10n.dart';
import 'list_selection_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _launchRecipeSite() async {
    final Uri url = Uri.parse('https://recipes.gaby15103.org/recipes');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      UIHelpers.showNotification("Error: Could not launch recipe site");
    }
  }

  void _showInvitations(BuildContext context) {
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      UIHelpers.showNotification(L10n.of(context, 'no_account'));
      return;
    }
    auth.refreshSocialData();
  }

  @override
  Widget build(BuildContext context) {
    final groupCtrl = context.watch<GroupController>();
    final authCtrl = context.watch<AuthController>();

    return MainLayout(
      title: L10n.of(context, 'dashboard'),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${L10n.of(context, 'welcome')} ${authCtrl.userProfile?.firstName ?? L10n.of(context, 'chef_fallback')}",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(L10n.of(context, 'kitchen_status')),
                ],
              ),
            ),
          ),
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
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: groupCtrl.groups.take(5).length,
                itemBuilder: (context, index) => _buildRecentCard(context, groupCtrl.groups[index], groupCtrl),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatusBanner(context, authCtrl),
            ),
          ),

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

  Widget _buildRecentCard(BuildContext context, GroceryGroup group, GroupController groupCtrl) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: () async {
          await groupCtrl.changeActiveGroup(group.id);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListSelectionView(groupId: group.id),
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
              Text(group.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(L10n.of(context, 'active_group_label'),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, AuthController auth) {
    final bool isOnline = auth.isLoggedIn;
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