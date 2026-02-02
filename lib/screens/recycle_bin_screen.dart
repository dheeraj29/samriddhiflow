import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/transaction.dart';
import '../widgets/pure_icons.dart';

import '../widgets/transaction_list_item.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final accounts = ref.watch(accountsProvider).value ?? [];
    final categories = ref.watch(categoriesProvider);

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
              return TransactionListItem(
                txn: txn,
                currencyLocale: currencyLocale,
                accounts: accounts,
                categories: categories,
                showLineThrough: true,
                onTap: () {}, // No action on tap in recycle bin for now
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: PureIcons.restore(color: Colors.green),
                      tooltip: 'Restore',
                      onPressed: () async {
                        await storage.restoreTransaction(txn.id);
                        ref.invalidate(transactionsProvider);
                        ref.invalidate(accountsProvider);
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
