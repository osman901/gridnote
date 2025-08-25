// lib/services/measurement_rest_repository.dart
import 'package:dio/dio.dart';
import '../models/measurement.dart';
import '../state/measurement_repository.dart';

class MeasurementRestRepository implements MeasurementRepository {
  MeasurementRestRepository({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final Dio _dio;
  final String _baseUrl;

  String get _endpoint => '$_baseUrl/measurements';

  @override
  Future<List<Measurement>> fetchAll() async {
    final res = await _dio.get(_endpoint);
    final data = res.data as List<dynamic>;
    return data
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Measurement> add(Measurement item) async {
    final res = await _dio.post(_endpoint, data: _toJson(item));
    return _fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<Measurement> update(Measurement item) async {
    final id = item.id;
    if (id == null) {
      return add(item);
    }
    final res = await _dio.put('$_endpoint/$id', data: _toJson(item));
    return _fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> delete(Measurement item) async {
    final id = item.id;
    if (id == null) return;
    await _dio.delete('$_endpoint/$id');
  }

  /// Requisito de `MeasurementRepository`.
  @override
  Future<void> saveMany(List<Measurement> items) async {
    // Ajustá el path si tu API usa otro endpoint para operaciones masivas.
    await _dio.put('$_endpoint/bulk', data: items.map(_toJson).toList());
  }

  /// Compat: si en alguna parte del código llaman `saveAll`, delegamos.
  Future<void> saveAll(List<Measurement> items) => saveMany(items);

  // ---------- JSON mappers (ajustá llaves según tu API) ----------

  Map<String, dynamic> _toJson(Measurement m) => <String, dynamic>{
    'id': m.id,
    'progresiva': m.progresiva,
    'ohm1m': m.ohm1m,
    'ohm3m': m.ohm3m,
    'observations': m.observations,
    'date': m.date.toIso8601String(),
    'latitude': m.latitude,
    'longitude': m.longitude,
  };

  Measurement _fromJson(Map<String, dynamic> j) {
    return Measurement(
      id: j['id'] as int?,
      progresiva: (j['progresiva'] ?? '').toString(),
      ohm1m: (j['ohm1m'] as num?)?.toDouble() ?? 0.0,
      ohm3m: (j['ohm3m'] as num?)?.toDouble() ?? 0.0,
      observations: (j['observations'] ?? '').toString(),
      date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
    );
  }
}
