import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/profile.dart';
import '../widgets/pure_icons.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Manage Profiles')),
      body: profilesAsync.when(
        data: (profiles) => ListView.builder(
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final p = profiles[index];
            final isActive = p.id == activeProfileId;

            return ListTile(
              title: Text(p.name,
                  style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal)),
              subtitle:
                  Text('${p.currencyLocale} | Budget: ${p.monthlyBudget}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: PureIcons.copy(),
                    tooltip: 'Copy Categories from another profile',
                    onPressed: () =>
                        _showCopyCategoriesDialog(context, ref, p.id),
                  ),
                  if (!isActive)
                    IconButton(
                      icon: PureIcons.delete(color: Colors.grey),
                      onPressed: () async {
                        // In a real app, maybe don't allow delete if active or has data
                        // For now, let's just make it simple
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Profile?'),
                            content: const Text(
                                'This will permanently delete this profile and ALL associated data (accounts, transactions, loans, etc.). This action cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final storage = ref.read(storageServiceProvider);
                          await storage.deleteProfile(p.id);
                          ref.invalidate(profilesProvider);
                          ref.invalidate(activeProfileIdProvider);
                          ref.invalidate(accountsProvider);
                          ref.invalidate(transactionsProvider);
                          ref.invalidate(loansProvider);
                          ref.invalidate(recurringTransactionsProvider);
                          ref.invalidate(categoriesProvider);
                        }
                      },
                    ),
                  if (isActive) PureIcons.checkCircle(color: Colors.green),
                ],
              ),
              onTap: () async {
                await ref
                    .read(activeProfileIdProvider.notifier)
                    .setProfile(p.id);
                // Refresh others
                ref.invalidate(accountsProvider);
                ref.invalidate(transactionsProvider);
                ref.invalidate(loansProvider);
                ref.invalidate(recurringTransactionsProvider);
                ref.invalidate(categoriesProvider);
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProfileDialog(context, ref),
        child: PureIcons.add(),
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Profile Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final storage = ref.read(storageServiceProvider);
                final newProfile = Profile.create(name: nameController.text);
                await storage.saveProfile(newProfile);
                ref.invalidate(profilesProvider);
                Navigator.pop(c);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCopyCategoriesDialog(
      BuildContext context, WidgetRef ref, String targetProfileId) {
    final profilesAsync = ref.read(profilesProvider);
    profilesAsync.whenData((profiles) {
      final otherProfiles =
          profiles.where((p) => p.id != targetProfileId).toList();
      if (otherProfiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other profiles to copy from.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Copy Categories'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: otherProfiles
                  .map((p) => ListTile(
                        title: Text(p.name),
                        onTap: () async {
                          final storage = ref.read(storageServiceProvider);
                          await storage.copyCategories(p.id, targetProfileId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Categories copied to ${profiles.firstWhere((pr) => pr.id == targetProfileId).name}')),
                          );
                          Navigator.pop(c);
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Close')),
          ],
        ),
      );
    });
  }
}
