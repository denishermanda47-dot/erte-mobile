import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/data_model.dart';

class LetterPdfService {
  static Future<Uint8List> generate(DataModel request) async {
    final document = pw.Document();
    final date = DateFormat(
      'd MMMM yyyy',
      'id_ID',
    ).format(request.verifiedAt ?? request.submittedAt);

    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'SURAT PENGANTAR RT/RW',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Nomor: ${request.letterNumber ?? '-'}'),
                pw.Divider(),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Yang bertanda tangan di bawah ini menerangkan bahwa:',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          _row('Nama', request.userName),
          _row('Jenis surat', request.title),
          _row('Keperluan', request.description),
          ...request.applicantDetails.entries.map(
            (entry) => _row(entry.key, entry.value),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Demikian surat pengantar ini dibuat untuk dipergunakan sebagaimana mestinya.',
          ),
          pw.SizedBox(height: 40),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Tanggal $date'),
                pw.SizedBox(height: 52),
                pw.Text(
                  'Pengurus RT/RW',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 100, child: pw.Text(label)),
        pw.Text(': '),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );
}
