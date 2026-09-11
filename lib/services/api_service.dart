import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/user_access.dart';
import 'auth_storage.dart';

class FactoryHubApi {
  static const String baseUrl = 'https://exim-raw-api.onrender.com';
  static const String basePath = '/fh';
  static const Duration timeout = Duration(seconds: 60);

  static String? _token;
  static Map<String, dynamic>? _currentUser;
  static UserAccess? _access;

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static UserAccess? get userAccess => _access;
  static String get role => _currentUser?['role'] ?? '';
  static int? get userId => int.tryParse(_currentUser?['id']?.toString() ?? '');
  static String get username => _currentUser?['username']?.toString() ?? '';
  static bool get isLoggedIn => _token != null;

  // ─── Sessiya ────────────────────────────────────────────────
  static Future<bool> restoreSession() async {
    try {
      final token = await AuthStorage.getToken();
      final user = await AuthStorage.getUser();
      if (token != null && user != null) {
        _token = token;
        _currentUser = user;
        await _refreshAccess();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _post(
      '/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );
    if (result['error'] == null) {
      _token = result['token'] as String?;
      _currentUser = result['user'] as Map<String, dynamic>?;
      if (_token != null && _currentUser != null) {
        await AuthStorage.saveSession(_token!, _currentUser!);
        await _refreshAccess();
      }
    }
    return result;
  }

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _access = null;
    await AuthStorage.clearSession();
  }

  static Future<void> _refreshAccess() async {
    final result = await _get('/auth/my-access');
    if (result['is_full_access'] is bool) {
      _access = UserAccess.fromJson(result);
    } else {
      _access = null;
    }
  }

  static Future<Map<String, dynamic>> setupSuperAdmin(
    String username,
    String email,
    String password,
    String secret,
  ) =>
      _post('/setup', {
        'username': username,
        'email': email,
        'password': password,
        'secret_key': secret,
      }, requiresAuth: false);

  // ─── Dashboard / statistika ────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async => _get('/dashboard/summary');

  // ─── Katalog (exim_raw) ────────────────────────────────────
  static Future<Map<String, dynamic>> getRawMaterials() async => _get('/catalog/raw-materials');

  static Future<Map<String, dynamic>> getProducts({String? search}) async =>
      _get('/catalog/products${search == null || search.isEmpty ? '' : '?search=$search'}');

  static Future<Map<String, dynamic>> getPartners() async => _get('/catalog/partners');

  // ─── Omborlar va zaxira ────────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouses() async => _get('/warehouses');

  static Future<Map<String, dynamic>> createWarehouse({
    required String name,
    required String type,
    bool canAnalyze = true,
    bool canTransfer = false,
    bool canIncome = true,
    bool canExpense = true,
    List<int> transferTo = const [],
  }) async =>
      _post('/warehouses', {
        'name': name,
        'type': type,
        'canAnalyze': canAnalyze,
        'canTransfer': canTransfer,
        'canIncome': canIncome,
        'canExpense': canExpense,
        'transferTo': transferTo,
      });

  static Future<Map<String, dynamic>> updateWarehouse({
    required int id,
    required bool canAnalyze,
    required bool canTransfer,
    required bool canIncome,
    required bool canExpense,
    required List<int> transferTo,
    int? fixedTransferTo,
  }) async =>
      _put('/warehouses/$id', {
        'canAnalyze': canAnalyze,
        'canTransfer': canTransfer,
        'canIncome': canIncome,
        'canExpense': canExpense,
        'transferTo': transferTo,
        'fixedTransferTo': fixedTransferTo,
      });

  static Future<Map<String, dynamic>> deleteWarehouse(int id) async =>
      _delete('/warehouses/$id');

  static Future<Map<String, dynamic>> getWarehouseDetail(int id) async => _get('/warehouses/$id');

  static Future<Map<String, dynamic>> getWarehouseTransactions(int id, {int limit = 50}) async =>
      _get('/warehouses/$id/transactions?limit=$limit');

  static Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async =>
      _post('/warehouse/transaction', data);

  static Future<Map<String, dynamic>> getStock({int? warehouseId}) async =>
      _get('/stock${warehouseId == null ? '' : '?warehouse_id=$warehouseId'}');

  // ─── Dillerlar ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDealers({String? marketType}) async {
    final q = marketType == null || marketType.isEmpty ? '' : '?market_type=$marketType';
    return _get('/dealers$q');
  }

  static Future<Map<String, dynamic>> getDealerDetail(int id) async => _get('/dealers/$id');

  static Future<Map<String, dynamic>> createDealer({
    required String name,
    required String marketType,
    String? phone,
    String? address,
    String? contactPerson,
    bool isActive = true,
  }) async =>
      _post('/dealers', {
        'name': name,
        'marketType': marketType,
        'phone': phone,
        'address': address,
        'contactPerson': contactPerson,
        'isActive': isActive,
      });

  static Future<Map<String, dynamic>> updateDealer({
    required int id,
    required String name,
    required String marketType,
    String? phone,
    String? address,
    String? contactPerson,
    required bool isActive,
  }) async =>
      _put('/dealers/$id', {
        'name': name,
        'marketType': marketType,
        'phone': phone,
        'address': address,
        'contactPerson': contactPerson,
        'isActive': isActive,
      });

  static Future<Map<String, dynamic>> deleteDealer(int id) async =>
      _delete('/dealers/$id');

  // ─── 51-rejim qoldig'i hisoboti ────────────────────────────
  static Future<Map<String, dynamic>> getRegime51Balance({int? warehouseId, int? itemId}) {
    final q = <String>[];
    if (warehouseId != null) q.add('warehouse_id=$warehouseId');
    if (itemId != null) q.add('item_id=$itemId');
    return _get('/reports/regime51-balance${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  // ─── Rejalar ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPlans({String? status}) async =>
      _get('/plans${status == null ? '' : '?status=$status'}');

  static Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async =>
      _post('/plans', data);

  static Future<Map<String, dynamic>> updatePlanStatus(int id, String status) async =>
      _put('/plans/$id', {'status': status});

  static Future<Map<String, dynamic>> updatePlan(int id, Map<String, dynamic> data) async =>
      _put('/plans/$id', data);

  // ─── Ta'minotchi buyurtmalari ──────────────────────────────
  static Future<Map<String, dynamic>> getSupplierOrders({String? status}) async =>
      _get('/supplier-orders${status == null ? '' : '?status=$status'}');

  static Future<Map<String, dynamic>> createSupplierOrder(Map<String, dynamic> data) async =>
      _post('/supplier-orders', data);

  static Future<Map<String, dynamic>> updateSupplierOrderStatus(int id, String status) async =>
      _put('/supplier-orders/$id', {'status': status});

  // ─── Ishlab chiqarish ──────────────────────────────────────
  static Future<Map<String, dynamic>> getNorms(String barcode) async =>
      _get('/production/norms/$barcode');

  static Future<Map<String, dynamic>> startProduction(Map<String, dynamic> data) async =>
      _post('/production/start', data);

  static Future<Map<String, dynamic>> updateBatch(int id, Map<String, dynamic> data) async =>
      _put('/production/$id', data);

  static Future<Map<String, dynamic>> getBatches({String? status}) async =>
      _get('/reports/production${status == null ? '' : '?status=$status'}');

  // ─── Ogohlantirishlar ──────────────────────────────────────
  static Future<Map<String, dynamic>> getAlerts() async => _get('/alerts');

  // ─── HR: Xodimlar ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getEmployees({
    String? status,
    String? department,
    String? search,
  }) {
    final q = <String>[];
    if (status != null && status.isNotEmpty) q.add('status=$status');
    if (department != null && department.isNotEmpty) q.add('department=$department');
    if (search != null && search.isNotEmpty) q.add('search=${Uri.encodeQueryComponent(search)}');
    return _get('/hr/employees${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async =>
      _post('/hr/employees', data);

  static Future<Map<String, dynamic>> getEmployee(int id) async => _get('/hr/employees/$id');

  static Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async =>
      _put('/hr/employees/$id', data);

  static Future<Map<String, dynamic>> fireEmployee(int id, {String? reason}) async =>
      _delete('/hr/employees/$id');

  // ─── HR: Davomat ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getAttendance({
    int? employeeId,
    String? from,
    String? to,
  }) {
    final q = <String>[];
    if (employeeId != null) q.add('employee_id=$employeeId');
    if (from != null && from.isNotEmpty) q.add('from=$from');
    if (to != null && to.isNotEmpty) q.add('to=$to');
    return _get('/hr/attendance${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static Future<Map<String, dynamic>> addAttendance(Map<String, dynamic> data) async =>
      _post('/hr/attendance', data);

  static Future<Map<String, dynamic>> addAttendanceBulk(Map<String, dynamic> data) async =>
      _post('/hr/attendance/bulk', data);

  static Future<Map<String, dynamic>> updateAttendance(int id, Map<String, dynamic> data) async =>
      _put('/hr/attendance/$id', data);

  // ─── HR: Premiya/Jarima/Avans ──────────────────────────────
  static Future<Map<String, dynamic>> getSalaryAdjustments({    int? employeeId,
    String? type,
    String? status,
    String? from,
    String? to,
  }) {
    final q = <String>[];
    if (employeeId != null) q.add('employee_id=$employeeId');
    if (type != null && type.isNotEmpty) q.add('type=$type');
    if (status != null && status.isNotEmpty) q.add('status=$status');
    if (from != null && from.isNotEmpty) q.add('from=$from');
    if (to != null && to.isNotEmpty) q.add('to=$to');
    return _get('/hr/salary-adjustments${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static Future<Map<String, dynamic>> addSalaryAdjustment(Map<String, dynamic> data) async =>
      _post('/hr/salary-adjustments', data);

  static Future<Map<String, dynamic>> approveSalaryAdjustment(int id) async =>
      _put('/hr/salary-adjustments/$id/approve', {});

  static Future<Map<String, dynamic>> rejectSalaryAdjustment(int id) async =>
      _put('/hr/salary-adjustments/$id/reject', {});

  // ─── HR: Stavkalar (piece_rates) ───────────────────────────
  static Future<Map<String, dynamic>> getPieceRates({String? workType}) async {
    final q = <String>[];
    if (workType != null && workType.isNotEmpty) q.add('work_type=$workType');
    return _get('/hr/piece-rates${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static Future<Map<String, dynamic>> createPieceRate(Map<String, dynamic> data) async =>
      _post('/hr/piece-rates', data);

  static Future<Map<String, dynamic>> updatePieceRate(int id, Map<String, dynamic> data) async =>
      _put('/hr/piece-rates/$id', data);

  static Future<Map<String, dynamic>> deletePieceRate(int id) async =>
      _delete('/hr/piece-rates/$id');

  // ─── HR: Ish yozuvlari (work_records) ──────────────────────
  static Future<Map<String, dynamic>> getWorkRecords({
    int? employeeId,
    String? month,
    String? workType,
  }) {
    final q = <String>[];
    if (employeeId != null) q.add('employee_id=$employeeId');
    if (month != null && month.isNotEmpty) q.add('month=$month');
    if (workType != null && workType.isNotEmpty) q.add('work_type=$workType');
    return _get('/hr/work-records${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static Future<Map<String, dynamic>> createWorkRecord(Map<String, dynamic> data) async =>
      _post('/hr/work-records', data);

  static Future<Map<String, dynamic>> deleteWorkRecord(int id) async =>
      _delete('/hr/work-records/$id');

  // ─── HR: Oylik hisobot ─────────────────────────────────────
  static Future<Map<String, dynamic>> getMonthlyReport({
    String? month,
    int? employeeId,
  }) {
    final q = <String>[];
    if (month != null && month.isNotEmpty) q.add('month=$month');
    if (employeeId != null) q.add('employee_id=$employeeId');
    return _get('/hr/reports/monthly${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  // ─── Kritik darajalar (thresholds, admin) ──────────────────
  static Future<Map<String, dynamic>> getThresholds({String? type}) async =>
      _get('/thresholds${type == null ? '' : '?type=$type'}');

  static Future<Map<String, dynamic>> updateThreshold(int id, num minQty) async =>
      _put('/thresholds', {'id': id, 'min_qty': minQty});

  // ─── Foydalanuvchilar ──────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers() async => _get('/users');

  static Future<Map<String, dynamic>> getUserDetail(int id) async => _get('/users/$id');

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async =>
      _post('/users', data);

  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async =>
      _put('/users/$id', data);

  static Future<Map<String, dynamic>> deactivateUser(int id) async => _delete('/users/$id');

  static Future<Map<String, dynamic>> assignUser({
    required int userId,
    required List<int> warehouseIds,
  }) async =>
      _post('/users/assign', {
        'user_id': userId,
        'warehouse_ids': warehouseIds,
      });

  // ─── Admin: foydalanuvchi kirish huquqlari ────────────────
  static Future<Map<String, dynamic>> getAdminModules() async => _get('/admin/modules');

  static Future<Map<String, dynamic>> getUserAccess(int userId) async =>
      _get('/admin/users/$userId/access');

  static Future<Map<String, dynamic>> grantWarehouse(int userId, int warehouseId) async =>
      _post('/admin/users/$userId/warehouses', {'warehouse_id': warehouseId});

  static Future<Map<String, dynamic>> revokeWarehouse(int userId, int warehouseId) async =>
      _delete('/admin/users/$userId/warehouses/$warehouseId');

  static Future<Map<String, dynamic>> grantModule(int userId, String moduleKey) async =>
      _post('/admin/users/$userId/modules', {'module_key': moduleKey});

  static Future<Map<String, dynamic>> revokeModule(int userId, String moduleKey) async =>
      _delete('/admin/users/$userId/modules/$moduleKey');

  // ─── Product ↔ Warehouse (Many-to-Many) ────────────────
  static Future<Map<String, dynamic>> getProductWarehouses({int? warehouseId}) async =>
      _get('/product-warehouses${warehouseId != null ? '?warehouse_id=$warehouseId' : ''}');

  static Future<Map<String, dynamic>> assignProductWarehouses(Map<String, dynamic> data) async =>
      _post('/product-warehouses', data);

  static Future<Map<String, dynamic>> removeProductWarehouses(Map<String, dynamic> data) async =>
      _delete('/product-warehouses', body: data);

  // ─── Inter-Warehouse Transfers ─────────────────────────
  static Future<Map<String, dynamic>> getTransfers() async => _get('/transfers');

  static Future<Map<String, dynamic>> getTransferDetail(int id) async => _get('/transfers/$id');

  static Future<Map<String, dynamic>> createTransfer(Map<String, dynamic> data) async =>
      _post('/transfers', data);

  static Future<Map<String, dynamic>> sendTransfer(Map<String, dynamic> data) async =>
      _post('/transfers/send', data);

  // ─── Warehouse Report ──────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouseReport({
    required int warehouseId,
    String? from,
    String? to,
  }) async {
    var url = '/reports/warehouse?warehouse_id=$warehouseId';
    if (from != null) url += '&from=$from';
    if (to != null) url += '&to=$to';
    return _get(url);
  }

  // ─── Unified Items Catalog ────────────────────────────
  static Future<Map<String, dynamic>> getItems() async => _get('/items');

  static Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async =>
      _post('/items', data);

  // ─── BOM (Retsept) ──────────────────────────────────
  static Future<Map<String, dynamic>> getBoms() async => _get('/boms');

  static Future<Map<String, dynamic>> getBomDetail(int id) async => _get('/boms/$id');

  static Future<Map<String, dynamic>> createBom(Map<String, dynamic> data) async =>
      _post('/boms', data);

  static Future<Map<String, dynamic>> updateBom(int id, Map<String, dynamic> data) async =>
      _put('/boms/$id', data);

  // ─── Multi-Stage Production (BOM-based) ─────────────
  static Future<Map<String, dynamic>> startBomProduction(Map<String, dynamic> data) async =>
      _post('/production/bom/start', data);

  // ─── Soddalashtirilgan ishlab chiqarish (Mixing) ─────
  static Future<Map<String, dynamic>> mixingPreview({
    required int bomId,
    required double outputQuantity,
  }) async =>
      _get('/production/mixing/preview?bom_id=$bomId&output_quantity=$outputQuantity');

  static Future<Map<String, dynamic>> startMixing({
    required int bomId,
    required double outputQuantity,
    int? employeeId,
  }) async =>
      _post('/production/mixing/start', {
        'bom_id': bomId,
        'output_quantity': outputQuantity,
        if (employeeId != null) 'employee_id': employeeId,
      });

  // ─── Qadoqlash (Packaging) ─────────────────────────
  static Future<Map<String, dynamic>> packagingPreview({
    required int bomId,
    required double outputQuantity,
  }) async =>
      _get('/production/packaging/preview?bom_id=$bomId&output_quantity=$outputQuantity');

  static Future<Map<String, dynamic>> startPackaging({
    required int bomId,
    required double outputQuantity,
    required int destWarehouseId,
    int? employeeId,
  }) async =>
      _post('/production/packaging/start', {
        'bom_id': bomId,
        'output_quantity': outputQuantity,
        'dest_warehouse_id': destWarehouseId,
        if (employeeId != null) 'employee_id': employeeId,
      });

  // ─── Tasdiqlash zanjiri (pending transfers) ────────
  static Future<Map<String, dynamic>> getPendingTransfers({required int warehouseId}) async =>
      _get('/transfers/pending?warehouse_id=$warehouseId');

  static Future<Map<String, dynamic>> getPendingCounts() async =>
      _get('/transfers/pending/summary');

  static Future<Map<String, dynamic>> confirmTransfer(int transferId) async =>
      _post('/transfers/$transferId/confirm', {});

  static Future<Map<String, dynamic>> rejectTransfer(int transferId, String reason) async =>
      _post('/transfers/$transferId/reject', {'reason': reason});

  // ─── Karantin tekshiruvi (inspections) ─────────────
  static Future<Map<String, dynamic>> receiveToQuarantine({
    required int itemId,
    required double quantity,
    String? unit,
    required int quarantineWarehouseId,
    String? note,
  }) async =>
      _post('/inspections/receive', {
        'item_id': itemId,
        'quantity': quantity,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        'quarantine_warehouse_id': quarantineWarehouseId,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  static Future<Map<String, dynamic>> getPendingInspections({required int warehouseId}) async =>
      _get('/inspections/pending?warehouse_id=$warehouseId');

  static Future<Map<String, dynamic>> decideInspection(int inspectionId, String result, {String? note}) async =>
      _post('/inspections/$inspectionId/decide', {
        'result': result,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  // ─── Write-Off (Yo'qotish) ──────────────────────────
  static Future<Map<String, dynamic>> writeOff(Map<String, dynamic> data) async =>
      _post('/stock/write-off', data);

  // ─── Hisobot (Excel) ─────────────────────────────────────
  static Future<String?> downloadTransactionReport({
    required String from,
    required String to,
    String type = 'all',
    int? warehouseId,
  }) async {
    try {
      var url = '$baseUrl$basePath/reports/transactions?from=$from&to=$to&type=$type';
      if (warehouseId != null) url += '&warehouse_id=$warehouseId';
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/hisobot_${from}_${to}.xlsx');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) print('Excel download xato: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE HTTP METHODS
  // ═══════════════════════════════════════════════════════════

  static Map<String, String> _headers({bool requiresAuth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      return response.statusCode < 300
          ? {'success': true}
          : {'error': 'Server xatosi: ${response.statusCode}'};
    }
    try {
      final trimmed = response.body.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        if (response.statusCode == 404) {
          return {'error': 'Endpoint topilmadi (404). Backend yangilanishi kerak bo\'lishi mumkin.'};
        }
        if (response.statusCode >= 500) {
          return {'error': 'Server vaqtincha ishlamayapti (${response.statusCode}). 30 soniyadan keyin qayta urinib ko\'ring.'};
        }
        return {'error': 'Server noto\'g\'ri javob qaytardi (${response.statusCode})'};
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (response.statusCode == 401) {
          logout();
          return {'error': 'Sessiya tugadi. Qayta kiring.', 'unauthorized': true};
        }
        if (response.statusCode >= 400) {
          return {'error': data['error'] ?? 'Xatolik: ${response.statusCode}'};
        }
        return {'success': true, ...data};
      }
      return {'success': true, 'data': data};
    } catch (_) {
      if (response.statusCode >= 500) {
        return {'error': 'Server xatosi (${response.statusCode}). Keyinroq qayta urinib ko\'ring.'};
      }
      return {'error': "Javobni o'qishda xatolik (${response.statusCode})"};
    }
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (kDebugMode) print('API xatolik: $e');
    if (e.toString().contains('TimeoutException')) {
      return {'error': 'Server javob bermadi. Qayta urinib koring.'};
    }
    return {'error': 'Tarmoq xatosi. Internetni tekshiring.'};
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    bool requiresAuth = true,
  }) async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl$basePath$path'), headers: _headers(requiresAuth: requiresAuth))
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl$basePath$path'),
            headers: _headers(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .put(
            Uri.parse('$baseUrl$basePath$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final r = await http
          .delete(
            Uri.parse('$baseUrl$basePath$path'),
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }
}
