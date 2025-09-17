// Gridnote ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· MultiLocationAI (Median + Weighted + Kalman + Particle) ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 2025-09
// Local, sin dependencias extra. Filtro robusto, suavizado y fusiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.
// Null-safe. Evita (0,0). Compatible con Dart 3.x.

import 'dart:math' as math;

class AIMultiConfig {
  final double targetAccuracyMeters;
  final double outlierMadK;
  final double minAcceptableAcc;
  final int maxWindow;
  final double recencyHalfLifeSec;
  final int particleCount;

  const AIMultiConfig({
    this.targetAccuracyMeters = 20.0,
    this.outlierMadK = 3.5,
    this.minAcceptableAcc = 25.0,
    this.maxWindow = 48,
    this.recencyHalfLifeSec = 30.0,
    this.particleCount = 120,
  });
}

class RawSample {
  final double lat;
  final double lon;
  final double acc; // 1-sigma (m)
  final DateTime ts;
  const RawSample({
    required this.lat,
    required this.lon,
    required this.acc,
    required this.ts,
  });
}

class AIReturn {
  final double latitude;
  final double longitude;
  final double accuracyMeters; // sigma
  final int used;
  final int dropped;
  final double confidence; // 0..1
  const AIReturn({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.used,
    required this.dropped,
    required this.confidence,
  });
}

class MultiLocationAI {
  MultiLocationAI(this.cfg);

  final AIMultiConfig cfg;
  final List<RawSample> _buf = [];

  double? _lat0;
  double? _lon0;

  static const double _rEarth = 6378137.0; // WGS84 (m)
  static const double _deg2rad = math.pi / 180.0;
  static const double _rad2deg = 180.0 / math.pi;

  void push(RawSample s) {
    if (_buf.length >= cfg.maxWindow) _buf.removeAt(0);
    _buf.add(s);
    _lat0 ??= s.lat;
    _lon0 ??= s.lon;
  }

  bool get hasData => _buf.isNotEmpty;

  AIReturn? solve() {
    if (_buf.isEmpty) return null;

    // --- ProyecciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n local ENU
    final lat0 = _lat0!;
    final lon0 = _lon0!;
    final cosLat0 = math.cos(lat0 * _deg2rad);
    final now = _buf.last.ts;

    final enu = _buf.map((s) {
      final dx = (s.lon - lon0) * _deg2rad * _rEarth * cosLat0;
      final dy = (s.lat - lat0) * _deg2rad * _rEarth;
      final acc = (s.acc.isFinite && s.acc > 0) ? s.acc : cfg.minAcceptableAcc;
      final age = now.difference(s.ts).inMilliseconds / 1000.0;
      return _ENUSample(dx: dx, dy: dy, acc: acc, ts: s.ts, ageSec: age);
    }).toList();

    // --- Outliers por MAD
    final mx = _median(enu.map((e) => e.dx).toList());
    final my = _median(enu.map((e) => e.dy).toList());
    final dists = enu.map((e) => _hypot(e.dx - mx, e.dy - my)).toList();
    final medD = _median(dists);
    final mad = _median(dists.map((d) => (d - medD).abs()).toList());
    final madScaled = mad * 1.4826; // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€¹Ã¢â‚¬  ÃƒÆ’Ã‚ÂÃƒâ€ Ã¢â‚¬â„¢
    final cutoff = (madScaled.isFinite && madScaled > 0)
        ? math.max(cfg.outlierMadK * madScaled, cfg.targetAccuracyMeters * 1.5)
        : cfg.targetAccuracyMeters * 3;

    final kept = <_ENUSample>[];
    int dropped = 0;
    for (final s in enu) {
      final dist = _hypot(s.dx - mx, s.dy - my);
      if (dist <= cutoff) {
        kept.add(s);
      } else {
        dropped++;
      }
    }
    if (kept.isEmpty) {
      enu.sort((a, b) => _hypot(a.dx - mx, a.dy - my)
          .compareTo(_hypot(b.dx - mx, b.dy - my)));
      kept.addAll(enu.take(math.min(3, enu.length)));
      dropped = math.max(0, enu.length - kept.length);
    }

    // --- Estimadores en paralelo
    final ests = <_Estimate>[];
    final eMedian = _estimateMedian(kept);
    if (eMedian != null) ests.add(eMedian);
    final eWeighted = _estimateWeighted(kept, halfLife: cfg.recencyHalfLifeSec);
    if (eWeighted != null) ests.add(eWeighted);
    final eKalman = _estimateKalman(kept);
    if (eKalman != null) ests.add(eKalman);
    final eParticle = _estimateParticle(kept, cfg.particleCount);
    if (eParticle != null) ests.add(eParticle);
    if (ests.isEmpty) return null;

    // --- FusiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n por varianza inversa (mejores 2)
    ests.sort((a, b) => a.sigma.compareTo(b.sigma));
    final top = ests.take(math.min(2, ests.length)).toList();
    double wsum = 0, wx = 0, wy = 0;
    for (final e in top) {
      final w = (e.sigma > 0) ? 1.0 / (e.sigma * e.sigma) : 1.0;
      wx += e.x * w;
      wy += e.y * w;
      wsum += w;
    }
    final fx = wx / (wsum == 0 ? 1 : wsum);
    final fy = wy / (wsum == 0 ? 1 : wsum);
    final fusedSigma = 1.0 / math.sqrt(wsum == 0 ? 1 : wsum);

    // --- Confianza
    final spread = ests.map((e) => _hypot(e.x - fx, e.y - fy)).toList();
    final medSpread = _median(spread);
    final confA = _confFromAcc(fusedSigma);
    final confB =
        1.0 - (medSpread / (cfg.targetAccuracyMeters * 4)).clamp(0.0, 1.0);
    final conf = ((confA + confB) * 0.5).clamp(0.0, 1.0);

    // --- ReproyecciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n a lat/lon
    final lat = (fy / _rEarth) * _rad2deg + lat0;
    final lon = (fx / (_rEarth * cosLat0)) * _rad2deg + lon0;

    return AIReturn(
      latitude: lat,
      longitude: lon,
      accuracyMeters: fusedSigma,
      used: kept.length,
      dropped: dropped,
      confidence: conf,
    );
  }

