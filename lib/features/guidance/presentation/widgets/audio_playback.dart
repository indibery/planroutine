import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// 녹음 재생. 위젯 테스트에서 플랫폼 플러그인을 부르지 않으려고 인터페이스로 둔다.
abstract class AudioPlayback {
  Future<void> play(String path);
  Future<void> pause();
  Stream<Duration> get position;
  Stream<bool> get playing;
  Future<void> dispose();
}

class JustAudioPlayback implements AudioPlayback {
  JustAudioPlayback() {
    // just_audio의 `playing`은 끝까지 가도 true로 남는다 — 끝나면 스스로 멈추고 처음으로 되감아
    // 버튼이 `멈춤`에 남지 않게 하고, 다시 누르면 처음부터 재생되게 한다.
    _completedSub = _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    });
  }

  final _player = AudioPlayer();
  late final StreamSubscription<ProcessingState> _completedSub;
  String? _loaded;

  @override
  Future<void> play(String path) async {
    if (_loaded != path) {
      await _player.setFilePath(path);
      _loaded = path;
    }
    // play()는 끝날 때까지 기다리는 Future라 await하지 않는다. 오류는 삼키지 않고
    // 멈춘 상태(playing false)로 돌려 버튼이 `멈춤`에 남지 않게 한다.
    unawaited(_player.play().catchError((Object _) => _player.pause()));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Future<void> dispose() async {
    await _completedSub.cancel();
    await _player.dispose();
  }
}

/// 첨부마다 플레이어를 하나씩 만든다.
final audioPlaybackFactoryProvider = Provider<AudioPlayback Function()>(
  (ref) => JustAudioPlayback.new,
);
