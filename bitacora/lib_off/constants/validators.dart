class Validators {
  static String? notEmpty(String? value, {String? msg}) {
    if (value == null || value.trim().isEmpty) {
      return msg ?? 'Este campo es obligatorio';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? msg}) {
    if (value == null || value.length < min) {
      return msg ?? 'MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo $min caracteres';
    }
    return null;
  }

  // Ejemplo: solo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros
  static String? isNumeric(String? value, {String? msg}) {
    if (value == null || value.isEmpty) return null;
    final reg = RegExp(r'^\d+$');
    if (!reg.hasMatch(value)) return msg ?? 'Solo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros';
    return null;
  }
}
