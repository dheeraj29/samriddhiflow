import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'category.g.dart';

@HiveType(typeId: 15)
enum CategoryUsage {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
  @HiveField(2)
  both
}

@HiveType(typeId: 16)
enum CategoryTag {
  @HiveField(0)
  none,
  @HiveField(1)
  capitalGain,
  @HiveField(3)
  directTax,
  @HiveField(4)
  budgetFree,
  @HiveField(5)
  taxFree,
}

@HiveType(typeId: 17)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  CategoryUsage usage;

  @HiveField(3)
  CategoryTag tag;

  @HiveField(4)
  int iconCode; // Material icon codepoint

  @HiveField(5)
  String? profileId;

  Category({
    required this.id,
    required this.name,
    required this.usage,
    this.tag = CategoryTag.none,
    this.iconCode = 0,
    this.profileId,
  });

  factory Category.create({
    required String name,
    required CategoryUsage usage,
    CategoryTag tag = CategoryTag.none,
    int iconCode = 0,
    String? profileId = 'default',
  }) {
    return Category(
      id: const Uuid().v4(),
      name: name,
      usage: usage,
      tag: tag,
      iconCode: iconCode,
      profileId: profileId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'usage': usage.index,
      'tag': tag.index,
      'iconCode': iconCode,
      'profileId': profileId,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      usage: CategoryUsage.values[map['usage']],
      tag: CategoryTag.values[map['tag']],
      iconCode: map['iconCode'],
      profileId: map['profileId'],
    );
  }
}
