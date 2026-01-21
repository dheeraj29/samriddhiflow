import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import '../providers.dart';

class SumEntry {
  final String id;
  final double value;
  final String? name;
  final String operation; // '+', '-', '*', '/'

  SumEntry({
    required this.id,
    required this.value,
    this.name,
    this.operation = '+',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'value': value,
        'name': name,
        'operation': operation,
      };

  factory SumEntry.fromJson(Map<String, dynamic> json) => SumEntry(
        id: json['id'] ?? const Uuid().v4(),
        value: (json['value'] as num).toDouble(),
        name: json['name'],
        operation: (json['operation'] as String?) ?? '+',
      );
}

class SumProfile {
  final String id;
  final String name;
  final List<SumEntry> entries;

  SumProfile({
    required this.id,
    required this.name,
    required this.entries,
  });

  double get total {
    double runningTotal = 0;
    for (var entry in entries) {
      switch (entry.operation) {
        case '+':
          runningTotal += entry.value;
          break;
        case '-':
          runningTotal -= entry.value;
          break;
        case '*':
          runningTotal *= entry.value;
          break;
        case '/':
          if (entry.value != 0) {
            runningTotal /= entry.value;
          }
          break;
      }
    }
    return runningTotal;
  }

  SumProfile copyWith({String? name, List<SumEntry>? entries}) {
    return SumProfile(
      id: id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory SumProfile.fromJson(Map<String, dynamic> json) {
    // Migration logic for old data (List<double>)
    List<SumEntry> entries = [];
    if (json['values'] != null) {
      final values = List<double>.from(json['values']);
      entries =
          values.map((v) => SumEntry(id: const Uuid().v4(), value: v)).toList();
    } else if (json['entries'] != null) {
      entries = (json['entries'] as List)
          .map((e) => SumEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return SumProfile(
      id: json['id'],
      name: json['name'],
      entries: entries,
    );
  }
}

class SumTrackerState {
  final List<SumProfile> profiles;
  final String? activeProfileId;

  SumTrackerState({required this.profiles, this.activeProfileId});

  SumProfile? get activeProfile {
    if (activeProfileId == null) return null;
    final matches = profiles.where((p) => p.id == activeProfileId);
    if (matches.isNotEmpty) return matches.first;
    return profiles.isNotEmpty ? profiles.first : null;
  }

  SumTrackerState copyWith(
      {List<SumProfile>? profiles, String? activeProfileId}) {
    return SumTrackerState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }
}

class SumTrackerNotifier extends Notifier<SumTrackerState> {
  late Box _box;

  @override
  SumTrackerState build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) {
      return SumTrackerState(profiles: [], activeProfileId: null);
    }

    _box = Hive.box(
        'sum_tracker'); // Box is already opened by storageInitializerProvider

    final profilesJson = _box.get('profiles', defaultValue: []) as List;
    final profiles = profilesJson
        .map((p) => SumProfile.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    final activeId = _box.get('activeId') as String?;

    if (profiles.isEmpty) {
      // Create default profile if none exists (side effect safe in build if idempotent?
      // Better to return state with default and save later, or just init state here)
      // We will handle empty profiles by ensuring at least one exists logic or simply return state.
      // Actually, safest is to return state. If empty, the UI shows 'Create Profile'.
      // But we want a default.

      // We can't do async addProfile here.
      // Let's return a temporary state and then schedule a default creation?
      // Or better: Just init with a default in memory and let the first save persist it?
      if (profiles.isEmpty) {
        final defaultProfile =
            SumProfile(id: const Uuid().v4(), name: 'Default', entries: []);
        return SumTrackerState(
          profiles: [defaultProfile],
          activeProfileId: defaultProfile.id,
        );
      }
    }

    return SumTrackerState(
      profiles: profiles,
      activeProfileId: activeId,
    );
  }

  // Removed async _init()

  Future<void> addProfile(String name) async {
    final newProfile = SumProfile(
      id: const Uuid().v4(),
      name: name,
      entries: [],
    );
    final newState = state.copyWith(
      profiles: [...state.profiles, newProfile],
      activeProfileId: newProfile.id,
    );
    state = newState;
    await _save();
  }

  Future<void> activateProfile(String id) async {
    state = state.copyWith(activeProfileId: id);
    await _save();
  }

  Future<void> addValue(double value,
      {String? name, String operation = '+'}) async {
    if (state.activeProfileId == null) return;
    final active = state.activeProfile!;
    final entry = SumEntry(
        id: const Uuid().v4(), value: value, name: name, operation: operation);
    final updated = active.copyWith(entries: [...active.entries, entry]);
    final newProfiles =
        state.profiles.map((p) => p.id == active.id ? updated : p).toList();
    state = state.copyWith(profiles: newProfiles);
    await _save();
  }

  Future<void> clearValues() async {
    if (state.activeProfileId == null) return;
    final active = state.activeProfile!;
    final updated = active.copyWith(entries: []);
    final newProfiles =
        state.profiles.map((p) => p.id == active.id ? updated : p).toList();
    state = state.copyWith(profiles: newProfiles);
    await _save();
  }

  Future<void> deleteProfile(String id) async {
    final newProfiles = state.profiles.where((p) => p.id != id).toList();
    String? newActive = state.activeProfileId;
    if (newActive == id) {
      newActive = newProfiles.isNotEmpty ? newProfiles.first.id : null;
    }
    state = state.copyWith(profiles: newProfiles, activeProfileId: newActive);
    if (state.profiles.isEmpty) {
      await addProfile('Default');
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    await _box.put('profiles', state.profiles.map((p) => p.toJson()).toList());
    await _box.put('activeId', state.activeProfileId);
    await _box.flush(); // Ensure persistence
  }
}

final sumTrackerProvider =
    NotifierProvider<SumTrackerNotifier, SumTrackerState>(
        SumTrackerNotifier.new);
