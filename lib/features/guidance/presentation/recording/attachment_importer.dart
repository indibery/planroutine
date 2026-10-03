import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lock/system_sheet_guard.dart';

class PickedFile {
  const PickedFile({required this.path, required this.name});
  final String path;
  final String name;
}

abstract class AttachmentImporter {
  Future<PickedFile?> pickAudio();
  Future<PickedFile?> pickImage();
}

/// 고르기 창은 앱을 비활성(Android는 백그라운드)으로 만든다 — 반드시 가드 안에서 연다.
class FilePickerImporter implements AttachmentImporter {
  /// 음성 메모·통화 녹음·일반 녹음기의 확장자. `FileType.audio`는 iOS에서 **음악 보관함**을 열어
  /// 녹음 파일을 고를 수 없으므로 파일 창(custom)을 쓴다.
  static const audioExtensions = ['m4a', 'mp3', 'wav', 'aac', 'caf', 'amr', '3gp', 'ogg'];

  @override
  Future<PickedFile?> pickAudio() => SystemSheetGuard.run(() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: audioExtensions);
    return _first(r);
  });

  /// `allowCompression: false` — iOS 사진 고르기가 원본 표현(HEIC 그대로)을 넘긴다.
  /// 켜 두면 호환 형식으로 다시 인코딩돼 원본과 다른 바이트가 된다.
  @override
  Future<PickedFile?> pickImage() => SystemSheetGuard.run(() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowCompression: false);
    return _first(r);
  });

  PickedFile? _first(FilePickerResult? r) {
    final f = r?.files.firstOrNull;
    final path = f?.path;
    if (f == null || path == null) return null;
    return PickedFile(path: path, name: f.name);
  }
}

final attachmentImporterProvider = Provider<AttachmentImporter>((ref) => FilePickerImporter());
