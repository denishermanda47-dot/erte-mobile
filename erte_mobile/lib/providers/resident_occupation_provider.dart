import 'package:flutter_riverpod/flutter_riverpod.dart';

const residentOccupationOptions = <String>[
  'Belum/Tidak Bekerja',
  'Pelajar/Mahasiswa',
  'Karyawan Swasta',
  'Pegawai Negeri Sipil (PNS)',
  'TNI/Polri',
  'Wiraswasta/Pedagang',
  'Petani/Pekebun',
  'Nelayan',
  'Buruh',
  'Ibu Rumah Tangga',
  'Pensiunan',
  'Lainnya',
];

final residentOccupationProvider = StateProvider.autoDispose
    .family<String?, String>((ref, userId) => null);
