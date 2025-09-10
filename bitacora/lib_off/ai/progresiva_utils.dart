class Progresiva {
  Progresiva(this.km, this.plus);
  final int km;
  final int plus;

  @override
  String toString() => 'PK $km+${plus.toString().padLeft(3, '0')}';

  static Progresiva? parse(String s) {
    final r = RegExp(r'^\s*PK\s*(\d+)\+(\d+)\s*$', caseSensitive: false);
    final m = r.firstMatch(s);
    if (m == null) return null;
    return Progresiva(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  Progresiva next([int step = 100]) => Progresiva(km, plus + step);
}
