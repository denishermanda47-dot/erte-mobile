import 'package:hive_ce/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel extends HiveObject {
  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.name,
    required this.role,
    this.avatarPath,
    this.phoneNumber,
    this.nik,
    this.familyCardNumber,
    this.address,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String passwordHash;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String? avatarPath;

  @HiveField(6)
  final String? phoneNumber;

  @HiveField(7)
  final String? nik;

  @HiveField(8)
  final String? familyCardNumber;

  @HiveField(9)
  final String? address;

  bool get isAdmin => role == 'admin';

  UserModel copyWith({
    String? name,
    String? avatarPath,
    String? phoneNumber,
    String? nik,
    String? familyCardNumber,
    String? address,
  }) => UserModel(
    id: id,
    username: username,
    passwordHash: passwordHash,
    name: name ?? this.name,
    role: role,
    avatarPath: avatarPath ?? this.avatarPath,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    nik: nik ?? this.nik,
    familyCardNumber: familyCardNumber ?? this.familyCardNumber,
    address: address ?? this.address,
  );
}
