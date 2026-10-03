import '../../../core/constants/app_strings.dart';

/// 명단 사람의 구분. **역할(가해·피해·목격)이 아니다** — 사람이 누구인지만 말한다.
enum PersonRole {
  student('student', GuidanceStrings.roleStudent),
  guardian('guardian', GuidanceStrings.roleGuardian),
  staff('staff', GuidanceStrings.roleStaff),
  other('other', GuidanceStrings.roleOther);

  const PersonRole(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PersonRole fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => other);
}

/// 기록의 종류(사람에게 붙는 것이 아니다).
enum GuidanceKind {
  guidance('guidance', GuidanceStrings.kindGuidance),
  infringement('infringement', GuidanceStrings.kindInfringement);

  const GuidanceKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GuidanceKind fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => guidance);
}

enum GuidanceStatus {
  open('open', GuidanceStrings.statusOpen),
  closedAtSchool('closed_at_school', GuidanceStrings.statusClosedAtSchool),
  transferred('transferred', GuidanceStrings.statusTransferred);

  const GuidanceStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GuidanceStatus fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => open);
}

/// 사건 시각을 얼마나 정확히 아는가. 학생 확인서도 "3월 초쯤"을 허용한다 —
/// 정확한 시각만 받으면 사용자가 지어내게 된다.
enum OccurredPrecision {
  exact('exact', GuidanceStrings.precisionExact),
  date('date', GuidanceStrings.precisionDate),
  approx('approx', GuidanceStrings.precisionApprox);

  const OccurredPrecision(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static OccurredPrecision fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => exact);
}

enum AttachmentType {
  audio('audio', GuidanceStrings.attachmentAudio),
  image('image', GuidanceStrings.attachmentImage);

  const AttachmentType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AttachmentType fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => image);
}

enum AttachmentSource {
  recorded('recorded', GuidanceStrings.sourceRecorded),
  imported('imported', GuidanceStrings.sourceImported);

  const AttachmentSource(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AttachmentSource fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => imported);
}
