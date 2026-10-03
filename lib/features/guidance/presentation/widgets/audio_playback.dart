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
  final _player = AudioPlayer();
  String? _loaded;

  @override
  Future<void> play(String path) async {
    if (_loaded != path) {
      await _player.setFilePath(path);
      _loaded = path;
    }
    // play()는 끝날 때까지 기다리는 Future라 await하지 않는다.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Future<void> dispose() => _player.dispose();
}

/// 첨부마다 플레이어를 하나씩 만든다.
final audioPlaybackFactoryProvider = Provider<AudioPlayback Function()>(
  (ref) => JustAudioPlayback.new,
);
