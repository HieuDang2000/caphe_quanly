import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory getDatabaseFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> getDatabasePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'caphe_quanly.db');
}
