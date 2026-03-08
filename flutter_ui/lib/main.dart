import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/database/local_database.dart';
import 'core/database/local_seed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi', null);

  final localDb = LocalDatabase();
  await localDb.database;

  // Seed initial data on first run
  await LocalSeed.seedIfNeeded(localDb);

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDb),
      ],
      child: const CoffeeShopApp(),
    ),
  );
}
