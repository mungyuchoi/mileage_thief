import 'package:firebase_database/firebase_database.dart';

import 'category_service.dart';

enum AdminCategoryMoveDirection {
  up,
  down,
}

class AdminCommunityCategory {
  const AdminCommunityCategory({
    required this.databaseKey,
    required this.id,
    required this.name,
    required this.group,
    required this.description,
    required this.icon,
    required this.fabEnabled,
    required this.order,
  });

  final String databaseKey;
  final String id;
  final String name;
  final String group;
  final String description;
  final String icon;
  final bool fabEnabled;
  final double order;

  factory AdminCommunityCategory.fromMap(Map<String, dynamic> data) {
    return AdminCommunityCategory(
      databaseKey: (data['databaseKey'] ?? '').toString(),
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '이름 없음').toString(),
      group: (data['group'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      icon: (data['icon'] ?? '').toString(),
      fabEnabled: data['fabEnabled'] == true,
      order: _toDouble(data['order']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class AdminCategoryService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static Future<List<AdminCommunityCategory>> loadCategories() async {
    final snapshot = await _database.child('CATEGORIES').get();
    return _categoriesFromRaw(snapshot.value);
  }

  static Future<List<AdminCommunityCategory>> moveCategory({
    required String categoryId,
    required AdminCategoryMoveDirection direction,
  }) async {
    final categories = await loadCategories();
    final currentIndex =
        categories.indexWhere((category) => category.id == categoryId);
    if (currentIndex < 0) {
      throw StateError('카테고리를 찾을 수 없습니다.');
    }

    final targetIndex = direction == AdminCategoryMoveDirection.up
        ? currentIndex - 1
        : currentIndex + 1;
    if (targetIndex < 0 || targetIndex >= categories.length) {
      return categories;
    }

    final current = categories[currentIndex];
    final target = categories[targetIndex];
    final updates = <String, Object?>{};

    if (current.order == target.order) {
      final reordered = List<AdminCommunityCategory>.of(categories);
      reordered.removeAt(currentIndex);
      reordered.insert(targetIndex, current);
      for (var index = 0; index < reordered.length; index += 1) {
        updates['CATEGORIES/${reordered[index].databaseKey}/order'] = index + 1;
      }
    } else {
      updates['CATEGORIES/${current.databaseKey}/order'] = target.order;
      updates['CATEGORIES/${target.databaseKey}/order'] = current.order;
    }

    await _database.update(updates);
    CategoryService().clearCache();
    return loadCategories();
  }

  static List<AdminCommunityCategory> _categoriesFromRaw(Object? raw) {
    final entries = <AdminCommunityCategory>[];
    if (raw is List) {
      for (var index = 0; index < raw.length; index += 1) {
        final category = _categoryFromEntry(
          index.toString(),
          raw[index],
          index,
        );
        if (category != null) entries.add(category);
      }
    } else if (raw is Map) {
      var fallbackIndex = 0;
      for (final entry in raw.entries) {
        final category = _categoryFromEntry(
          entry.key.toString(),
          entry.value,
          fallbackIndex,
        );
        fallbackIndex += 1;
        if (category != null) entries.add(category);
      }
    }

    entries.sort((a, b) {
      final orderCompare = a.order.compareTo(b.order);
      if (orderCompare != 0) return orderCompare;
      final aKey = int.tryParse(a.databaseKey);
      final bKey = int.tryParse(b.databaseKey);
      if (aKey != null && bKey != null && aKey != bKey) {
        return aKey.compareTo(bKey);
      }
      return a.databaseKey.compareTo(b.databaseKey);
    });
    return entries;
  }

  static AdminCommunityCategory? _categoryFromEntry(
    String databaseKey,
    Object? raw,
    int fallbackIndex,
  ) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final id = (data['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;

    return AdminCommunityCategory.fromMap({
      ...data,
      'databaseKey': databaseKey,
      'order': data['order'] ?? fallbackIndex + 1,
    });
  }
}
