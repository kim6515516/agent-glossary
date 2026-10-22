#!/usr/bin/env bash
# 쓰지 않을 말 검사. 공용 도메인 + 프로젝트 용어집의 "쓰지 않을 말" 열을 모아
# 대상(기본 docs/)의 Markdown 에서 찾는다. 개인 별칭은 검사 대상이 아니라 금지 대상이다.
# 사용: lint-glossary.sh [파일 또는 디렉터리 ...]
# 종료 코드: 오류(3글자 이상 발견) 1, 그 외 0. 2글자 이하 짧은 말은 다른 뜻으로 쓰인 문장까지 걸리기 쉬워 경고로만 낸다.
# 예외: scripts/lint-allow.txt (플러그인) 과 <프로젝트>/docs/glossary-lint-allow.txt (프로젝트).
# 영어 금지어는 낱말 단위(stacktrace 안의 trace 는 안 걸림), 괄호 조건이 붙은 금지어는 검사하지 않는다.
# 공용 도메인은 설정 language(ko|ja)의 glossaries/<언어>/ 에서 읽고, 출력 문구도 그 언어로 낸다.
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
DOMAINS="${CLAUDE_PLUGIN_OPTION_DOMAINS:-common}"
PROJECT_REL="${CLAUDE_PLUGIN_OPTION_PROJECT_GLOSSARY:-docs/glossary.md}"
LANG_CODE="$(echo "${CLAUDE_PLUGIN_OPTION_LANGUAGE:-ko}" | tr -d '[]" ' | tr 'A-Z' 'a-z')"
case "$LANG_CODE" in ko|ja) ;; *) LANG_CODE=ko ;; esac
if [ "$LANG_CODE" = ja ]; then
  m_none="用語集ファイルがありません。"; m_empty="検査する「使わない言葉」がありません。"
  m_warn="[警告] 短い言葉"; m_warn_tail="(文脈の確認が必要):"; m_err="[エラー] 使わない言葉"; m_sum="エラー %d、警告 %d"
else
  m_none="용어집 파일이 없습니다."; m_empty="검사할 '쓰지 않을 말'이 없습니다."
  m_warn="[경고] 짧은 말"; m_warn_tail="(문맥 확인 필요):"; m_err="[오류] 쓰지 않을 말"; m_sum="오류 %d, 경고 %d"
fi
targets=("$@"); [ ${#targets[@]} -eq 0 ] && targets=("$PROJ/docs")

files=()
IFS=',' read -ra DS <<<"$(echo "$DOMAINS" | tr -d '[]" ')"
for d in "${DS[@]}"; do [ -f "$ROOT/glossaries/$LANG_CODE/$d.md" ] && files+=("$ROOT/glossaries/$LANG_CODE/$d.md"); done
[ -f "$PROJ/$PROJECT_REL" ] && files+=("$PROJ/$PROJECT_REL")
[ ${#files[@]} -eq 0 ] && { echo "$m_none"; exit 0; }

allow=$(cat "$ROOT/scripts/lint-allow.txt" "$PROJ/docs/glossary-lint-allow.txt" 2>/dev/null | grep -v '^#' | grep -v '^$' || true)

# 표 형식: | 용어 | 뜻 | 쓰지 않을 말 | 영역 | 확정일 | → 3번째 열을 쉼표로 나눈다 (머리글: 용어 / 用語)
banned=$(awk -F'|' '/^\|/ && $2 !~ /용어|用語|---/ { n=split($4,a,","); for(i=1;i<=n;i++){ gsub(/^[ \t]+|[ \t]+$/,"",a[i]); if(a[i]!="") print a[i] } }' "${files[@]}" | sort -u)
[ -z "$banned" ] && { echo "$m_empty"; exit 0; }

# 확정 용어(1열) — 금지어를 품은 확정 용어는 그 자리에서 허용한다 (예: 롤백 ↔ 트랜잭션 롤백)
terms=$(awk -F'|' '/^\|/ && $2 !~ /용어|用語|---/ { t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); if(t!="") print t }' "${files[@]}" | sort -u)
compounds=$(grep '^+' <<<"$allow" | sed 's/^+//' || true)

errors=0; warns=0
while IFS= read -r w; do
  [ -z "$w" ] && continue
  # 괄호로 조건을 단 말(예: "API(주소 하나를 가리킬 때)")은 AI 만 따르고 검사하지 않는다
  case "$w" in *"("*) continue;; esac
  grep -qxF -- "$w" <<<"$allow" && continue
  # 영어(ASCII)는 낱말 단위·대소문자 무시, 한국어는 조사가 붙으므로 부분 일치
  if LC_ALL=C grep -q '^[ -~]*$' <<<"$w"; then flags=(-w -i -F); else flags=(-F); fi
  hits=$(grep -rn --include='*.md' "${flags[@]}" -- "$w" "${targets[@]}" 2>/dev/null | grep -v -F -- "$PROJECT_REL" || true)
  [ -z "$hits" ] && continue
  # 파일별 예외(경로:단어)
  while IFS= read -r a; do
    case "$a" in +*) ;; *:*) p="${a%%:*}"; aw="${a#*:}"; [ "$aw" = "$w" ] && hits=$(grep -v -F -- "$p" <<<"$hits" || true);; esac
  done <<<"$allow"
  # 금지어를 품은 확정 용어·합성어를 지운 뒤에도 남는 줄만 남긴다
  masks=$( { grep -F -- "$w" <<<"$terms" | grep -vxF -- "$w"; grep -F -- "$w" <<<"$compounds"; } || true)
  kept=""
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    body="${h#*:}"; body="${body#*:}"
    while IFS= read -r m; do [ -n "$m" ] && body="${body//$m/}"; done <<<"$masks"
    grep -q "${flags[@]}" -- "$w" <<<"$body" && kept+="$h"$'\n'
  done <<<"$hits"
  [ -z "$kept" ] && continue
  if [ "${#w}" -le 2 ]; then
    echo "$m_warn '$w' $m_warn_tail"; warns=$((warns+1))
  else
    echo "$m_err '$w':"; errors=$((errors+1))
  fi
  printf '%s' "$kept" | sed 's/^/  /'
done <<<"$banned"
printf "$m_sum\n" "$errors" "$warns"
[ $errors -eq 0 ] && exit 0 || exit 1
