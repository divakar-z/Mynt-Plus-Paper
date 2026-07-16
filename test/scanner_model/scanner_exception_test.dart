import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/scanner_model/scanner_exception.dart';

void main() {
  group('StockScannerException.fromResponse', () {
    test('401 → authentication message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 401,
        backendMessage: 'no key',
      );
      expect(e.message, contains('Authentication required'));
      expect(e.statusCode, 401);
    });

    test('404 with backend message → prefixed message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 404,
        backendMessage: 'symbol ABC not found',
      );
      expect(e.message, 'Not found — symbol ABC not found');
    });

    test('422 → invalid input message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 422,
        backendMessage: 'field "x" required',
      );
      expect(e.message, contains('Invalid input'));
      expect(e.message, contains('field "x" required'));
    });

    test('429 → rate-limit message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 429,
        backendMessage: '',
      );
      expect(e.message, contains('Rate limit'));
    });

    test('5xx → generic backend-error message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 503,
        backendMessage: 'gateway',
      );
      expect(e.message, contains('Backend error'));
    });

    test('network factory yields status 0', () {
      final e = StockScannerException.network(Exception('boom'));
      expect(e.statusCode, 0);
      expect(e.message, contains('Could not reach'));
    });
  });
}
