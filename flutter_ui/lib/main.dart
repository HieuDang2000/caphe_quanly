import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/database/local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi', null);

  final localDb = LocalDatabase();
  // Trigger DB creation/open early so tables are ready
  await localDb.database;

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDb),
      ],
      child: const CoffeeShopApp(),
    ),
  );
}
