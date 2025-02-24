import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('my_app.db');
    return _database!;
  }

  Future<Database> _initDB(String dbName) async {
    // Get the path to the documents directory
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // If you need migrations
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1) Category Table
    await db.execute('''
      CREATE TABLE Category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        color TEXT,
        icon_color TEXT
      )
    ''');

    // 2) Transaction Table
    await db.execute('''
      CREATE TABLE "Transaction" (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        restaurant_name TEXT,
        date_time TEXT,
        total REAL,
        FOREIGN KEY (category_id) REFERENCES Category(id)
      )
    ''');

    // 3) OrderItem Table
    await db.execute('''
      CREATE TABLE OrderItem (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        name TEXT,
        price REAL,
        quantity INTEGER,
        FOREIGN KEY (transaction_id) REFERENCES "Transaction"(id)
      )
    ''');
  }

  // If you need migrations, define _onUpgrade:
  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // e.g. db.execute('ALTER TABLE ...');
  //   }
  // }

// Example usage
  final dbService = DatabaseService();

// Insert a category
  Future<void> insertCategory(
      String name, String color, String iconColor) async {
    final db = await dbService.database;
    await db.insert(
      'Category',
      {
        'name': name,
        'color': color,
        'icon_color': iconColor,
      },
    );
  }

// Query categories
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await dbService.database;
    return await db.query('Category');
  }

// Example of a join query
  Future<List<Map<String, dynamic>>> getTransactionsWithCategory() async {
    final db = await dbService.database;
    final result = await db.rawQuery('''
    SELECT t.id, t.restaurant_name, t.date_time, t.total,
           c.name as category_name, c.color as category_color
    FROM "Transaction" t
    JOIN Category c ON t.category_id = c.id
    ORDER BY t.id DESC
  ''');
    return result;
  }

  // Close the database
  Future close() async {
    final db = await database;
    db.close();
  }
}
