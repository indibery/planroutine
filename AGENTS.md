# PlanRoutine (공직플랜) — Agent 안내

이 프로젝트의 규칙·아키텍처는 **[CLAUDE.md](./CLAUDE.md)** 단일 소스에 있습니다.

Codex 등 `AGENTS.md`를 읽는 에이전트도 `CLAUDE.md`를 그대로 따르세요. (내용 중복을 피하기 위해 여기에 복사하지 않습니다.)

**배포는 CLAUDE.md에 없습니다.** 명령·레인·게이트·트러블슈팅·검증 함정은
[.claude/skills/deploy/SKILL.md](./.claude/skills/deploy/SKILL.md)로 옮겼습니다 —
Claude Code는 이 파일을 스킬로 자동 로드하지만, **그 외 에이전트는 경로로 직접 읽어야 합니다.**
CLAUDE.md의 `## 배포 · 빌드 도구`에는 배포 밖에서도 밟는 급소만 남아 있습니다.

같은 이유로 알아 둘 파일 둘:
- 파일별 상세 구조: [docs/notes/project-structure.md](./docs/notes/project-structure.md)
- 문서↔코드 가드를 쓰는 절차: [.claude/skills/guard/SKILL.md](./.claude/skills/guard/SKILL.md)

⚠️ `.claude/settings.json`의 훅이 `git push --force`·`--no-verify`·테스트 삭제 등을
**차단**합니다(Claude Code에서만 동작). 다른 에이전트는 그 보호를 받지 않으니
CLAUDE.md의 `## Claude Code 훅` 절을 읽고 규칙을 스스로 지키세요.
