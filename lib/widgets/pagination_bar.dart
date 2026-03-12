import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  final int safeCurrentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.safeCurrentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $safeCurrentPage of $totalPages',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: safeCurrentPage > 1
                    ? () => onPageChanged(
                        safeCurrentPage - 1) // coverage:ignore-line
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: safeCurrentPage < totalPages
                    ? () => onPageChanged(safeCurrentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
