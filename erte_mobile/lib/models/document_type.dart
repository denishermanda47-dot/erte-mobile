/// Jenis dokumen yang difoto pada Tahap 3 registrasi.
enum DocumentType { ktp, kk }

extension DocumentTypeInfo on DocumentType {
  /// Label singkat untuk judul dan teks.
  String get label => this == DocumentType.ktp ? 'KTP' : 'KK';

  /// Rasio lebar : tinggi bingkai panduan (hanya panduan visual, foto tidak dipotong).
  /// KTP ≈ 1.586 : 1, KK ≈ 1.4 : 1.
  double get aspect => this == DocumentType.ktp ? 1.586 : 1.4;

  String get instruction => 'Posisikan $label di dalam kotak';
}
