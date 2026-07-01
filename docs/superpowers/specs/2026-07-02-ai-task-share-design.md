# 단일 이벤트 AI 자동화 공유 — 설계

## 개요
캘린더 이벤트를 편집할 때, 그 일정 한 건을 **외부 AI에 넘겨 자동화**(문서·메일 초안, 준비물
정리 등)를 시킬 수 있는 공유 경로. 앱은 AI를 품지 않고, 일정을 AI가 바로 이해·작업할
**하이브리드(지시문 + JSON)** 텍스트로 만들어 공유시트로 핸드오프한다. **고급 기능**이라
설정에서 기본 비활성화(Google 연동과 같은 플래그 철학).

## 요구사항 (확정)
- **범위**: 단일 캘린더 이벤트(EventEditDialog에서 편집 중인 이벤트 1건).
- **진입점**: 캘린더 이벤트 편집 다이얼로그(EventEditDialog)의 액션.
- **게이팅**: 설정 탭 "고급" 토글 `AI 자동화 공유` — **기본 OFF**. OFF면 다이얼로그에 액션 미노출.
- **포맷**: 지시문(자연어) + JSON 코드블록 하이브리드.
- **지시문**: 기본 고정(v1). 편집 기능 없음(후속 후보).
- **핸드오프**: 공유시트(share_plus) — 기존 CSV 내보내기와 동일 패턴.

## 내보내기 포맷
```
아래는 제 업무 일정 한 건입니다. 이 일정을 처리하는 데 필요한 것을 도와주세요 —
관련 문서·메일 초안 작성, 준비물·체크리스트 정리 등 실행 가능한 형태로 제안해 주세요.

​```json
{
  "title": "2025학년도 겨울방학 운영 계획",
  "date": "2026-01-03",
  "endDate": null,
  "allDay": true,
  "description": ""
}
​```
```
- JSON 필드 = 캘린더 이벤트 필드: `title`, `date`(event_date), `endDate`(end_date, 없으면 null),
  `allDay`(is_all_day), `description`(없으면 빈 문자열). 이벤트엔 category가 없으므로 제외.
- 날짜는 `yyyy-MM-dd`(date_utils.formatDate 재사용).

## 컴포넌트
1. **순수 함수** `buildAiTaskExport(CalendarEvent) → String` (지시문 + JSON). 지시문 상수는
   `CalendarStrings`(또는 신규 도메인 strings). → 유닛 테스트로 포맷·필드 고정.
2. **설정 고급 토글** — `aiTaskShareEnabledProvider`(shared_preferences 기반, 알림 설정 provider와
   동일 패턴). 설정 탭 고급 섹션에 SwitchListTile. 기본 false.
3. **EventEditDialog 조건부 액션** — 토글 ON일 때만 `AI로 보내기` 노출. 탭 → buildAiTaskExport →
   `Share.share(...)`. 위치: 헤더 우측(휴지통 옆) 또는 본문 액션. OFF면 렌더 안 함.

## 테스트
- 유닛: `buildAiTaskExport` — 지시문 포함, JSON 필드 정확(endDate null·description 빈값 등 엣지),
  파싱 가능한 JSON.
- 위젯: 토글 OFF면 EventEditDialog에 액션 없음 / ON이면 있음.

## 범위 밖 (YAGNI — 후속 후보)
- 다중 항목/필터 목록 일괄 AI 공유.
- 지시문 편집 UI.
- Webhook/URL 전송, iOS 단축어 연동, 인앱 AI.
- 일정 검토(schedule) 탭 쪽 AI 공유(이번은 캘린더 이벤트만).

## 설계 결정 근거
- **기본 OFF 게이팅**: 색상 피커 제거로 막 비운 편집 다이얼로그를 일반 교사에겐 그대로 두고,
  고급 사용자만 켜서 씀(공직자 격조·단순 유지). Google 연동 플래그와 같은 철학.
- **하이브리드 포맷**: 사람도 읽고 AI/에이전트도 파싱 → 자동화 유리.
- **공유시트**: 특정 AI에 종속 안 됨(어떤 앱에든 전달), 기존 export 인프라 재사용.
