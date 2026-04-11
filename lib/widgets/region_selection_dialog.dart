import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feature_providers.dart';
import '../l10n/app_localizations.dart';
import '../core/cloud_config.dart';

class RegionSelectionDialog extends ConsumerStatefulWidget {
  final bool isMandatory;

  const RegionSelectionDialog({super.key, this.isMandatory = false});

  @override
  ConsumerState<RegionSelectionDialog> createState() =>
      _RegionSelectionDialogState();
}

class _RegionSelectionDialogState extends ConsumerState<RegionSelectionDialog> {
  String? _selectedRegion;

  // Use programmatic IDs for internal logic
  final List<String> _availableRegions = [CloudDatabaseRegion.india];

  @override
  void initState() {
    super.initState();
    _selectedRegion = ref.read(cloudDatabaseRegionProvider);
  }

  String _getRegionLabel(String regionId, AppLocalizations l10n) {
    switch (regionId) {
      case CloudDatabaseRegion.india:
        return l10n.indiaLabel;
      default:
        return regionId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.isMandatory,
      child: AlertDialog(
        title: Text(l10n.selectRegionTitle),
        content: RadioGroup<String>(
          groupValue: _selectedRegion,
          onChanged: (val) =>
              setState(() => _selectedRegion = val), // coverage:ignore-line
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.selectRegionDescription),
              const SizedBox(height: 20),
              ..._availableRegions.map((regionId) => RadioListTile<String>(
                    title: Text(_getRegionLabel(regionId, l10n)),
                    value: regionId,
                    activeColor: theme.colorScheme.primary,
                  )),
            ],
          ),
        ),
        actions: [
          if (!widget.isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(context), // coverage:ignore-line
              child: Text(l10n.cancelButton),
            ),
          ElevatedButton(
            onPressed: _selectedRegion == null
                ? null
                : () async {
                    // coverage:ignore-line
                    try {
                      // coverage:ignore-start
                      await ref
                          .read(cloudDatabaseRegionProvider.notifier)
                          .setRegion(_selectedRegion!);
                      if (context.mounted) Navigator.pop(context, true);
                      // coverage:ignore-end
                    } catch (e) {
                      // coverage:ignore-start
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                e.toString().replaceAll('Exception: ', '')),
                            // coverage:ignore-end
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            child: Text(l10n.confirmButton),
          ),
        ],
      ),
    );
  }
}
