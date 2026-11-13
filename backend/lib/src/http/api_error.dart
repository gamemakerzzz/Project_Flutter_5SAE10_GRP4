class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);
  final int status;
  final String code, message;
  Map<String, Object> toJson() => {
    'status': status,
    'code': code,
    'message': message,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };
}

String field(
  Map<String, dynamic> data,
  String name, {
  int max = 200,
  bool optional = false,
}) {
  final value = data[name];
  if (optional && value == null) return '';
  if (value is! String ||
      (!optional && value.trim().isEmpty) ||
      value.length > max) {
    throw ApiError(400, 'VALIDATION_ERROR', 'Invalid $name.');
  }
  return value.trim();
}
