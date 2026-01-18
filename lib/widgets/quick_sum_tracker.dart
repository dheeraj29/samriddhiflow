import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sum_tracker_provider.dart';
import '../providers.dart';
import '../widgets/pure_icons.dart';
import '../navigator_key.dart';

class QuickSumTracker extends ConsumerStatefulWidget {
  const QuickSumTracker({super.key});

  @override
  ConsumerState<QuickSumTracker> createState() => _QuickSumTrackerState();
}

class _QuickSumTrackerState extends ConsumerState<QuickSumTracker> {
  bool _isExpanded = false;
  Offset _position = const Offset(0, 100);
  bool _initialized = false;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sumTrackerProvider);
    final activeProfile = state.activeProfile;
    final currencyLocale = ref.watch(currencyProvider);
    final formatter = NumberFormat.simpleCurrency(locale: currencyLocale);

    if (activeProfile == null) return const SizedBox();

    final screenSize = MediaQuery.of(context).size;

    // Initial position to right edge middle
    if (!_initialized) {
      _position =
          Offset(screenSize.width - (60 + 16), (screenSize.height / 2) - 30);
      _initialized = true;
    }

    // Clamp position within screen
    final double targetWidth =
        _isExpanded ? (screenSize.width * 0.9).clamp(200.0, 260.0) : 60;
    final double targetHeight =
        _isExpanded ? (screenSize.height * 0.7).clamp(300.0, 360.0) : 60;
    final viewPadding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomInset = viewPadding.bottom + viewInsets.bottom + 20;

    _position = Offset(
      _position.dx.clamp(0.0, screenSize.width - targetWidth),
      _position.dy.clamp(
          viewPadding.top, (screenSize.height - targetHeight - bottomInset)),
    );

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: _isExpanded
                    ? SizedBox(
                        width: targetWidth,
                        height: targetHeight,
                        child: OverflowBox(
                          minWidth: targetWidth,
                          maxWidth: targetWidth,
                          minHeight: targetHeight,
                          maxHeight: targetHeight,
                          alignment: Alignment.topLeft,
                          child: _buildExpandedContent(targetWidth,
                              activeProfile, state.profiles, formatter),
                        ),
                      )
                    : _buildCollapsedContent(activeProfile, formatter),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(SumProfile active, NumberFormat formatter) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PureIcons.calculate(color: const Color(0xFF6C63FF), size: 24),
            Text(
              NumberFormat.compact().format(active.total),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(double currentWidth, SumProfile active,
      List<SumProfile> allProfiles, NumberFormat formatter) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  active.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (currentWidth > 150) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: PureIcons.switchAccount(
                      size: 18, color: const Color(0xFF6C63FF)),
                  onPressed: () => _showProfileManager(allProfiles),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: PureIcons.close(size: 18),
                  onPressed: () => setState(() => _isExpanded = false),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Total Display
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            formatter.format(active.total),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        // History List
        Expanded(
          child: active.entries.isEmpty
              ? const Center(
                  child: Text('Add values below',
                      style: TextStyle(color: Colors.grey, fontSize: 11)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: active.entries.length,
                  itemBuilder: (context, index) {
                    final entry =
                        active.entries[active.entries.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                                entry.name ??
                                    (entry.operation == '+'
                                        ? 'Value'
                                        : 'Op: ${entry.operation}'),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                              '${entry.operation == '+' ? '' : ('${entry.operation} ')}${(entry.operation == '*' || entry.operation == '/') ? entry.value : formatter.format(entry.value)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Input Area
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Entry name (optional)',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Value (e.g., 5 or *2)',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.\+\-\*\/]'))
                        ],
                        onSubmitted: (_) => _addValue(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF6C63FF),
                    radius: 16,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: PureIcons.add(color: Colors.white, size: 18),
                      onPressed: _addValue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Bottom Actions
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    ref.read(sumTrackerProvider.notifier).clearValues(),
                child: const Text('Clear History',
                    style: TextStyle(fontSize: 11, color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addValue() {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    String operation = '+';
    if (text.startsWith(RegExp(r'[+\-*/]'))) {
      operation = text[0];
      text = text.substring(1).trim();
    }

    final val = double.tryParse(text);
    if (val != null) {
      ref.read(sumTrackerProvider.notifier).addValue(
            val,
            name: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            operation: operation,
          );
      _controller.clear();
      _nameController.clear();
      _focusNode.requestFocus();
    }
  }

  void _showProfileManager(List<SumProfile> allProfiles) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Profiles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: SizedBox(
          width: 300,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(
              shrinkWrap: true,
              children: [
                ...allProfiles.map((p) => ListTile(
                      dense: true,
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('Total: ${p.total}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: p.id ==
                              ref.read(sumTrackerProvider).activeProfileId
                          ? PureIcons.checkCircle(color: Colors.green, size: 20)
                          : IconButton(
                              icon: PureIcons.deleteOutlined(
                                  size: 18, color: Colors.redAccent),
                              onPressed: () {
                                ref
                                    .read(sumTrackerProvider.notifier)
                                    .deleteProfile(p.id);
                                Navigator.pop(context);
                              }),
                      onTap: () {
                        ref
                            .read(sumTrackerProvider.notifier)
                            .activateProfile(p.id);
                        Navigator.pop(context);
                      },
                    )),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: PureIcons.addCircle(
                      size: 20, color: const Color(0xFF6C63FF)),
                  title: const Text('Create New Profile',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold)),
                  onTap: () => _showAddProfileDialog(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showAddProfileDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Profile Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref
                    .read(sumTrackerProvider.notifier)
                    .addProfile(nameController.text);
                Navigator.pop(context); // Close add profile dialog
                Navigator.pop(context); // Close profile manager
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
