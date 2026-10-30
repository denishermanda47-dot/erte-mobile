import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import 'resident_profile_repository.dart';
import 'hive_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  static const demoUserUsername = 'user@erte.id';
  static const demoUserPassword = 'user123';
  static const demoAdminUsername = 'admin@erte.id';
  static const demoAdminPassword = 'admin123';
  static const _uuid = Uuid();

  String _hashPassword(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  Future<void> seedDefaultUsers() async {
    final users = HiveService.users;
    final userExists = users.values.any(
      (user) => user.username.toLowerCase() == demoUserUsername,
    );
    final adminExists = users.values.any(
      (user) => user.username.toLowerCase() == demoAdminUsername,
    );

    if (!userExists) {
      await users.put(
        'demo-user',
        UserModel(
          id: 'demo-user',
          username: demoUserUsername,
          passwordHash: _hashPassword(demoUserPassword),
          name: 'Budi Santoso',
          role: 'user',
        ),
      );
    }
    if (!adminExists) {
      await users.put(
        'demo-admin',
        UserModel(
          id: 'demo-admin',
          username: demoAdminUsername,
          passwordHash: _hashPassword(demoAdminPassword),
          name: 'Admin ERTE',
          role: 'admin',
        ),
      );
    }
  }

  Future<UserModel?> getCurrentUser() async {
    await seedDefaultUsers();
    final userId = HiveService.session.get('currentUserId') as String?;
    if (userId == null) return null;
    final user = HiveService.users.get(userId);
    if (user == null) await HiveService.session.delete('currentUserId');
    return user;
  }

  Future<UserModel> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    await seedDefaultUsers();
    final normalizedUsername = username.trim().toLowerCase();
    UserModel? account;
    for (final user in HiveService.users.values) {
      if (user.username.toLowerCase() == normalizedUsername) {
        account = user;
        break;
      }
    }
    final phone = _normalizePhone(normalizedUsername);
    if (account == null && phone != null) {
      final profiles = ResidentProfileRepository();
      UserModel? phoneAccount;
      for (final user in HiveService.users.values) {
        final registeredPhone =
            user.phoneNumber ?? profiles.getProfile(user.id)?.phoneNumber;
        if (registeredPhone == null ||
            _normalizePhone(registeredPhone) != phone) {
          continue;
        }
        if (phoneAccount != null) {
          phoneAccount = null;
          break;
        }
        phoneAccount = user;
      }
      account = phoneAccount;
    }
    if (account == null || account.passwordHash != _hashPassword(password)) {
      throw const AuthException('Nama pengguna atau kata sandi tidak sesuai.');
    }

    if (rememberMe) {
      await HiveService.session.put('currentUserId', account.id);
    } else {
      await HiveService.session.delete('currentUserId');
    }
    return account;
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
    await seedDefaultUsers();
    final normalizedEmail = email.trim().toLowerCase();
    if (name.trim().length < 3) {
      throw const AuthException('Nama minimal 3 karakter.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      throw const AuthException('Format email tidak valid.');
    }
    if (password.length < 8) {
      throw const AuthException('Kata sandi minimal 8 karakter.');
    }
    if (phoneNumber != null && _normalizePhone(phoneNumber) == null) {
      throw const AuthException('Gunakan format nomor HP 08xx atau +628xx.');
    }
    if (nik != null && !RegExp(r'^\d{16}$').hasMatch(nik.trim())) {
      throw const AuthException('NIK harus berupa 16 digit angka.');
    }
    if (familyCardNumber != null &&
        !RegExp(r'^\d{16}$').hasMatch(familyCardNumber.trim())) {
      throw const AuthException('Nomor KK harus berupa 16 digit angka.');
    }
    if (address != null && address.trim().length < 10) {
      throw const AuthException('Alamat lengkap minimal 10 karakter.');
    }
    if (HiveService.users.values.any(
      (user) => user.username.toLowerCase() == normalizedEmail,
    )) {
      throw const AuthException('Email sudah terdaftar. Silakan masuk.');
    }
    final profiles = ResidentProfileRepository();
    if (nik != null &&
        HiveService.users.values.any(
          (user) =>
              user.nik == nik.trim() ||
              profiles.getProfile(user.id)?.nik == nik.trim(),
        )) {
      throw const AuthException('NIK sudah terdaftar.');
    }
    final normalizedPhone = phoneNumber == null
        ? null
        : _normalizePhone(phoneNumber);
    if (normalizedPhone != null &&
        HiveService.users.values.any((user) {
          final registeredPhone =
              user.phoneNumber ?? profiles.getProfile(user.id)?.phoneNumber;
          return registeredPhone != null &&
              _normalizePhone(registeredPhone) == normalizedPhone;
        })) {
      throw const AuthException('Nomor HP sudah terdaftar.');
    }

    final user = UserModel(
      id: _uuid.v4(),
      username: normalizedEmail,
      passwordHash: _hashPassword(password),
      name: name.trim(),
      role: 'user',
      phoneNumber: normalizedPhone,
      nik: nik?.trim(),
      familyCardNumber: familyCardNumber?.trim(),
      address: address?.trim(),
    );
    await HiveService.users.put(user.id, user);
    return user;
  }

  Future<void> updateUser(UserModel user) =>
      HiveService.users.put(user.id, user);

  Future<void> logout() => HiveService.session.delete('currentUserId');

  String? _normalizePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(08\d{8,11}|\+628\d{8,11})$').hasMatch(compact)) {
      return null;
    }
    return compact.startsWith('+62') ? '0${compact.substring(3)}' : compact;
  }
}
