import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/data_model.dart';
import '../models/data_status.dart';
import '../models/user_model.dart';

abstract final class HiveService {
  static const usersBoxName = 'users';
  static const submissionsBoxName = 'dataSubmissions';
  static const sessionBoxName = 'session';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    registerAdapters();

    await Future.wait([
      Hive.openBox<UserModel>(usersBoxName),
      Hive.openBox<DataModel>(submissionsBoxName),
      Hive.openBox<dynamic>(sessionBoxName),
    ]);
  }

  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DataStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DataModelAdapter());
    }
  }

  static Box<UserModel> get users => Hive.box<UserModel>(usersBoxName);
  static Box<DataModel> get submissions =>
      Hive.box<DataModel>(submissionsBoxName);
  static Box<dynamic> get session => Hive.box<dynamic>(sessionBoxName);
}
