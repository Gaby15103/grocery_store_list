import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../widgets/main_layout.dart';
import '../repositories/grocery_repository.dart';
import '../models/group.dart';
import '../screens/grocery_list_screen.dart';

class HomeScreen extends StatelessWidget {
  final GroceryRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Dashboard",
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
                  String displayName = "Chef";

                  if (snapshot.hasData) {
                    final user = snapshot.data!;
                    displayName = "${user.firstName} ${user.lastName}";
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bonjour, $displayName",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SizedBox(height: 4, child: LinearProgressIndicator(minHeight: 2))
                      else
                        const Text("Here is what's happening in your kitchen."),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Recent Lists (Horizontal Carousel)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("Recently Used", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _buildRecentCard(context, group);
                    },
                  );
                },
              ),
            ),
          ),

          // 3. System Status (Server vs Local)
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatusBanner(context),
            ),
          ),

          // 4. Quick Actions / Categories
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text("Quick Access", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                _buildActionCard(context, "All Recipes", Icons.menu_book, Colors.orange, () {}),
                _buildActionCard(context, "Shopping", Icons.shopping_bag, Colors.green, () {}),
                _buildActionCard(context, "Invitations", Icons.mail, Colors.blue, () {}),
                _buildActionCard(context, "Sync Logs", Icons.terminal, Colors.grey, () {}),
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
          // Navigate to your list selection or specific list
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
              const Text("Last updated: 2h", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    bool isOnline = repository.getUserEmail() != null;
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
                Text(isOnline ? "Server Connected" : "Local Mode", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(isOnline ? "Syncing to gab-server" : "Changes saved locally in Hive", style: const TextStyle(fontSize: 12)),
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