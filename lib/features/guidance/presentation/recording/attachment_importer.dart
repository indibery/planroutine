import 'dart:io';

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

  /// 고르기 창이 넘긴 사본을 지운다. 첨부 폴더로 복사가 끝난 뒤(성공·실패 모두) 부른다.
  Future<void> discard(PickedFile picked);
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

  /// `picked.path`만 지운다. file_picker 9.2.3 소스로 확인한 사실:
  /// - iOS 사진(PHPicker)은 `Documents/picked_images/`에 사본을 쓴다 — **tmp가 아니라**
  ///   `clearTemporaryFiles()`(= NSTemporaryDirectory 전체 삭제)로는 지워지지 않는다.
  ///   Documents는 iCloud 백업에도 들어간다.
  /// - iOS 파일(UIDocumentPicker import)은 tmp로 옮긴 사본, Android는 `cache/file_picker/<시각>/`의 사본이다.
  /// 즉 이 경로는 늘 플러그인이 만든 사본이고 원본이 아니다. `clearTemporaryFiles()`를 쓰지 않는
  /// 이유는 위의 iOS 사진을 못 지우고, iOS에서는 앱의 tmp 전체를 지우기 때문이다.
  @override
  Future<void> discard(PickedFile picked) async {
    try {
      await File(picked.path).delete();
    } catch (_) {
      // 이미 없거나 지울 수 없어도 첨부는 끝났다 — 기능을 멈추지 않는다.
    }
  }

  PickedFile? _first(FilePickerResult? r) {
    final f = r?.files.firstOrNull;
    final path = f?.path;
    if (f == null || path == null) return null;
    return PickedFile(path: path, name: f.name);
  }
}

final attachmentImporterProvider = Provider<AttachmentImporter>((ref) => FilePickerImporter());
