class Validators {
  static String? notEmpty(String? value, {String msg = 'Campo obligatorio'}) {
    if (value == null || value.trim().isEmpty) return msg;
    return null;
  }

  static String? isDouble(String? value, {String msg = 'Valor invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido'}) {
    if (value == null || value.trim().isEmpty) return null;
    final val = double.tryParse(value.replaceAll(',', '.'));
    if (val == null) return msg;
    return null;
  }

  static String? minValue(double min, String? value,
      {String msg = 'Valor bajo'}) {
    if (value == null) return null;
    final val = double.tryParse(value.replaceAll(',', '.'));
    if (val != null && val < min) return msg;
    return null;
  }
}
