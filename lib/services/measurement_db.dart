// lib/services/measurement_db.dart
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqffi;

import '../models/measurement.dart';

class MeasurementDB {
  static final MeasurementDB instance = MeasurementDB._();
  MeasurementDB._();

  sq.Database? _db;

  // Selecciona la factory correcta (FFI en desktop, normal en mobile)
  Future<void> _ensureFactory() async {
    if (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS) {
      sqffi.sqfliteFfiInit();
      sq.databaseFactory = sqffi.databaseFactoryFfi;
    }
    // En Android/iOS no hace falta cambiar la factory.
  }

  Future<sq.Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    await _ensureFactory();
    _db = await _initDB('measurements.db');
    return _db!;
  }

  Future<sq.Database> _initDB(String fileName) async {
    final dbPath = await sq.getDatabasesPath();
    final path = p.join(dbPath, fileName);
    return sq.openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(sq.Database db, int version) async {
    await db.execute('''
      CREATE TABLE measurements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        progresiva TEXT NOT NULL,
        ohm1m REAL NOT NULL,
        ohm3m REAL NOT NULL,
        observations TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        date INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insert(Measurement m) async {
    final database = await db;
    final map = Map<String, Object?>.from(m.toJson());
    if (map['date'] is DateTime) {
      map['date'] = (map['date'] as DateTime).millisecondsSinceEpoch;
    }
    return database.insert(
      'measurements',
      map,
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<List<Measurement>> getAll() async {
    final database = await db;
    final res = await database.query('measurements', orderBy: 'id ASC');
    return res.map((e) {
      final map = Map<String, Object?>.from(e);
      if (map['date'] is int) {
        map['date'] = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
      }
      return Measurement.fromJson(map);
    }).toList();
  }

  Future<int> update(Measurement m) async {
    if (m.id == null) {
      throw ArgumentError('Measurement sin id');
    }
    final database = await db;
    final map = Map<String, Object?>.from(m.toJson());
    if (map['date'] is DateTime) {
      map['date'] = (map['date'] as DateTime).millisecondsSinceEpoch;
    }
    return database.update(
      'measurements',
      map,
      where: 'id = ?',
      whereArgs: [m.id],
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(int id) async {
    final database = await db;
    return database.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
