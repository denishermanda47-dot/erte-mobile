import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_session.dart';
import '../models/user_model.dart';
import '../services/auth_repository.dart';
import '../services/hive_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserModel?>>(
      (ref) => AuthController(ref.watch(authRepositoryProvider)),
    );

class AuthController extends StateNotifier<AsyncValue<UserModel?>> {
  AuthController(this._repository) : super(const AsyncLoading());

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.getCurrentUser);
  }

  Future<UserModel> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    final user = await _repository.login(
      username: username,
      password: password,
      rememberMe: rememberMe,
    );
    state = AsyncData(user);
    return user;
  }

  /// Dipanggil setelah login ke API berhasil: simpan pengguna dari server
  /// sebagai UserModel lokal supaya dashboard bisa membacanya.
  /// Role "Admin RW" / "Superadmin" dipetakan ke admin; lainnya ke warga.
  Future<UserModel> loginFromApi({
    required String id,
    required String name,
    required String email,
    required List<String> roles,
    bool rememberMe = true,
  }) async {
    const adminRoles = {'admin', 'admin rw', 'superadmin'};
    final isAdmin =
        roles.any((r) => adminRoles.contains(r.trim().toLowerCase()));
    final existing = HiveService.users.get(id); // pertahankan profil lokal
    final user = UserModel(
      id: id,
      username: email.trim().toLowerCase(),
      passwordHash: '', // tidak ada password lokal untuk akun dari API
      name: name,
      role: isAdmin ? 'admin' : 'user',
      avatarPath: existing?.avatarPath,
      phoneNumber: existing?.phoneNumber,
      nik: existing?.nik,
      familyCardNumber: existing?.familyCardNumber,
      address: existing?.address,
    );
    await HiveService.users.put(user.id, user);
    if (rememberMe) {
      await HiveService.session.put('currentUserId', user.id);
    } else {
      await HiveService.session.delete('currentUserId');
    }
    state = AsyncData(user);
    return user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
    String? nik,
    String? familyCardNumber,
    String? address,
  }) async {
    final user = await _repository.register(
      name: name,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      nik: nik,
      familyCardNumber: familyCardNumber,
      address: address,
    );
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    AuthSession.clear(); // hapus token API dari memori
    state = const AsyncData(null);
  }
}
