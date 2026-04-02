import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.renameLoanTitle),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.loanNameLabel),
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        ElevatedButton(
          onPressed: () async {
            if (_controller.text.isNotEmpty) {
              final storage = ref.read(storageServiceProvider);
              widget.loan.name = _controller.text;
              await storage.saveLoan(widget.loan);
              ref.invalidate(loansProvider);
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: Text(AppLocalizations.of(context)!.saveButton),
        ),
      ],
    );
  }
}
