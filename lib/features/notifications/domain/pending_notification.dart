/// 예약될 알림의 최종 명세 (플랫폼에 전달 직전 형태).
///
/// `computeNotifications` 순수 함수의 출력이자 `NotificationService`의 입력.
class PendingNotification {
  const PendingNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  /// 플랫폼에 전달할 고유 int id. 같은 id는 덮어쓰기 취급.
  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;

  @override
  bool operator ==(Object other) =>
      other is PendingNotification &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.scheduledAt == scheduledAt;

  @override
  int get hashCode => Object.hash(id, title, body, scheduledAt);

  @override
  String toString() =>
      'PendingNotification(id=$id, title="$title", at=$scheduledAt)';
}
