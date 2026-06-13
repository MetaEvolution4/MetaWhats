import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/message.dart';

class LocalDbDatasource {
  static final LocalDbDatasource _instance = LocalDbDatasource._internal();
  factory LocalDbDatasource() => _instance;
  LocalDbDatasource._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'metawhats_secure.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        conversationId TEXT,
        senderId TEXT,
        content TEXT,
        nonce TEXT,
        status TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert('messages', message.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => Message.fromJson(map)).toList();
  }
}
