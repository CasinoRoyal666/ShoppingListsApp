import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _budgetLimitKey = 'budget_limit_';

  // Сохранение лимита бюджета
  static Future<void> saveBudgetLimit(String period, double limit) async {
    try {
      await _storage.write(
        key: '$_budgetLimitKey$period',
        value: limit.toString(),
      );
    } catch (e) {
      print('Ошибка при сохранении лимита бюджета: $e');
    }
  }
  static Future<double?> getBudgetLimit(String period) async {
    try {
      final value = await _storage.read(key: '$_budgetLimitKey$period');
      return value != null ? double.parse(value) : null;
    } catch (e) {
      print('Ошибка при получении лимита бюджета: $e');
      return null;
    }
  }

  // Удаление лимита бюджета
  static Future<void> deleteBudgetLimit(String period) async {
    try {
      await _storage.delete(key: '$_budgetLimitKey$period');
    } catch (e) {
      print('Ошибка при удалении лимита бюджета: $e');
    }
  }
} 