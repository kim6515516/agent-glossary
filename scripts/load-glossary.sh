#!/usr/bin/env bash
# SessionStart 훅. 종료 코드 0 + 일반 텍스트 stdout → Claude 컨텍스트에 추가된다.
# 층 순서: 공용 도메인(플러그인 동봉) → 프로젝트(저장소) → 개인(사용자 홈).
# 전체 출력은 10,000자 상한이 있으므로 넘으면 뒤를 잘라내고 경고를 남긴다.
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
DOMAINS="${CLAUDE_PLUGIN_OPTION_DOMAINS:-common}"
PERSONAL="${CLAUDE_PLUGIN_OPTION_PERSONAL_GLOSSARY:-$HOME/.claude/glossary/personal.md}"
PERSONAL="${PERSONAL/#\~/$HOME}"
PROJECT_REL="${CLAUDE_PLUGIN_OPTION_PROJECT_GLOSSARY:-docs/glossary.md}"
LIMIT=9500

out=""
emit() { out+="$1"$'\n'; }

emit "# 용어집 (agent-glossary 플러그인이 세션 시작 시 불러옴)"
emit ""
emit "규칙:"
emit "1. 문서·코드 주석·화면 문구·커밋/PR 본문에는 **공용·프로젝트 용어**만 쓴다. 개인 용어는 쓰지 않는다."
emit "2. 사용자에게 보고·설명·질문할 때는 문장을 이 용어집과 대조해 '쓰지 않을 말'을 확정 용어로 바꾼다."
emit "   개인 별칭표가 있으면 사용자에게 말할 때만 그 말로 바꾼다. 우선순위: 개인 > 프로젝트 > 공용."
emit "3. 사용자가 개인 별칭으로 말하면 대응 용어로 이해한다."
emit "4. 다른 사람에게 전달할 결과물(PR 본문·문서·공유 보고)은 개인 별칭 없이 공용·프로젝트 용어로 쓴다."
emit "5. 새 개념에 이름을 붙였으면 PR 생성 전에 'glossary' 스킬의 용어 정리 절차를 따른다."
emit "6. 코드 식별자·옵션·파일명은 원문 그대로 두되 처음 나올 때 확정 용어를 함께 적는다."
emit "7. 쓰지 않을 말이 다른 확정 용어 안에 들어 있으면(예: 롤백 ↔ 트랜잭션 롤백) 그 확정 용어는 그대로 쓴다."
emit "8. 쓰지 않을 말에 괄호 조건이 붙어 있으면(예: API(주소 하나를 가리킬 때)) 그 조건일 때만 피한다."
emit "9. 쓰지 않을 말이 빈 행은 뜻만 고정한 업계 표준어다. 그 말을 그대로 쓰되 표의 뜻으로만 쓴다."
emit ""

IFS=',' read -ra DS <<<"$(echo "$DOMAINS" | tr -d '[]" ')"
for d in "${DS[@]}"; do
  f="$ROOT/glossaries/$d.md"
  if [ -f "$f" ]; then
    emit "## 공용 도메인: $d"
    emit "$(cat "$f")"
    emit ""
  else
    emit "(공용 도메인 '$d' 파일 없음: $f)"
  fi
done

if [ -f "$PROJ/$PROJECT_REL" ]; then
  emit "## 프로젝트 용어집 ($PROJECT_REL)"
  emit "$(cat "$PROJ/$PROJECT_REL")"
  emit ""
else
  emit "(프로젝트 용어집 없음: $PROJECT_REL. 만들려면 glossary 스킬의 templates/project-glossary.md 를 쓴다)"
fi

if [ -f "$PERSONAL" ]; then
  emit "## 개인 별칭표 (보고·설명에만 적용, 문서에는 쓰지 않음)"
  emit "$(cat "$PERSONAL")"
fi

if [ ${#out} -gt $LIMIT ]; then
  out="${out:0:$LIMIT}"$'\n'"(용어집이 10,000자 상한에 걸려 잘렸습니다. 도메인 파일을 줄이거나 활성 용어와 이력을 분리하세요.)"
fi
printf '%s' "$out"
exit 0
