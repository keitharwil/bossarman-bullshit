import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _pesoFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final NumberFormat _pesoWholeFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  /// Safely formats currency while guarding against NaN and Infinity crashes.
  static String currency(double amount, {bool showDecimals = true}) {
    final safeAmount = (amount.isNaN || amount.isInfinite) ? 0.0 : amount;
    return showDecimals
        ? _pesoFormat.format(safeAmount)
        : _pesoWholeFormat.format(safeAmount);
  }

  static String dateTimeShort(DateTime dt) {
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  static String timeOnly(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

class AppValidators {
  AppValidators._();

  static const int maxPartNameLength = 50;
  static const int maxSkuLength = 24;
  static const int maxBarcodeLength = 20;
  static const int maxStorageCoordLength = 20;
  static const int maxRiderNameLength = 50;
  static const int maxMotorcycleModelLength = 40;
  static const int maxPlateLength = 7;
  static const int maxServiceNotesLength = 250;

  static String? requiredField(
    String? value, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates Rider Full Name (3 to 50 characters, letters/spaces/hyphens/dots only).
  static String? riderFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Rider full name is required';
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return 'Rider full name must be at least 3 characters';
    }
    if (clean.length > maxRiderNameLength) {
      return 'Rider full name cannot exceed $maxRiderNameLength characters';
    }
    if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ\s\.\-']+$").hasMatch(clean)) {
      return 'Name can only contain letters, spaces, and hyphens';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(clean)) {
      return 'Name must contain at least one letter';
    }
    return null;
  }

  /// Validates First / Last Name for user registration.
  static String? name(String? value, [String fieldName = 'Name']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final clean = value.trim();
    if (clean.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (clean.length > 30) {
      return '$fieldName cannot exceed 30 characters';
    }
    if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ\s\.\-']+$").hasMatch(clean)) {
      return '$fieldName can only contain letters, spaces, or hyphens';
    }
    return null;
  }

  /// Validates Motorcycle Model (2 to 40 characters, alphanumeric).
  static String? motorcycleModel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Motorcycle model is required';
    }
    final clean = value.trim();
    if (clean.length < 2) {
      return 'Motorcycle model must be at least 2 characters';
    }
    if (clean.length > maxMotorcycleModelLength) {
      return 'Motorcycle model cannot exceed $maxMotorcycleModelLength characters';
    }
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(clean)) {
      return 'Motorcycle model must include letters or numbers';
    }
    return null;
  }

  /// Validates Philippine Mobile Number (Exactly 11 digits, numbers only, starts with 09).
  /// Allows input with hyphens/spaces but requires exactly 11 digits beginning with 09.
  static String? philippineMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final clean = value.trim();
    final digits = clean.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Mobile number must contain numbers only';
    }
    if (digits.length != 11) {
      return 'Mobile number must be exactly 11 digits (e.g. 09171234567)';
    }
    if (!digits.startsWith('09')) {
      return 'Mobile number must start with 09 (e.g. 09171234567)';
    }
    return null;
  }

  /// Validates Motorcycle Symptoms / Requested Work (descriptive sentence, 8 to 250 characters).
  static String? serviceNotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Service symptoms or notes are required';
    }
    final clean = value.trim();
    if (clean.length < 8) {
      return 'Please describe the symptoms in a brief sentence (min 8 characters)';
    }
    if (clean.length > maxServiceNotesLength) {
      return 'Description cannot exceed $maxServiceNotesLength characters';
    }
    return null;
  }

  /// Validates Part Name (3 to 50 characters, must include alphanumeric characters).
  static String? partName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Part name is required';
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return 'Part name must be at least 3 characters';
    }
    if (clean.length > maxPartNameLength) {
      return 'Part name cannot exceed $maxPartNameLength characters';
    }
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(clean)) {
      return 'Part name must include letters or numbers';
    }
    return null;
  }

  /// Validates SKU (3 to 24 characters, alphanumeric + hyphens/underscores/slashes, unique).
  static String? sku(String? value, {Iterable<String>? existingSkus}) {
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return 'SKU must be at least 3 characters';
    }
    if (clean.length > maxSkuLength) {
      return 'SKU cannot exceed $maxSkuLength characters';
    }
    if (!RegExp(r'^[A-Za-z0-9\-_/]+$').hasMatch(clean)) {
      return 'SKU can only use letters, numbers, -, _, or /';
    }
    if (existingSkus != null) {
      final upper = clean.toUpperCase();
      final isDuplicate = existingSkus.any(
        (s) => s.trim().toUpperCase() == upper,
      );
      if (isDuplicate) {
        return 'SKU "$upper" already exists in inventory';
      }
    }
    return null;
  }

  /// Validates Barcode (4 to 20 characters, alphanumeric or digits/hyphens, unique).
  static String? barcode(String? value, {Iterable<String>? existingBarcodes}) {
    if (value == null || value.trim().isEmpty) {
      return 'Barcode is required';
    }
    final clean = value.trim();
    if (clean.length < 4) {
      return 'Barcode must be at least 4 characters';
    }
    if (clean.length > maxBarcodeLength) {
      return 'Barcode cannot exceed $maxBarcodeLength characters';
    }
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(clean)) {
      return 'Barcode can only contain letters, digits, or -';
    }
    if (existingBarcodes != null) {
      final upper = clean.toUpperCase();
      final isDuplicate = existingBarcodes.any(
        (b) => b.trim().toUpperCase() == upper,
      );
      if (isDuplicate) {
        return 'Barcode "$clean" is already assigned to another part';
      }
    }
    return null;
  }

  /// Validates storage location coordinate (Rack / Shelf / Bin, 1 to 20 chars).
  static String? storageCoordinate(
    String? value, [
    String fieldName = 'Location',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final clean = value.trim();
    if (clean.length > maxStorageCoordLength) {
      return '$fieldName cannot exceed $maxStorageCoordLength chars';
    }
    return null;
  }

  static String? positiveQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid whole number';
    }
    if (parsed <= 0) {
      return 'Quantity must be greater than 0';
    }
    if (parsed > 99999) {
      return 'Quantity cannot exceed 99,999';
    }
    return null;
  }

  static String? nonNegativeInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Stock count is required';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid whole number';
    }
    if (parsed < 0) {
      return 'Negative quantities are not allowed';
    }
    if (parsed > 99999) {
      return 'Stock count cannot exceed 99,999';
    }
    return null;
  }

  /// Rejects null, empty, NaN, Infinity, or negative currency values.
  static String? positiveAmount(String? value, {bool allowZero = false}) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return 'Enter a valid numeric amount';
    }
    if (parsed < 0) {
      return 'Negative amount is not allowed';
    }
    if (!allowZero && parsed <= 0) {
      return 'Price must be greater than ₱0';
    }
    if (parsed > 1000000) {
      return 'Amount cannot exceed ₱1,000,000';
    }
    return null;
  }

  /// Validates Philippine LTO Motorcycle Plate format (maximum 7 characters)
  /// Examples: "412-NBO", "111-ABC", "ABC1234", "123-ABC", "FOR-REG", "ABC 123"
  static String? plateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Plate or MV File No. is required';
    }
    final clean = value.trim().toUpperCase();
    if (clean.length < 3) {
      return 'Plate number must be at least 3 characters';
    }
    if (clean.length > maxPlateLength) {
      return 'Plate number cannot exceed $maxPlateLength characters';
    }
    final regExp = RegExp(r'^[A-Z0-9]{2,4}[-\s]?[A-Z0-9]{2,4}$');
    if (!regExp.hasMatch(clean)) {
      return 'Invalid plate format (e.g., 412-NBO or ABC1234)';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final regExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 4) {
      return 'Username must be at least 4 characters';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
