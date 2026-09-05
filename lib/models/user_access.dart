class UserAccessWarehouse {
  final int id;
  final String name;
  final String type;

  const UserAccessWarehouse(this.id, this.name, this.type);

  factory UserAccessWarehouse.fromJson(Map<String, dynamic> j) => UserAccessWarehouse(
        (j['id'] as num?)?.toInt() ?? 0,
        j['name']?.toString() ?? '',
        j['type']?.toString() ?? '',
      );
}

class UserAccessModule {
  final String key;
  final String nameUz;
  final String category;

  const UserAccessModule(this.key, this.nameUz, this.category);

  factory UserAccessModule.fromJson(Map<String, dynamic> j) => UserAccessModule(
        j['module_key']?.toString() ?? '',
        j['name_uz']?.toString() ?? '',
        j['category']?.toString() ?? '',
      );
}

class UserAccess {
  final String role;
  final bool isFullAccess;
  final List<UserAccessWarehouse> warehouses;
  final List<UserAccessModule> modules;

  const UserAccess({
    required this.role,
    required this.isFullAccess,
    required this.warehouses,
    required this.modules,
  });

  factory UserAccess.fromJson(Map<String, dynamic> j) => UserAccess(
        role: j['role']?.toString() ?? '',
        isFullAccess: j['is_full_access'] == true,
        warehouses: ((j['warehouses'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(UserAccessWarehouse.fromJson)
            .toList(),
        modules: ((j['modules'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(UserAccessModule.fromJson)
            .toList(),
      );

  bool get isEmpty => !isFullAccess && warehouses.isEmpty && modules.isEmpty;
}