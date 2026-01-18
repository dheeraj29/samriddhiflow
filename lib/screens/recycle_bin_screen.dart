import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/transaction.dart';
import '../widgets/pure_icons.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Recycle Bin')),
      body: FutureBuilder<List<Transaction>>(
        future: Future.value(storage.getDeletedTransactions()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deleted = snapshot.data!;
          if (deleted.isEmpty) {
            return const Center(child: Text('Recycle Bin is empty'));
          }

          return ListView.builder(
            itemCount: deleted.length,
            itemBuilder: (context, index) {
              final txn = deleted[index];
              return ListTile(
                title: Text(txn.title,
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: PureIcons.restore(color: Colors.green),
                      tooltip: 'Restore',
                      onPressed: () async {
                        await storage.restoreTransaction(txn.id);
                        final _ = ref.refresh(transactionsProvider);
                        final __ = ref
                            .refresh(accountsProvider); // Also refresh accounts
                        setState(() {}); // Rebuild to remove item from list
                      },
                    ),
                    IconButton(
                      icon: PureIcons.deleteForever(color: Colors.red),
                      tooltip: 'Delete Permanently',
                      onPressed: () async {
                        await storage.permanentlyDeleteTransaction(txn.id);
                        setState(() {});
                      },
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
