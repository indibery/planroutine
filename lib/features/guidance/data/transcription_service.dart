import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/transcript.dart';

/// Swift(`ios/Runner/Transcriber.swift`)와 맞춰야 하는 이름들. 가드가 양쪽을 대조한다.
abstract final class TranscriberContract {
  static const methodChannel = 'planroutine/transcriber';
  static const eventChannel = 'planroutine/transcriber/segments';
  static const methodIsAvailable = 'isAvailable';
  static const eventPreparing = 'preparing';
  static const eventSegment = 'segment';
}

sealed class TranscriptEvent {
  const TranscriptEvent();
}

/// 한국어 모델을 처음 내려받는 중.
class TranscriptPreparing extends TranscriptEvent {
  const TranscriptPreparing();
}

class TranscriptSegmentArrived extends TranscriptEvent {
  const TranscriptSegmentArrived(this.segment);
  final TranscriptSegment segment;
}

enum TranscriptFailure { modelDownload, fileNotFound, unsupported, other }

class TranscriptionException implements Exception {
  const TranscriptionException(this.failure);
  final TranscriptFailure failure;
}

/// 기기 안 전사. 위젯 테스트에서는 가짜 구현을 끼운다(`AudioPlayback`과 같은 이유).
abstract class TranscriptionService {
  Future<bool> isAvailable();

  /// 구독을 끊으면 기기 쪽 전사도 멈춘다.
  Stream<TranscriptEvent> transcribe(String path);
}

class ChannelTranscriptionService implements TranscriptionService {
  /// [isAndroid] 기본은 `Platform.isAndroid` — `defaultTargetPlatform`은 테스트에서 늘 android다.
  ChannelTranscriptionService({bool? isAndroid})
    : _isAndroid = isAndroid ?? Platform.isAndroid;

  final bool _isAndroid;
  static const _method = MethodChannel(TranscriberContract.methodChannel);
  static const _events = EventChannel(TranscriberContract.eventChannel);

  @override
  Future<bool> isAvailable() async {
    if (_isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>(
            TranscriberContract.methodIsAvailable,
          ) ??
          false;
    } catch (_) {
      // 채널이 없는 빌드·구버전 iOS 등 — 버튼을 숨기면 된다.
      return false;
    }
  }

  @override
  Stream<TranscriptEvent> transcribe(String path) => _events
      .receiveBroadcastStream(path)
      .handleError((Object e) => throw TranscriptionException(_failureOf(e)))
      .map(_eventOf)
      .where((e) => e != null)
      .cast<TranscriptEvent>();

  static TranscriptEvent? _eventOf(dynamic raw) {
    if (raw is! Map) return null;
    return switch (raw['type']) {
      TranscriberContract.eventPreparing => const TranscriptPreparing(),
      TranscriberContract.eventSegment => TranscriptSegmentArrived(
        TranscriptSegment(
          startMs: (raw['startMs'] as num?)?.toInt() ?? 0,
          endMs: (raw['endMs'] as num?)?.toInt() ?? 0,
          text: raw['text'] as String? ?? '',
        ),
      ),
      _ => null,
    };
  }

  static TranscriptFailure _failureOf(Object e) =>
      switch (e is PlatformException ? e.code : null) {
        'modelDownloadFailed' => TranscriptFailure.modelDownload,
        'fileNotFound' => TranscriptFailure.fileNotFound,
        'unsupported' => TranscriptFailure.unsupported,
        _ => TranscriptFailure.other,
      };
}
