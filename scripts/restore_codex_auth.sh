#!/usr/bin/env bash
# cloud session で Codex の認証情報を取得する。
#
# 背景: Claude Code on the web の cloud sandbox は使い捨て VM のため、
# ~/.codex/auth.json を毎セッション用意する必要がある。
#
# 認証情報そのものを cloud environment の環境変数へ置くと、VPS 側で
# トークンが更新されても配布される値が古いまま固定され、いずれ失効する。
# そこで環境変数には取得用トークンのみを置き、実体は VPS から取得する。
# VPS 側は sync-codex-auth.sh が ~/.codex/auth.json を配信元へ同期する。
#
# 必要な環境変数: CODEX_AUTH_FETCH_TOKEN
# ローカル(VPS 等)では CLAUDE_CODE_REMOTE が true にならないため何もしない。
set -uo pipefail

readonly AUTH_PATH="${HOME}/.codex/auth.json"
readonly AUTH_URL="https://sebas.xvps.jp/codex-auth"

is_cloud_session() {
  [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]
}

has_fetch_token() {
  [ -n "${CODEX_AUTH_FETCH_TOKEN:-}" ]
}

auth_file_is_valid() {
  [ -s "$AUTH_PATH" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$AUTH_PATH" 2>/dev/null
}

fetch_auth_file() {
  mkdir -p "$(dirname "$AUTH_PATH")" || return 1
  curl --fail --silent --show-error --max-time 20 \
    -H "Authorization: Bearer ${CODEX_AUTH_FETCH_TOKEN}" \
    -o "${AUTH_PATH}.tmp" "$AUTH_URL" || return 1
  mv "${AUTH_PATH}.tmp" "$AUTH_PATH" || return 1
  chmod 600 "$AUTH_PATH" 2>/dev/null
  auth_file_is_valid
}

main() {
  is_cloud_session || exit 0

  if ! has_fetch_token; then
    echo "CODEX_AUTH_FETCH_TOKEN が未設定のため Codex 認証情報を取得できません。" >&2
    exit 0
  fi

  # 毎回取得する。VPS 側で更新されたトークンを常に反映するため、
  # 既存ファイルが妥当でも上書きする。
  if fetch_auth_file; then
    echo "Codex の認証情報を取得しました: ${AUTH_PATH}"
  else
    rm -f "${AUTH_PATH}.tmp"
    echo "Codex 認証情報の取得に失敗しました。${AUTH_URL} とトークンを確認してください。" >&2
  fi
  exit 0
}

main "$@"
