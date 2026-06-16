import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class FactoryHubApi {
  static const String baseUrl = 'https://flutter-backend-m8is.onrender.com';
  static const Duration timeout = Duration(seconds: 60);

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String get role => _currentUser?['role'] ?? 'employee';
  static int? get userId => int.tryParse(_currentUser?['id']?.toString() ?? '');
  static int? get factoryId => _currentUser?['factoryId'] as int?;
  static bool get isLoggedIn => _token != null;

  // Ilova ishga tushganda sessiyani tiklash
  static Future<bool> restoreSession() async {
    try {
      final token = await AuthStorage.getToken();
      final user = await AuthStorage.getUser();
      if (token != null && user != null) {
        _token = token;
        _currentUser = user;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _post(
      '/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );
    if (result['error'] == null) {
      _token = result['token'] as String?;
      _currentUser = result['user'] as Map<String, dynamic>?;
      // Persistent saqlash
      if (_token != null && _currentUser != null) {
        await AuthStorage.saveSession(_token!, _currentUser!);
      }
    }
    return result;
  }

  // Chiqish
  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await AuthStorage.clearSession();
  }

  // Setup
  static Future<Map<String, dynamic>> setupSuperAdmin(
    String username, String email, String password, String secret) async =>
      _post('/setup', {
        'username': username, 'email': email,
        'password': password, 'secret_key': secret,
      }, requiresAuth: false);

  // ─── Dashboard ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async =>
      _get('/dashboard/summary');

  static Future<Map<String, dynamic>> getSuperAdminDashboard() async =>
      _get('/dashboard/super_admin');

  static Future<Map<String, dynamic>> getFactoryAdminDashboard() async =>
      _get('/dashboard/factory_admin');

  // ─── Factories ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getFactories() async =>
      _get('/factories');

  static Future<Map<String, dynamic>> createFactory({
    required String name, String? address,
  }) async => _post('/factories', {'name': name, 'address': address});

  static Future<Map<String, dynamic>> updateFactory(int id, {
    String? name, String? address, bool? isActive,
  }) async => _put('/factories/$id', {
    if (name != null) 'name': name,
    if (address != null) 'address': address,
    if (isActive != null) 'isActive': isActive,
  });

  // ─── Materiallar ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getMaterials() async =>
      _get('/materials?user_id=$userId&role=$role');

  static Future<Map<String, dynamic>> createMaterial(Map<String, dynamic> data) async =>
      _post('/materials', data);

  // ─── Omborlar ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouses() async =>
      _get('/warehouses');

  static Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async =>
      _post('/warehouse/transaction', data);

  // ─── BOM ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBoms() async => _get('/boms');

  static Future<Map<String, dynamic>> createBom(Map<String, dynamic> data) async =>
      _post('/boms', data);

  // ─── Ishlab chiqarish ─────────────────────────────────────
  static Future<Map<String, dynamic>> startProduction(Map<String, dynamic> data) async =>
      _post('/production/start', data);

  static Future<Map<String, dynamic>> updateProduction(int id, Map<String, dynamic> data) async =>
      _put('/production/$id', data);

  // ─── Hisobotlar ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getProductionReport(String period) async =>
      _get('/reports/production?period=$period');

  static Future<Map<String, dynamic>> getStockReport() async =>
      _get('/reports/stock');

  static Future<Map<String, dynamic>> getForecastReport() async =>
      _get('/reports/forecast');

  // ─── Ogohlantirishlar ─────────────────────────────────────
  static Future<Map<String, dynamic>> getAlerts() async => _get('/alerts');

  static Future<Map<String, dynamic>> generateAlerts() async =>
      _post('/alerts', {});

  // ─── Foydalanuvchilar ─────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers() async => _get('/users');

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async =>
      _post('/users', data);

  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async =>
      _put('/users/$id', data);

  // ─── Departamentlar─────────────────────────────────────

  static Future<Map<String, dynamic>> getDepartments() async =>
      _get('/departments');

  static Future<Map<String, dynamic>> createDepartment(Map<String, dynamic> data) async =>
      _post('/departments', data);

  static Future<Map<String, dynamic>> getUserDetail(int id) async =>
      _get('/users/$id');

  static Future<Map<String, dynamic>> assignUser({
    required int userId,
    required List<int> departmentIds,
    required List<int> warehouseIds,
  }) async =>
      _post('/users/assign', {
        'user_id': userId,
        'department_ids': departmentIds,
        'warehouse_ids': warehouseIds,
      });

  // ─── Kategoriyalar ────────────────────────────────────────
  static Future<Map<String, dynamic>> getCategories() async =>
      _get('/categories');

  static Future<Map<String, dynamic>> getProductTypes() async =>
      _get('/product-types');

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
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (response.statusCode == 401) {
          // Token muddati o'tgan — sessiyani tozalash
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
      return {'error': 'Javob o\'qishda xatolik'};
    }
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (kDebugMode) print('API xatolik: $e');
    if (e.toString().contains('TimeoutException')) {
      return {'error': 'Server javob bermadi. Qayta urinib ko\'ring.'};
    }
    return {'error': 'Tarmoq xatosi. Internetni tekshiring.'};
  }

  static Future<Map<String, dynamic>> _get(String path, {bool requiresAuth = true}) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(requiresAuth: requiresAuth),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(requiresAuth: requiresAuth),
        body: jsonEncode(body),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }
}
