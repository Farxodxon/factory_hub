class AppRoles {
  static const admin = 'admin';
  static const operationsManager = 'operations_manager';
  static const warehouseKeeper = 'warehouse_keeper';
  static const warehouseController = 'warehouse_controller';
  static const director = 'director';
  static const hrManager = 'hr_manager';

  static bool isValid(String role) => [
        admin,
        operationsManager,
        warehouseKeeper,
        warehouseController,
        director,
        hrManager,
      ].contains(role);
}

extension RoleX on String {
  bool get isAdmin => this == AppRoles.admin;
  bool get isOpsManager => this == AppRoles.operationsManager;
  bool get isKeeper => this == AppRoles.warehouseKeeper;
  bool get isController => this == AppRoles.warehouseController;
  bool get isDirector => this == AppRoles.director;
  bool get isHrManager => this == AppRoles.hrManager;

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
      case AppRoles.hrManager:
        return 'HR boshqaruvchi';
    }
    return this;
  }

  bool get canManageUsers => isAdmin;
  bool get canManageThresholds => isAdmin;
  bool get canPlan => isAdmin || isOpsManager;
  bool get canTransactStock => !isDirector && !isHrManager;
  bool get canControlWarehouses => isAdmin || isController;
  bool get isReadOnly => isDirector;

  bool get canViewHr => isAdmin || isHrManager || isDirector;
  bool get canManageHr => isAdmin || isHrManager;
}
