import 'package:untitled2/database.dart';
import 'package:untitled2/model/customer.dart';

class CustomerController {
  final table = "customers";

  Future<int> insert(CustomerModel c) async {
    return DatabaseService.instance.insert(table, c.toMap());
  }

  Future<List<CustomerModel>> getAll() async {
    final data = await DatabaseService.instance.getAll(table, orderBy: 'name ASC');
    return data.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<CustomerModel?> getById(int id) async {
    final data = await DatabaseService.instance.GetById(table, id);
    if (data.isEmpty) return null;
    return CustomerModel.fromMap(data.first);
  }

  /// يبحث عن عميل موجود مسبقاً برقم الهاتف حتى لا تتكرر بياناته في
  /// كل عملية بيع جديدة.
  Future<CustomerModel?> findByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;
    final data = await DatabaseService.instance
        .rawQuery('SELECT * FROM customers WHERE phone = ? LIMIT 1', [phone.trim()]);
    if (data.isEmpty) return null;
    return CustomerModel.fromMap(data.first);
  }

  /// يعيد عميلاً موجوداً (حسب رقم الهاتف) أو يُنشئ عميلاً جديداً،
  /// ويرجع الـ id في الحالتين. يُستخدم أثناء إتمام عملية البيع.
  Future<int> findOrCreate({required String name, String? phone, String? email}) async {
    if (phone != null && phone.trim().isNotEmpty) {
      final existing = await findByPhone(phone);
      if (existing != null) return existing.id!;
    }
    return insert(CustomerModel(name: name, phone: phone, email: email));
  }

  /// بحث حقيقي من SQLite بالاسم أو رقم الهاتف (يُستخدم في Autocomplete
  /// عند اختيار العميل أثناء الدفع الآجل/الجزئي). محدود بعدد نتائج
  /// صغير ولا يُحمَّل كل جدول العملاء إلى الذاكرة.
  Future<List<CustomerModel>> search(String query, {int limit = 15}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await DatabaseService.instance.rawQuery(
      '''
      SELECT * FROM customers
      WHERE name LIKE ? OR phone LIKE ?
      ORDER BY name ASC
      LIMIT ?
      ''',
      ['%$q%', '%$q%', limit],
    );
    return rows.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<bool> update(int id, CustomerModel c) async {
    final count = await DatabaseService.instance.UpdataData(table, id, c.toMap());
    return count > 0;
  }

  Future<bool> delete(int id) async {
    final count = await DatabaseService.instance.Delete(table, id);
    return count > 0;
  }
}
