/// Formats a number in Indian currency format (₹X,XX,XXX.XX)
String formatIndianCurrency(double amount) {
  final isNegative = amount < 0;
  amount = amount.abs();

  // Split into integer and decimal parts
  final parts = amount.toStringAsFixed(2).split('.');
  final integerPart = parts[0];
  final decimalPart = parts[1];

  // Apply Indian grouping: first group of 3 from right, then groups of 2
  final buffer = StringBuffer();
  final digits = integerPart.split('').reversed.toList();

  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  final formatted = buffer.toString().split('').reversed.join();
  final sign = isNegative ? '-' : '';
  return '$sign₹$formatted.$decimalPart';
}
