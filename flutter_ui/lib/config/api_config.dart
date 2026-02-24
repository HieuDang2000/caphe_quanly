class ApiConfig {
  // static const String baseUrl = 'https://hien.meonohehe.men/api';
  static const String baseUrl = 'http://localhost:8000/api';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';

  static const String users = '/users';

  static const String floors = '/layout/floors';
  static const String layoutObjects = '/layout/objects';
  static const String layoutObjectsBatch = '/layout/objects/batch';
  static const String tables = '/layout/tables';

  static const String categories = '/menu/categories';
  static const String menuItems = '/menu/items';

  static const String orders = '/orders';
  static const String activeOrders = '/orders/active';
  static const String orderActivities = '/orders/activities';

  static const String invoices = '/invoices';

  static const String reports = '/reports';

  static const String staff = '/staff';
  static const String inventory = '/inventory';
  static const String customers = '/customers';
  static const String reservations = '/reservations';
}
