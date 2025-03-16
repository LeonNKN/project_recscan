import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart' show OrderItem;

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  DatabaseService._internal();

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
        subtotal REAL,
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

    // Initialize default categories
    await _initializeDefaultCategories(db);
  }

  Future<void> _initializeDefaultCategories(Database db) async {
    final defaultCategories = [
      {
        'name': 'Food & Beverage',
        'color': '0xFF2196F3',
        'icon_color': '0xFFE91E63'
      },
      {'name': 'Groceries', 'color': '0xFF4CAF50', 'icon_color': '0xFFE91E63'},
      {'name': 'Shopping', 'color': '0xFFFFC107', 'icon_color': '0xFFE91E63'},
      {'name': 'Others', 'color': '0xFF9E9E9E', 'icon_color': '0xFFE91E63'},
    ];

    for (final category in defaultCategories) {
      await db.insert('Category', category);
    }
  }

  // If you need migrations, define _onUpgrade:
  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // e.g. db.execute('ALTER TABLE ...');
  //   }
  // }

  Future<void> insertCategory(
      String name, String color, String iconColor) async {
    final db = await database;
    await db.insert(
      'Category',
      {
        'name': name,
        'color': color,
        'icon_color': iconColor,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    debugPrint('Executing categories query...');
    final result = await db.query('Category');
    debugPrint('Query returned ${result.length} categories');
    return result;
  }

  Future<List<Map<String, dynamic>>> getTransactionsWithCategory() async {
    final db = await database;
    debugPrint('Executing transaction query...');
    final result = await db.rawQuery('''
    SELECT t.id, t.restaurant_name, t.date_time, t.subtotal, t.total,
           c.name as category_name, c.color as category_color, c.icon_color
    FROM "Transaction" t
    JOIN Category c ON t.category_id = c.id
    ORDER BY t.date_time DESC
  ''');
    debugPrint('Query returned ${result.length} transactions');
    return result;
  }

  Future<int> insertTransaction({
    required int categoryId,
    required String restaurantName,
    required DateTime dateTime,
    required double subtotal,
    required double total,
  }) async {
    final db = await database;
    return await db.insert(
      'Transaction',
      {
        'category_id': categoryId,
        'restaurant_name': restaurantName,
        'date_time': dateTime.toIso8601String(),
        'subtotal': subtotal,
        'total': total,
      },
    );
  }

  Future<void> insertOrderItem({
    required int transactionId,
    required String name,
    required double price,
    required int quantity,
  }) async {
    final db = await database;
    await db.insert(
      'OrderItem',
      {
        'transaction_id': transactionId,
        'name': name,
        'price': price,
        'quantity': quantity,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getOrderItemsForTransaction(
      int transactionId) async {
    final db = await database;
    debugPrint('Getting order items for transaction $transactionId');
    final result = await db.query(
      'OrderItem',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    debugPrint('Found ${result.length} order items');
    return result;
  }

  // Delete a transaction and its associated order items
  Future<void> deleteTransaction(int transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      debugPrint('Deleting order items for transaction $transactionId');
      // Delete associated order items first
      await txn.delete(
        'OrderItem',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      debugPrint('Deleting transaction $transactionId');
      // Delete the transaction
      await txn.delete(
        'Transaction',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
    debugPrint('Transaction and associated items deleted successfully');
  }

  // Update transaction details
  Future<void> updateTransaction({
    required int id,
    required int categoryId,
    required String restaurantName,
    required DateTime dateTime,
    required double subtotal,
    required double total,
  }) async {
    final db = await database;
    await db.update(
      'Transaction',
      {
        'category_id': categoryId,
        'restaurant_name': restaurantName,
        'date_time': dateTime.toIso8601String(),
        'subtotal': subtotal,
        'total': total,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Transaction $id updated successfully');
  }

  // Update order items for a transaction
  Future<void> updateOrderItems({
    required int transactionId,
    required List<OrderItem> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      debugPrint('Updating order items for transaction $transactionId');

      // Delete existing items
      await txn.delete(
        'OrderItem',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      // Insert new items
      for (final item in items) {
        await txn.insert(
          'OrderItem',
          {
            'transaction_id': transactionId,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          },
        );
      }
    });
    debugPrint(
        'Updated ${items.length} order items for transaction $transactionId');
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
