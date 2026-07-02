import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'ai_task_share_enabled';

/// AI 자동화 공유(고급 기능) 활성 여부. **기본 OFF**. SharedPreferences 저장.
/// ON일 때만 캘린더 이벤트 편집에 'AI로 보내기' 액션이 노출된다.
final aiTaskShareEnabledProvider =
    AsyncNotifierProvider<AiTaskShareEnabledNotifier, bool>(
  AiTaskShareEnabledNotifier.new,
);

class AiTaskShareEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
