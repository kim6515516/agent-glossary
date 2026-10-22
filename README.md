# agent-glossary

AI 에이전트가 만든 말과 사람이 쓰는 말을 맞추는 3층 용어집 플러그인이다.

| 층 | 파일 | 적용 |
|---|---|---|
| 공용 도메인 | 이 플러그인 `glossaries/*.md` | 문서·주석·보고 전부 |
| 프로젝트 | 저장소 `docs/glossary.md` | 문서·주석·보고 전부 |
| 개인 | `~/.claude/glossary/personal.md` | 보고·설명에만 |

## 무엇이 들어 있나

- `hooks/hooks.json` — SessionStart 훅. 세 층을 읽어 컨텍스트에 넣고 "말하기 전에 변환" 규칙을 함께 올린다.
- `skills/glossary` — 용어 정리 절차(추출→후보 표→확정 대기→반영→용어집 커밋), 검사, 개인 별칭 등록.
- `scripts/lint-glossary.sh` — "쓰지 않을 말"이 문서에 다시 나오는지 검사. CI 에서도 쓸 수 있다.
- `templates/` — 프로젝트·개인 용어집 템플릿.

## 설치

이 저장소가 마켓플레이스이자 플러그인이다(`.claude-plugin/marketplace.json` 의 source `.`).

```bash
claude plugin marketplace add kim6515516/agent-glossary
/plugin install agent-glossary --marketplace kim6515516/agent-glossary
```

로컬에서 바로 써 보려면 설치 없이 `claude --plugin-dir /path/to/agent-glossary` 로 세션을 연다.

`.claude/settings.json` 의 `enabledPlugins` 를 커밋해도 팀원 기기에 자동 설치되지는 않는다. 각자 위 설치 명령을 한 번 실행하고
폴더를 신뢰해야 적용된다. 설치 후 `/config` 에서 `domains`(예: `common,backend`)를 고른다.

## 확인

- `claude plugin validate .` 로 매니페스트 검사.
- 새 세션에서 `/context` 로 용어집이 올라갔는지 확인.
- `scripts/lint-glossary.sh docs/` 로 검사 동작 확인. 2글자 이하 말은 경고로만 내고, 예외는 `scripts/lint-allow.txt`(플러그인) 또는 `<프로젝트>/docs/glossary-lint-allow.txt` 에 적는다.

## 설계 원칙

- 개인 층은 별칭만 둔다. 새 개념은 프로젝트·공용 층에서만 만든다. 그래야 커밋되는 문서가 작성자와 무관하게 같은 용어를 쓴다.
- 우선순위는 말할 때 개인 > 프로젝트 > 공용, 쓸 때 프로젝트 > 공용.
- 승격: 개인 별칭을 둘 이상이 쓰면 프로젝트로, 여러 프로젝트에서 확정되면 공용으로.
- 공용 파일은 매 세션 전부 올라가므로 짧게(파일당 50행 안팎). SessionStart 출력은 10,000자 상한.

## 미결

- `userConfig` 의 `multiple` 옵션으로 도메인을 고르게 할지(지금은 쉼표 문자열).
- Stop 훅으로 PR 본문·보고에 쓰지 않을 말이 섞였는지 자동 검사할지.
- 공용 저장소의 도메인별 검토자.
