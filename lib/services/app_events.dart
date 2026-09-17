import 'dart:async';

/// ═══════════════════════════════════════════════════════════════
/// AppEvents
/// ناقل أحداث بسيط داخل التطبيق: كلما تغيّرت بيانات مهمة (فاتورة
/// جديدة، دفعة، تعديل منتج...) نبث حدثاً هنا، وكل شاشة مفتوحة
/// (ضمن IndexedStack في HomeShell) تستمع وتُعيد تحميل بياناتها
/// تلقائياً دون الحاجة لإغلاق التطبيق وفتحه من جديد.
/// ═══════════════════════════════════════════════════════════════
enum AppEventType { products, invoices, customers, payments, all }

class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  final StreamController<AppEventType> _controller =
      StreamController<AppEventType>.broadcast();

  Stream<AppEventType> get stream => _controller.stream;

  void fire(AppEventType type) {
    if (!_controller.isClosed) _controller.add(type);
  }

  /// يُستخدم بعد أي عملية تمس أكثر من كيان دفعة واحدة (بيع، تسديد دين).
  void fireMany(List<AppEventType> types) {
    for (final t in types) {
      fire(t);
    }
  }
}