  // ----------------- Estimadores -----------------

  _Estimate? _estimateMedian(List<_ENUSample> s) {
    if (s.isEmpty) return null;
    final xs = s.map((e) => e.dx).toList()..sort();
    final ys = s.map((e) => e.dy).toList()..sort();
    final x = xs.length.isOdd
        ? xs[xs.length >> 1]
        : 0.5 * (xs[(xs.length >> 1) - 1] + xs[xs.length >> 1]);
    final y = ys.length.isOdd
        ? ys[ys.length >> 1]
        : 0.5 * (ys[(ys.length >> 1) - 1] + ys[ys.length >> 1]);
    final d = s.map((e) => _hypot(e.dx - x, e.dy - y)).toList()..sort();
    final sigma = (_median(d) * 1.4826).clamp(1.0, 500.0);
    return _Estimate(x: x, y: y, sigma: sigma);
  }

  _Estimate? _estimateWeighted(List<_ENUSample> s, {required double halfLife}) {
    if (s.isEmpty) return null;
    final lambda = math.log(2) / math.max(1e-3, halfLife);
    double wsum = 0, wx = 0, wy = 0;
    for (final e in s) {
      final wAcc = 1.0 / (e.acc * e.acc);
      final wTime = math.exp(-lambda * e.ageSec);
      final w = wAcc * wTime;
      wx += e.dx * w;
      wy += e.dy * w;
      wsum += w;
    }
    if (wsum == 0) return null;
    final x = wx / wsum, y = wy / wsum;

    double variance = 0;
    for (final e in s) {
      final wAcc = 1.0 / (e.acc * e.acc);
      final wTime = math.exp(-lambda * e.ageSec);
      final w = wAcc * wTime;
      final dr = _hypot(e.dx - x, e.dy - y);
      variance += w * dr * dr;
    }
    variance = variance / wsum;
    final sigma = math.sqrt(variance).clamp(1.0, 500.0);
    return _Estimate(x: x, y: y, sigma: sigma);
  }

  _Estimate? _estimateKalman(List<_ENUSample> s) {
    if (s.isEmpty) return null;
    s.sort((a, b) => a.ts.compareTo(b.ts));
    final kf = _Kalman2D();
    _KState? st;
    DateTime? last;

    for (final e in s) {
      final dt =
      last == null ? 0.0 : (e.ts.difference(last!).inMilliseconds / 1000.0);
      last = e.ts;
      if (st == null) {
        st = kf.init(x: e.dx, y: e.dy, vx: 0, vy: 0, measSigma: e.acc);
      } else {
        st = kf.predict(st, dt: dt);
        st = kf.update(st, measX: e.dx, measY: e.dy, measSigma: e.acc);
      }
    }
    if (st == null) return null;
    final sigma = math
        .sqrt(math.max(0.0, st.P[0][0] + st.P[1][1]))
        .clamp(1.0, 500.0);
    return _Estimate(x: st.x, y: st.y, sigma: sigma);
  }

