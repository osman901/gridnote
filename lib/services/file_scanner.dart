import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileInfo {
  final File file;
  final String name;
  final String ext; // .pdf / .xlsx
  final DateTime modified;
  final int sizeBytes;
  final String origin; // 'Documents' | 'Reports' | 'Temp' | '—'

  const FileInfo({
    required this.file,
    required this.name,
    required this.ext,
    required this.modified,
    required this.sizeBytes,
    required this.origin,
  });
}

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(2)} MB';
}

Future<List<FileInfo>> scanReports() async {
  final docs = await getApplicationDocumentsDirectory();
  final temp = await getTemporaryDirectory();
  final reportsDir = Directory(p.join(docs.path, 'reports'));
  final candidates = <Directory>[docs, temp, reportsDir];

  final out = <FileInfo>[];
  for (final dir in candidates) {
    if (!await dir.exists()) continue;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      final ext = p.extension(e.path).toLowerCase();
      if (ext != '.pdf' && ext != '.xlsx') continue;

      final st = await e.stat();
      final path = e.path;
      final origin = path.startsWith(reportsDir.path)
          ? 'Historial'
          : path.startsWith(docs.path)
          ? 'Documents'
          : path.startsWith(temp.path)
          ? 'Temp'
          : '—';

      out.add(FileInfo(
        file: e,
        name: p.basename(path),
        ext: ext,
        modified: st.modified,
        sizeBytes: st.size,
        origin: origin,
      ));
    }
  }
  out.sort((a, b) => b.modified.compareTo(a.modified));
  return out;
}
