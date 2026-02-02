import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/loan.dart';
import '../../providers.dart';

class LoanRenameDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanRenameDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanRenameDialog> createState() => _LoanRenameDialogState();
}

class _LoanRenameDialogState extends ConsumerState<LoanRenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.loan.name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Loan'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Loan Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_controller.text.isNotEmpty) {
              final storage = ref.read(storageServiceProvider);
              widget.loan.name = _controller.text;
              await storage.saveLoan(widget.loan);
              ref.invalidate(loansProvider);
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
