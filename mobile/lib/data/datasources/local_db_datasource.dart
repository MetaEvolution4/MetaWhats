import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/message.dart';

class LocalDbDatasource {
  static final LocalDbDatasource _instance = LocalDbDatasource._internal();
  factory LocalDbDatasource() => _instance;
  LocalDbDatasource._internal();

  Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'metawhats_secure.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            conversation_id TEXT,
            sender_id TEXT,
            type TEXT,
            content TEXT,
            ciphertext TEXT,
            cipher_type INTEGER,
            reply_to_message_id TEXT,
            status TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE group_keys(
            group_id TEXT PRIMARY KEY,
            key_base64 TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE group_keys(
              group_id TEXT PRIMARY KEY,
              key_base64 TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN reply_to_message_id TEXT');
          } catch(e) {
            // Might already exist
          }
        }
      },
    );
  }

  Future<void> saveGroupKey(String groupId, String keyBase64) async {
    final db = await database;
    await db.insert('group_keys', {
      'group_id': groupId,
      'key_base64': keyBase64,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getGroupKey(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_keys',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (maps.isNotEmpty) {
      return maps.first['key_base64'] as String;
    }
    return null;
  }

  Future<void> insertMessage(Message message) async {
    final db = await database;
    if (db == null) return;
    await db.insert('messages', message.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    if (db == null) return [];
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromJson(map)).toList();
  }
}
