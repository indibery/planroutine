import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/google_calendar_service.dart';

/// Google Calendar 서비스 (싱글톤)
final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  final service = GoogleCalendarService();
  // 앱 시작 시 조용한 로그인 시도 — 저장된 토큰으로 자동 복귀
  service.signInSilently();
  return service;
});

/// 현재 로그인된 구글 계정을 방출하는 Stream.
/// 로그인/로그아웃 시 자동 갱신.
final googleAccountProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final service = ref.watch(googleCalendarServiceProvider);
  // 초기 값을 먼저 방출하고 이후 변화를 스트림으로 받는다
  return service.accountStream.startWith(service.currentUser);
});

extension on Stream<GoogleSignInAccount?> {
  Stream<GoogleSignInAccount?> startWith(GoogleSignInAccount? initial) async* {
    yield initial;
    yield* this;
  }
}
