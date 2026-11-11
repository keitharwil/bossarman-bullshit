import 'main_internal.dart' as internal_app;

export 'main_customer.dart' show BossArmanCustomerApp;
export 'main_internal.dart' show BossArmanInternalApp;

/// Default: Internal ERP.
/// Launch customer app with: `flutter run -t lib/main_customer.dart`
void main() {
  internal_app.main();
}
