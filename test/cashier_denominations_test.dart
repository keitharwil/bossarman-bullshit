import 'package:flutter_test/flutter_test.dart';
import 'package:boss_arman_motohub/views/cashier/cashier_shell_screen.dart';

void main() {
  group('Cashier Greedy Denominations Calculator Tests', () {
    test('Expected 0 -> all denominations are 0', () {
      final counts = calculateGreedyDenominations(0);
      expect(counts, {
        1000: 0,
        500: 0,
        200: 0,
        100: 0,
        50: 0,
        20: 0,
        10: 0,
        5: 0,
        1: 0,
      });
      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 0);
    });

    test('Expected 49 -> 2x₱20 + 1x₱5 + 4x₱1 (total ₱49, remainder 0)', () {
      final counts = calculateGreedyDenominations(49);
      expect(counts[1000], 0);
      expect(counts[500], 0);
      expect(counts[200], 0);
      expect(counts[100], 0);
      expect(counts[50], 0);
      expect(counts[20], 2);
      expect(counts[10], 0);
      expect(counts[5], 1);
      expect(counts[1], 4);

      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 49);
    });

    test('Expected 50 -> 1x₱50 (total ₱50, remainder 0)', () {
      final counts = calculateGreedyDenominations(50);
      expect(counts[50], 1);
      expect(counts[1000], 0);
      expect(counts[500], 0);
      expect(counts[200], 0);
      expect(counts[100], 0);
      expect(counts[20], 0);
      expect(counts[10], 0);
      expect(counts[5], 0);
      expect(counts[1], 0);

      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 50);
    });

    test('Expected 1275 -> 1x₱1000 + 1x₱200 + 1x₱50 + 1x₱20 + 1x₱5 (total ₱1275, remainder 0)', () {
      final counts = calculateGreedyDenominations(1275);
      expect(counts[1000], 1);
      expect(counts[500], 0);
      expect(counts[200], 1);
      expect(counts[100], 0);
      expect(counts[50], 1);
      expect(counts[20], 1);
      expect(counts[10], 0);
      expect(counts[5], 1);
      expect(counts[1], 0);

      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 1275);
    });

    test('Expected 18,659 -> 18x₱1000 + 1x₱500 + 1x₱100 + 1x₱50 + 1x₱5 + 4x₱1 (total ₱18659, remainder 0)', () {
      final counts = calculateGreedyDenominations(18659);
      expect(counts[1000], 18);
      expect(counts[500], 1);
      expect(counts[200], 0);
      expect(counts[100], 1);
      expect(counts[50], 1);
      expect(counts[20], 0);
      expect(counts[10], 0);
      expect(counts[5], 1);
      expect(counts[1], 4);

      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 18659);
    });

    test('Negative value (e.g. -500.50) -> treated as 0 (all counts 0)', () {
      final counts = calculateGreedyDenominations(-500.50);
      expect(counts, {
        1000: 0,
        500: 0,
        200: 0,
        100: 0,
        50: 0,
        20: 0,
        10: 0,
        5: 0,
        1: 0,
      });
      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 0);
    });

    test('Value with centavos (e.g. 1275.85) -> centavos ignored, whole pesos matched exactly', () {
      final counts = calculateGreedyDenominations(1275.85);
      final total = counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value);
      expect(total, 1275);
      expect(1275.85.toInt() - total, 0);
    });
  });
}

