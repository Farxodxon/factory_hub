class AppRoles {
  static const admin = 'admin';
  static const operationsManager = 'operations_manager';
  static const warehouseKeeper = 'warehouse_keeper';
  static const warehouseController = 'warehouse_controller';
  static const director = 'director';

  static bool isValid(String role) =>
      [admin, operationsManager, warehouseKeeper, warehouseController, director].contains(role);
}

extension RoleX on String {
  bool get isAdmin => this == AppRoles.admin;
  bool get isOpsManager => this == AppRoles.operationsManager;
  bool get isKeeper => this == AppRoles.warehouseKeeper;
  bool get isController => this == AppRoles.warehouseController;
  bool get isDirector => this == AppRoles.director;

  String get label {
    switch (this) {
      case AppRoles.admin:
        return 'Admin';
      case AppRoles.operationsManager:
        return 'Ish boshqaruvchi';
      case AppRoles.warehouseKeeper:
        return 'Omborchi';
      case AppRoles.warehouseController:
        return 'Ombor nazoratchisi';
      case AppRoles.director:
        return 'Direktor';
    }
    return this;
  }

  bool get canManageUsers => isAdmin;
  bool get canPlan => isAdmin || isOpsManager;
  bool get canTransactStock => !isDirector;
  bool get canControlWarehouses => isAdmin || isController;
  bool get isReadOnly => isDirector;
}
