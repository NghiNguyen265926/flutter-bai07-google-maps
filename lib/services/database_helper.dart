import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/favorite_route.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final folder = await getDatabasesPath();
    final path = join(folder, 'bai07_maps.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorite_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start TEXT NOT NULL,
            destination TEXT NOT NULL,
            mode TEXT NOT NULL,
            distance TEXT NOT NULL,
            duration TEXT NOT NULL,
            start_lat REAL NOT NULL,
            start_lng REAL NOT NULL,
            end_lat REAL NOT NULL,
            end_lng REAL NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertFavorite(FavoriteRoute route) async {
    final db = await database;
    return db.insert('favorite_routes', route.toMap());
  }

  Future<List<FavoriteRoute>> getFavorites() async {
    final db = await database;
    final rows = await db.query(
      'favorite_routes',
      orderBy: 'id DESC',
    );
    return rows.map(FavoriteRoute.fromMap).toList();
  }

  Future<int> deleteFavorite(int id) async {
    final db = await database;
    return db.delete(
      'favorite_routes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
