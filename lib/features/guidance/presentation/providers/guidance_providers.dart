import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/guidance_file_store.dart';
import '../../data/guidance_people_repository.dart';
import '../../data/guidance_repository.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) => GuidanceRepository());

final guidancePeopleRepositoryProvider = Provider<GuidancePeopleRepository>(
  (ref) => GuidancePeopleRepository(),
);

final guidanceFileStoreProvider = Provider<GuidanceFileStore>((ref) => GuidanceFileStore());

/// 지도 기록이 바뀌었다는 신호. 목록·보기·이력이 watch해 다시 읽는다.
final guidanceChangedProvider = StateProvider<int>((ref) => 0);
