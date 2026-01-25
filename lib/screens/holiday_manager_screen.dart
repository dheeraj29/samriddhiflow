import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../widgets/pure_icons.dart';

class HolidayManagerScreen extends ConsumerWidget {
  const HolidayManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider)..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Manager'),
        actions: [
          IconButton(
            icon: PureIcons.add(),
            onPressed: () => _showAddHolidayDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                PureIcons.info(color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Recurring transactions can be configured to avoid these dates by scheduling them a day earlier.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: holidays.isEmpty
                ? const Center(child: Text('No holidays added yet.'))
                : ListView.builder(
                    itemCount: holidays.length,
                    itemBuilder: (context, index) {
                      final date = holidays[index];
                      return ListTile(
                        leading: PureIcons.calendar(color: Colors.orange),
                        title: Text(DateFormat('MMMM dd, yyyy').format(date)),
                        subtitle: Text(DateFormat('EEEE').format(date)),
                        trailing: IconButton(
                          icon: PureIcons.deleteOutlined(color: Colors.red),
                          onPressed: () => ref
                              .read(holidaysProvider.notifier)
                              .removeHoliday(date),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddHolidayDialog(
      BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      await ref.read(holidaysProvider.notifier).addHoliday(picked);
    }
  }
}
