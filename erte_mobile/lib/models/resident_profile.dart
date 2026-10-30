class ResidentProfile {
  const ResidentProfile({
    required this.nik,
    required this.familyCardNumber,
    required this.fullName,
    required this.birthPlace,
    required this.birthDate,
    required this.gender,
    required this.religion,
    required this.maritalStatus,
    required this.occupation,
    required this.address,
    required this.rt,
    required this.rw,
    required this.phoneNumber,
    required this.familyRelationship,
    required this.ktpPhotoPath,
    required this.familyCardPhotoPath,
  });

  final String nik;
  final String familyCardNumber;
  final String fullName;
  final String birthPlace;
  final DateTime birthDate;
  final String gender;
  final String religion;
  final String maritalStatus;
  final String occupation;
  final String address;
  final String rt;
  final String rw;
  final String phoneNumber;
  final String familyRelationship;
  final String ktpPhotoPath;
  final String familyCardPhotoPath;

  factory ResidentProfile.fromJson(Map<String, dynamic> json) =>
      ResidentProfile(
        nik: json['nik'] as String,
        familyCardNumber: json['familyCardNumber'] as String,
        fullName: json['fullName'] as String,
        birthPlace: json['birthPlace'] as String,
        birthDate: DateTime.parse(json['birthDate'] as String),
        gender: json['gender'] as String,
        religion: json['religion'] as String,
        maritalStatus: json['maritalStatus'] as String,
        occupation: json['occupation'] as String,
        address: json['address'] as String,
        rt: json['rt'] as String,
        rw: json['rw'] as String,
        phoneNumber: json['phoneNumber'] as String,
        familyRelationship: json['familyRelationship'] as String,
        ktpPhotoPath: json['ktpPhotoPath'] as String,
        familyCardPhotoPath: json['familyCardPhotoPath'] as String,
      );

  Map<String, dynamic> toJson() => {
    'nik': nik,
    'familyCardNumber': familyCardNumber,
    'fullName': fullName,
    'birthPlace': birthPlace,
    'birthDate': birthDate.toIso8601String(),
    'gender': gender,
    'religion': religion,
    'maritalStatus': maritalStatus,
    'occupation': occupation,
    'address': address,
    'rt': rt,
    'rw': rw,
    'phoneNumber': phoneNumber,
    'familyRelationship': familyRelationship,
    'ktpPhotoPath': ktpPhotoPath,
    'familyCardPhotoPath': familyCardPhotoPath,
  };
}
