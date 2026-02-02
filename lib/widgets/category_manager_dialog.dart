import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../providers.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final TextEditingController _controller = TextEditingController();
  CategoryUsage _usage = CategoryUsage.expense;
  CategoryTag _tag = CategoryTag.none;
  int _iconCode = 0xe5c7;
  String? _editingCategoryId;
  final ScrollController _iconScrollController = ScrollController();

  @override
  void dispose() {
    _iconScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  final List<int> _iconOptions = [
    0xe332,
    0xea68,
    0xea14,
    0xef92,
    0xef97,
    0xef63,
    0xe6ca,
    0xe1d5,
    0xe546,
    0xe8b0,
    0xe550,
    0xf0ff,
    0xeb41,
    0xe869,
    0xe2a8,
    0xe110,
    0xe842,
    0xe02c,
    0xe8b1,
    0xe5c7,
    0xe548,
    0xeb6f,
    0xf8eb,
    0xf3ee,
    0xe2eb,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final allCategories = ref.watch(categoriesProvider);
        final usedIcons =
            allCategories.map((c) => c.iconCode).where((c) => c != 0).toSet();
        final currentIconOptions = {..._iconOptions, ...usedIcons}.toList();

        final filteredCategories = allCategories.where((c) {
          if (_usage == CategoryUsage.both) return true;
          return c.usage == CategoryUsage.both || c.usage == _usage;
        }).toList();

        return AlertDialog(
          title: const Text('Manage Categories'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CategoryUsage>(
                        value: _usage,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Usage',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: CategoryUsage.values
                            .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _usage = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<CategoryTag>(
                        value: _tag,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tag',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: CategoryTag.values
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _tag = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Select Icon",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _iconScrollController,
                    child: ListView.builder(
                      controller: _iconScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: currentIconOptions.length,
                      itemBuilder: (context, index) {
                        final code = currentIconOptions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () => setState(() => _iconCode = code),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _iconCode == code
                                    ? Colors.blue.withOpacity(0.2)
                                    : null,
                                border: Border.all(
                                    color: _iconCode == code
                                        ? Colors.blue
                                        : Colors.grey),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  IconData(code, fontFamily: 'MaterialIcons'),
                                  size: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_controller.text.trim().isEmpty) return;
                          if (_editingCategoryId == null) {
                            await ref
                                .read(categoriesProvider.notifier)
                                .addCategory(Category(
                                  id: const Uuid().v4(),
                                  name: _controller.text.trim(),
                                  usage: _usage,
                                  tag: _tag,
                                  iconCode: _iconCode,
                                ));
                          } else {
                            await ref
                                .read(categoriesProvider.notifier)
                                .updateCategory(
                                  _editingCategoryId!,
                                  name: _controller.text.trim(),
                                  usage: _usage,
                                  tag: _tag,
                                  iconCode: _iconCode,
                                );
                            setState(() => _editingCategoryId = null);
                          }
                          _controller.clear();
                        },
                        child: Text(_editingCategoryId == null
                            ? 'Add Category'
                            : 'Update'),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const Text("Existing Categories",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final cat = filteredCategories[index];
                      return ListTile(
                        leading: Icon(
                            IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                            size: 20),
                        title: Text(cat.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text("${cat.usage.name} | ${cat.tag.name}",
                            style: const TextStyle(fontSize: 12)),
                        dense: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                setState(() {
                                  _editingCategoryId = cat.id;
                                  _controller.text = cat.name;
                                  _usage = cat.usage;
                                  _tag = cat.tag;
                                  _iconCode = cat.iconCode;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              onPressed: () => ref
                                  .read(categoriesProvider.notifier)
                                  .removeCategory(cat.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE')),
          ],
        );
      },
    );
  }
}
