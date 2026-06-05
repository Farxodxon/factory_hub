import 'dart:convert';
import 'package:http/http.dart' as http;

class FactoryHubApi {
  static const String baseUrl = 'https://flutter-backend-m8is.onrender.com';
  static const Duration timeout = Duration(seconds: 60);

  static Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) return {'success': true};
      return {'error': 'Server xatosi: ${response.statusCode}'};
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (response.statusCode >= 400) return {'error': data['error'] ?? 'Xatolik: ${response.statusCode}'};
        final result = <String, dynamic>{'success': true};
        result.addAll(data);
        return result;
      }
      return {'success': true, 'data': data};
    } catch (e) {
      return {'error': 'JSON xatosi'};
    }
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (e is http.ClientException) return {'error': 'Tarmoq xatosi'};
    if (e.toString().contains('TimeoutException')) return {'error': 'Vaqt tugadi'};
    return {'error': 'Ulanish xatosi'};
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl$path'), headers: {'Accept': 'application/json'}).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.post(Uri.parse('$baseUrl$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async => _post('/login', {'email': email, 'password': password});

  static Future<Map<String, dynamic>> setupSuperAdmin(String username, String email, String password, String secret) async =>
      _post('/setup-super-admin', {'username': username, 'email': email, 'password': password, 'secret_key': secret});

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard() async => _get('/dashboard/summary');

  // Materiallar - rol va user_id bilan
  static Future<Map<String, dynamic>> getMaterials({String? userId, String? role, String? factoryId}) async {
    final params = <String>[];
    if (userId != null) params.add('user_id=$userId');
    if (role != null) params.add('role=$role');
    if (factoryId != null) params.add('factory_id=$factoryId');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _get('/materials$query');
  }

  static Future<Map<String, dynamic>> createMaterial({
    required String name, required String type, required String unit,
    required double minStock, required double maxStock, required int leadTime,
    int? factoryId, int? assignedTo, int? createdBy,
  }) async => _post('/materials', {
    'name': name, 'type': type, 'unit': unit,
    'min_stock': minStock, 'max_stock': maxStock, 'lead_time_days': leadTime,
    'factory_id': factoryId, 'assigned_to': assignedTo, 'created_by': createdBy,
  });

  // Warehouses
  static Future<Map<String, dynamic>> getWarehouses() async => _get('/warehouses');

  // BOM
  static Future<Map<String, dynamic>> getBoms() async => _get('/boms');

  // Production
  static Future<Map<String, dynamic>> getProductionReport({String period = 'month'}) async => _get('/reports/production?period=$period');

  // Reports
  static Future<Map<String, dynamic>> getStockReport() async => _get('/reports/stock');
  static Future<Map<String, dynamic>> getForecastReport() async => _get('/reports/forecast');

  // Alerts
  static Future<Map<String, dynamic>> getAlerts() async => _get('/alerts');

  // Users
  static Future<Map<String, dynamic>> getUsers() async => _get('/users');
}