  _Estimate? _estimateParticle(List<_ENUSample> s, int n) {
    if (s.isEmpty) return null;
    final rand = math.Random(7);

    final med = _estimateMedian(s)!;
    final ps = <_Particle>[];
    for (var i = 0; i < n; i++) {
      ps.add(_Particle(
        x: med.x + _gauss(rand, 0, med.sigma),
        y: med.y + _gauss(rand, 0, med.sigma),
        vx: 0,
        vy: 0,
        w: 1.0 / n,
      ));
    }

    DateTime? last;
    for (final e in s) {
      final dt =
      last == null ? 0.0 : (e.ts.difference(last!).inMilliseconds / 1000.0);
      last = e.ts;

      // PredicciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n
      for (final p in ps) {
        p.x += p.vx * dt + _gauss(rand, 0, 0.5);
        p.y += p.vy * dt + _gauss(rand, 0, 0.5);
        p.vx += _gauss(rand, 0, 0.2);
        p.vy += _gauss(rand, 0, 0.2);
      }

      // PonderaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n por distancia a mediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n
      final varMeas = e.acc * e.acc;
      double wsum = 0;
      for (final p in ps) {
        final dx = p.x - e.dx, dy = p.y - e.dy;
        final r2 = dx * dx + dy * dy;
        final w = math.exp(-0.5 * (r2 / (varMeas + 1e-6)));
        p.w = w;
        wsum += w;
      }
      if (wsum == 0) {
        for (final p in ps) {
          p.w = 1.0 / n;
        }
      } else {
        for (final p in ps) {
          p.w /= wsum;
        }
      }

      // Re-muestreo estratificado
      final cumulative = <double>[];
      double c = 0;
      for (final p in ps) {
        c += p.w;
        cumulative.add(c);
      }
      final newPs = <_Particle>[];
      final step = 1.0 / n;
      double u = rand.nextDouble() * step;
      int idx = 0;
      for (var i = 0; i < n; i++) {
        while (u > cumulative[idx]) {
          idx++;
        }
        final q = ps[idx];
        newPs.add(_Particle(x: q.x, y: q.y, vx: q.vx, vy: q.vy, w: 1.0 / n));
        u += step;
      }
      ps
        ..clear()
        ..addAll(newPs);
    }

    // Media ponderada y varianza
    double wsum = 0, mx = 0, my = 0;
    for (final p in ps) {
      mx += p.x * p.w;
      my += p.y * p.w;
      wsum += p.w;
    }
    final meanX = mx / (wsum == 0 ? 1 : wsum);
    final meanY = my / (wsum == 0 ? 1 : wsum);

    double variance = 0;
    for (final p in ps) {
      final dx = p.x - meanX, dy = p.y - meanY;
      variance += p.w * (dx * dx + dy * dy);
    }
    final sigma = math.sqrt(variance / (wsum == 0 ? 1 : wsum)).clamp(1.0, 500.0);

    return _Estimate(x: meanX, y: meanY, sigma: sigma);
  }

  // ----------------- Utils -----------------

  static double _median(List<double> v) {
    if (v.isEmpty) return 0;
    v.sort();
    final n = v.length;
    if (n.isOdd) return v[n >> 1];
    return 0.5 * (v[(n >> 1) - 1] + v[n >> 1]);
  }

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);

  static double _gauss(math.Random r, double mu, double sigma) {
    // Box-Muller
    double u1 = 0, u2 = 0;
    while (u1 == 0) {
      u1 = r.nextDouble();
    }
    while (u2 == 0) {
      u2 = r.nextDouble();
    }
    final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    return mu + z0 * sigma;
  }

  double _confFromAcc(double sigmaMeters) {
    final a = sigmaMeters.clamp(1.0, 100.0);
    return (100.0 - a) / 99.0;
  }
}

// ----------------- Tipos internos -----------------

class _ENUSample {
  final double dx;
  final double dy;
  final double acc;
  final DateTime ts;
  final double ageSec;
  const _ENUSample({
    required this.dx,
    required this.dy,
    required this.acc,
    required this.ts,
    required this.ageSec,
  });
}

class _Estimate {
  final double x;
  final double y;
  final double sigma;
  const _Estimate({required this.x, required this.y, required this.sigma});
}

class _Particle {
  double x, y, vx, vy, w;
  _Particle({required this.x, required this.y, required this.vx, required this.vy, required this.w});
}

