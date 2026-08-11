import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> predictExpense({
    required String userId,
    required String text,
    required double amount,
    required String paymentMethod,
    required String location,
  }) async {
    final url = Uri.parse('$_baseUrl/predict_test');

    final body = {
      "user_id": userId,
      "text": text.trim().toLowerCase(),
      "amount": amount,
      "payment_method": paymentMethod.trim().toLowerCase(),
      "location": location.trim().toLowerCase(),
    };

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("PREDICT RESPONSE: ${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception("Predict API failed: ${res.body}");
  }

  static Future<Map<String, dynamic>> getSurvivalStatus(String userId) async {
    final url = Uri.parse('$_baseUrl/survival_status/$userId');

    final res = await http.get(url);

    print("SURVIVAL RESPONSE: ${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception("Survival API failed: ${res.body}");
  }

  static Future<List<dynamic>> getAlternatives({
    required String userId,
    required String itemText,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/get_alternatives/$userId/${Uri.encodeComponent(itemText)}',
    );

    final res = await http.get(url);

    print("ALT RESPONSE: ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["alternatives"] ?? [];
    }

    throw Exception("Alternatives API failed: ${res.body}");
  }
}