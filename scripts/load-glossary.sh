#!/usr/bin/env bash
# SessionStart 훅. 종료 코드 0 + 일반 텍스트 stdout → Claude 컨텍스트에 추가된다.
# 층 순서: 공용 도메인(플러그인 동봉) → 프로젝트(저장소) → 개인(사용자 홈).
# 공용 도메인은 설정 language(ko|ja)에 맞는 glossaries/<언어>/ 에서 읽는다. 안내 문구도 그 언어로 낸다.
# 전체 출력은 10,000자 상한이 있으므로 넘으면 뒤를 잘라내고 경고를 남긴다.
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
DOMAINS="${CLAUDE_PLUGIN_OPTION_DOMAINS:-common}"
LANG_CODE="${CLAUDE_PLUGIN_OPTION_LANGUAGE:-ko}"
PERSONAL="${CLAUDE_PLUGIN_OPTION_PERSONAL_GLOSSARY:-$HOME/.claude/glossary/personal.md}"
PERSONAL="${PERSONAL/#\~/$HOME}"
PROJECT_REL="${CLAUDE_PLUGIN_OPTION_PROJECT_GLOSSARY:-docs/glossary.md}"
LIMIT=9500

out=""
emit() { out+="$1"$'\n'; }

LANG_CODE="$(echo "$LANG_CODE" | tr -d '[]" ' | tr 'A-Z' 'a-z')"
case "$LANG_CODE" in
  ko|ja) bad_lang="" ;;
  *) bad_lang="$LANG_CODE"; LANG_CODE=ko ;;
esac

if [ "$LANG_CODE" = ja ]; then
  emit "# 用語集 (agent-glossary プラグインがセッション開始時に読み込み)"
  emit ""
  emit "ルール:"
  emit "1. ドキュメント・コードコメント・画面文言・コミット/PR 本文には **共通・プロジェクト用語** だけを使う。個人の呼び名は使わない。"
  emit "2. ユーザーへの報告・説明・質問では、文をこの用語集と照らし合わせ「使わない言葉」を確定用語に置き換える。"
  emit "   個人の呼び名表があれば、ユーザーに話すときだけその言葉に置き換える。優先順位: 個人 > プロジェクト > 共通。"
  emit "3. ユーザーが個人の呼び名で話したら、対応する用語として理解する。"
  emit "4. 他の人に渡す成果物(PR 本文・ドキュメント・共有の報告)は、個人の呼び名を使わず共通・プロジェクト用語で書く。"
  emit "5. 新しい概念に名前を付けたら、PR を作る前に 'glossary' スキルの用語整理の手順に従う。"
  emit "6. コード識別子・オプション・ファイル名は原文のままにし、初出のときに確定用語を添える。"
  emit "7. 使わない言葉が別の確定用語の中に含まれていれば(例: ロールバック ↔ トランザクションロールバック)、その確定用語はそのまま使う。"
  emit "8. 使わない言葉に括弧の条件が付いていれば(例: API(URL 1つを指すとき))、その条件のときだけ避ける。"
  emit "9. 使わない言葉が空の行は、意味だけを固定した業界の標準語。そのまま使うが、表の意味でだけ使う。"
  emit "10. ユーザーへの報告・成果物は日本語で書く。"
  emit ""
  [ -n "$bad_lang" ] && emit "(設定 language='$bad_lang' は対応していないため ko を使います)"
  h_domain="共通ドメイン"; h_project="プロジェクト用語集"; h_personal="個人の呼び名表 (報告・説明にだけ適用、ドキュメントには使わない)"
  m_no_domain="ファイルなし"; m_no_project="プロジェクト用語集なし"; m_make_project="作るときは glossary スキルの templates/ja/project-glossary.md を使う"
  m_cut="(用語集が 10,000 文字の上限で切れました。ドメインファイルを減らすか、有効な用語と履歴を分けてください。)"
else
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
  [ -n "$bad_lang" ] && emit "(설정 language='$bad_lang' 은 지원하지 않아 ko 를 씁니다)"
  h_domain="공용 도메인"; h_project="프로젝트 용어집"; h_personal="개인 별칭표 (보고·설명에만 적용, 문서에는 쓰지 않음)"
  m_no_domain="파일 없음"; m_no_project="프로젝트 용어집 없음"; m_make_project="만들려면 glossary 스킬의 templates/ko/project-glossary.md 를 쓴다"
  m_cut="(용어집이 10,000자 상한에 걸려 잘렸습니다. 도메인 파일을 줄이거나 활성 용어와 이력을 분리하세요.)"
fi

IFS=',' read -ra DS <<<"$(echo "$DOMAINS" | tr -d '[]" ')"
for d in "${DS[@]}"; do
  f="$ROOT/glossaries/$LANG_CODE/$d.md"
  if [ -f "$f" ]; then
    emit "## $h_domain: $d"
    emit "$(cat "$f")"
    emit ""
  else
    emit "($h_domain '$d' $m_no_domain: $f)"
  fi
done

if [ -f "$PROJ/$PROJECT_REL" ]; then
  emit "## $h_project ($PROJECT_REL)"
  emit "$(cat "$PROJ/$PROJECT_REL")"
  emit ""
else
  emit "($m_no_project: $PROJECT_REL. $m_make_project)"
fi

if [ -f "$PERSONAL" ]; then
  emit "## $h_personal"
  emit "$(cat "$PERSONAL")"
fi

if [ ${#out} -gt $LIMIT ]; then
  out="${out:0:$LIMIT}"$'\n'"$m_cut"
fi
printf '%s' "$out"
exit 0