// ---- Kalman 2D mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo ----
class _KState {
  final double x, y, vx, vy;
  final List<List<double>> P;
  const _KState({required this.x, required this.y, required this.vx, required this.vy, required this.P});
}

class _Kalman2D {
  final double qAccel;
  const _Kalman2D({this.qAccel = 1.0});

  _KState init({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double measSigma,
  }) {
    final p = _eye(4, diag: math.max(1.0, measSigma * measSigma));
    return _KState(x: x, y: y, vx: vx, vy: vy, P: p);
  }

  _KState predict(_KState s, {required double dt}) {
    final double dt2 = dt * dt;
    final f = <List<double>>[
      [1.0, 0.0, dt,  0.0],
      [0.0, 1.0, 0.0, dt  ],
      [0.0, 0.0, 1.0, 0.0 ],
      [0.0, 0.0, 0.0, 1.0 ],
    ];
    final q = <List<double>>[
      [0.25 * dt2 * dt2 * qAccel, 0.0,                   0.5 * dt2 * qAccel,       0.0],
      [0.0,                   0.25 * dt2 * dt2 * qAccel, 0.0,                      0.5 * dt2 * qAccel],
      [0.5 * dt2 * qAccel,    0.0,                       dt * qAccel,              0.0],
      [0.0,                   0.5 * dt2 * qAccel,        0.0,                      dt * qAccel],
    ];

    final xPred = s.x + s.vx * dt;
    final yPred = s.y + s.vy * dt;
    final vxPred = s.vx;
    final vyPred = s.vy;

    final p1 = _matAdd(_matMul(_matMul(f, s.P), _transpose(f)), q);
    return _KState(x: xPred, y: yPred, vx: vxPred, vy: vyPred, P: p1);
  }

  _KState update(_KState s, {required double measX, required double measY, required double measSigma}) {
    final h = <List<double>>[
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
    ];
    final r = <List<double>>[
      [measSigma * measSigma, 0.0],
      [0.0, measSigma * measSigma],
    ];
    final z = <List<double>>[
      [measX],
      [measY],
    ];
    final xVec = <List<double>>[
      [s.x],
      [s.y],
      [s.vx],
      [s.vy],
    ];

    final y = _matSub(z, _matMul(h, xVec));
    final sMat = _matAdd(_matMul(_matMul(h, s.P), _transpose(h)), r);
    final k = _matMul(_matMul(s.P, _transpose(h)), _inv2x2(sMat));

    final xNew = _matAdd(xVec, _matMul(k, y));
    final i = _eye(4);
    final pNew = _matMul(_matSub(i, _matMul(k, h)), s.P);

    return _KState(
      x: xNew[0][0],
      y: xNew[1][0],
      vx: xNew[2][0],
      vy: xNew[3][0],
      P: pNew,
    );
  }

  // --- helpers de matrices pequeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±as ---
  static List<List<double>> _eye(int n, {double diag = 1.0}) {
    final m = List.generate(n, (_) => List.filled(n, 0.0));
    for (var i = 0; i < n; i++) {
      m[i][i] = diag;
    }
    return m;
  }

  static List<List<double>> _transpose(List<List<double>> a) {
    final r = List.generate(a[0].length, (_) => List.filled(a.length, 0.0));
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < a[0].length; j++) {
        r[j][i] = a[i][j];
      }
    }
    return r;
  }

  static List<List<double>> _matMul(List<List<double>> a, List<List<double>> b) {
    final n = a.length, m = b[0].length, k = b.length;
    final r = List.generate(n, (_) => List.filled(m, 0.0));
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < m; j++) {
        var sum = 0.0;
        for (var t = 0; t < k; t++) {
          sum += a[i][t] * b[t][j];
        }
        r[i][j] = sum;
      }
    }
    return r;
  }

  static List<List<double>> _matAdd(List<List<double>> a, List<List<double>> b) {
    final r = List.generate(a.length, (i) =>
        List.generate(a[0].length, (j) => a[i][j] + b[i][j]));
    return r;
  }

  static List<List<double>> _matSub(List<List<double>> a, List<List<double>> b) {
    final r = List.generate(a.length, (i) =>
        List.generate(a[0].length, (j) => a[i][j] - b[i][j]));
    return r;
  }

  static List<List<double>> _inv2x2(List<List<double>> m) {
    final a = m[0][0], b = m[0][1], c = m[1][0], d = m[1][1];
    final det = a * d - b * c;
    final invDet = det != 0 ? 1.0 / det : 0.0;
    return [
      [ d * invDet, -b * invDet],
      [-c * invDet,  a * invDet],
    ];
  }
}
