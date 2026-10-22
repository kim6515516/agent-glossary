#!/usr/bin/env bash
# 쓰지 않을 말 검사. 공용 도메인 + 프로젝트 용어집의 "쓰지 않을 말" 열을 모아
# 대상(기본 docs/)의 Markdown 에서 찾는다. 개인 별칭은 검사 대상이 아니라 금지 대상이다.
# 사용: lint-glossary.sh [파일 또는 디렉터리 ...]
# 종료 코드: 오류(3글자 이상 발견) 1, 그 외 0. 2글자 이하 짧은 말은 잘못 걸림이 잦아 경고로만 낸다.
# 예외: scripts/lint-allow.txt (플러그인) 과 <프로젝트>/docs/glossary-lint-allow.txt (프로젝트).
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
DOMAINS="${CLAUDE_PLUGIN_OPTION_DOMAINS:-common}"
PROJECT_REL="${CLAUDE_PLUGIN_OPTION_PROJECT_GLOSSARY:-docs/glossary.md}"
targets=("$@"); [ ${#targets[@]} -eq 0 ] && targets=("$PROJ/docs")

files=()
IFS=',' read -ra DS <<<"$(echo "$DOMAINS" | tr -d '[]" ')"
for d in "${DS[@]}"; do [ -f "$ROOT/glossaries/$d.md" ] && files+=("$ROOT/glossaries/$d.md"); done
[ -f "$PROJ/$PROJECT_REL" ] && files+=("$PROJ/$PROJECT_REL")
[ ${#files[@]} -eq 0 ] && { echo "용어집 파일이 없습니다."; exit 0; }

allow=$(cat "$ROOT/scripts/lint-allow.txt" "$PROJ/docs/glossary-lint-allow.txt" 2>/dev/null | grep -v '^#' | grep -v '^$' || true)

# 표 형식: | 용어 | 뜻 | 쓰지 않을 말 | 영역 | 확정일 | → 3번째 열을 쉼표로 나눈다
banned=$(awk -F'|' '/^\|/ && $2 !~ /용어|---/ { n=split($4,a,","); for(i=1;i<=n;i++){ gsub(/^[ \t]+|[ \t]+$/,"",a[i]); if(a[i]!="") print a[i] } }' "${files[@]}" | sort -u)
[ -z "$banned" ] && { echo "검사할 '쓰지 않을 말'이 없습니다."; exit 0; }

errors=0; warns=0
while IFS= read -r w; do
  grep -qxF -- "$w" <<<"$allow" && continue
  hits=$(grep -rn --include='*.md' -F -- "$w" "${targets[@]}" 2>/dev/null | grep -v -F -- "$PROJECT_REL" || true)
  [ -z "$hits" ] && continue
  # 파일별 예외(경로:단어) 제거
  while IFS= read -r a; do
    case "$a" in *:*) p="${a%%:*}"; aw="${a#*:}"; [ "$aw" = "$w" ] && hits=$(grep -v -F -- "$PROJ/$p" <<<"$hits" | grep -v -F -- "$p" || true);; esac
  done <<<"$allow"
  [ -z "$hits" ] && continue
  if [ "${#w}" -le 2 ]; then
    echo "[경고] 짧은 말 '$w' (문맥 확인 필요):"; warns=$((warns+1))
  else
    echo "[오류] 쓰지 않을 말 '$w':"; errors=$((errors+1))
  fi
  sed 's/^/  /' <<<"$hits"
done <<<"$banned"
echo "오류 $errors, 경고 $warns"
[ $errors -eq 0 ] && exit 0 || exit 1
