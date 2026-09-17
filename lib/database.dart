import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// ═══════════════════════════════════════════════════════════════
/// DatabaseService
/// طبقة وصول عامة لقاعدة بيانات SQLite (sqflite) — مشتركة بين كل
/// الـ Controllers (Products / Customers / Invoices).
/// لا تحتوي منطق عمل (Business Logic)، فقط عمليات CRUD عامة +
/// إنشاء/ترقية الجداول.
/// ═══════════════════════════════════════════════════════════════
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _db;

  DatabaseService._init();

  // كل تعديل على شكل الجداول لازم يرفع هذا الرقم + إضافة خطوة ترقية
  // بالأسفل في _upgradeDB حتى لا تنكسر نسخة المستخدم القديمة.
  static const int _dbVersion = 3;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('store.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        min_alert INTEGER NOT NULL DEFAULT 5,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT NOT NULL DEFAULT 'عميل نقدي',
        total REAL NOT NULL,
        cost REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'نقدي',
        payment_status TEXT NOT NULL DEFAULT 'paid',
        paid_amount REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER,
        name TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_invoices_status ON invoices (payment_status)');
    await db.execute(
        'CREATE INDEX idx_invoices_customer ON invoices (customer_id)');

    await _createV3Tables(db);
  }

  /// جدول سجل الدفعات + جدول الإعدادات (مثل بيانات SMTP) + الفهارس
  /// الإضافية. مُستخرَج في دالة مستقلة حتى يُستخدَم من onCreate مباشرة
  /// (قاعدة جديدة) ومن _upgradeDB (قاعدة قديمة تُرقَّى) بدون تكرار.
  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        customer_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'نقدي',
        payment_date TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        notes TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments (invoice_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_customer ON payments (customer_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers (phone)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_email ON customers (email)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products (barcode)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_created ON invoices (created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoice_items_product ON invoice_items (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items (invoice_id)');
  }

  /// يُنفَّذ تلقائياً عند فتح قاعدة بيانات بنسخة أقدم — يضيف الجداول
  /// والأعمدة الجديدة دون حذف بيانات المستخدم الحالية.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // كانت النسخة الأولى تحتوي فقط products + invoices (بدون عملاء
      // ولا حالة دفع) — هذه الخطوة تكمّل الجداول والأعمدة الناقصة.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          notes TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
        )
      ''');

      final invoiceCols =
          (await db.rawQuery('PRAGMA table_info(invoices)'))
              .map((c) => c['name'] as String)
              .toSet();

      Future<void> addCol(String def) async {
        final colName = def.split(' ').first;
        if (!invoiceCols.contains(colName)) {
          await db.execute('ALTER TABLE invoices ADD COLUMN $def');
        }
      }

      await addCol('customer_id INTEGER');
      await addCol("customer_name TEXT NOT NULL DEFAULT 'عميل نقدي'");
      await addCol('cost REAL NOT NULL DEFAULT 0');
      await addCol("payment_method TEXT NOT NULL DEFAULT 'نقدي'");
      await addCol("payment_status TEXT NOT NULL DEFAULT 'paid'");
      await addCol('paid_amount REAL NOT NULL DEFAULT 0');

      final itemCols =
          (await db.rawQuery('PRAGMA table_info(invoice_items)'))
              .map((c) => c['name'] as String)
              .toSet();
      if (!itemCols.contains('product_id')) {
        await db.execute('ALTER TABLE invoice_items ADD COLUMN product_id INTEGER');
      }
    }

    if (oldVersion < 3) {
      // إضافة سجل الدفعات الحقيقي (Payments) + جدول الإعدادات (SMTP...)
      // + فهارس إضافية، دون المساس بأي بيانات موجودة.
      await _createV3Tables(db);

      // Backfill: لكل فاتورة قديمة عليها مبلغ مدفوع لكن بلا أي سطر في
      // جدول payments (لأن الجدول لم يكن موجوداً وقتها)، أنشئ دفعة
      // واحدة تمثّل ما دُفع فعلياً حتى تتطابق سجلات الدفعات مع
      // paid_amount المخزَّن على الفاتورة، دون فقدان أي بيانات تاريخية.
      final oldInvoices = await db.rawQuery(
          "SELECT id, customer_id, paid_amount, payment_method, created_at FROM invoices WHERE paid_amount > 0");
      for (final inv in oldInvoices) {
        final invoiceId = inv['id'] as int;
        final existing = await db.rawQuery(
            'SELECT COUNT(*) AS c FROM payments WHERE invoice_id = ?',
            [invoiceId]);
        final already = (existing.first['c'] as int?) ?? 0;
        if (already > 0) continue;
        await db.insert('payments', {
          'invoice_id': invoiceId,
          'customer_id': inv['customer_id'],
          'amount': inv['paid_amount'],
          'payment_method': inv['payment_method'] ?? 'نقدي',
          'payment_date': inv['created_at'],
          'notes': 'دفعة أولية عند إنشاء الفاتورة (تمت تعبئتها تلقائياً عند ترقية قاعدة البيانات)',
        });
      }
    }
  }

  // ============ عمليات عامة (تُستخدم من كل الـ Controllers) ============

  Future<int> insert(String table, Map<String, dynamic> value) async {
    final db = await database;
    return db.insert(table, value);
  }

  Future<List<Map<String, dynamic>>> getAll(String table,
      {String? orderBy}) async {
    final db = await database;
    return db.query(table, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> GetById(String table, int id) async {
    final db = await database;
    return db.query(table, where: 'id =?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getByBarcode(
      String table, String barcode) async {
    final db = await database;
    return db.query(table, where: 'barcode =?', whereArgs: [barcode]);
  }

  Future<int> UpdataData(
      String table, int id, Map<String, dynamic> Value) async {
    final db = await database;
    return db.update(table, Value, where: 'id=?', whereArgs: [id]);
  }

  Future<int> Delete(String table, int id) async {
    final db = await database;
    return db.delete(table, where: 'id=?', whereArgs: [id]);
  }

  Future<bool> barcodeExists(String barcode, {int? excludeId}) async {
    final db = await database;
    final result = await db.query('products',
        where: excludeId == null ? 'barcode = ?' : 'barcode = ? AND id != ?',
        whereArgs: excludeId == null ? [barcode] : [barcode, excludeId],
        limit: 1);
    return result.isNotEmpty;
  }

  Future<void> addStock(int productId, int qty) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE products SET stock = stock + ? WHERE id = ?', [qty, productId]);
  }

  /// استعلام SQL حر (يُستخدم للتقارير والإحصائيات في InvoiceController)
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  /// معاملة (Transaction) — تضمن أن كل خطوات إنشاء الفاتورة (إدخال
  /// الفاتورة + الأصناف + خصم المخزون) تنجح معاً أو تُلغى معاً.
  Future<T> runTransaction<T>(
      Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }
}
