#!/usr/bin/env bash
# cloud session で Codex の認証情報を復元する。
#
# 背景: Claude Code on the web の cloud sandbox では、環境変数 CODEX_AUTH_B64 に
# base64 化した ~/.codex/auth.json を持たせている。setup script はスナップショット
# 作成時に一度だけ走り、その時点では環境変数が渡らないため書き出しが空になる。
# SessionStart hook は毎セッション走るので、ここで復元する。
#
# ローカル(VPS 等)では CLAUDE_CODE_REMOTE が true にならないため何もしない。
set -uo pipefail

readonly AUTH_PATH="${HOME}/.codex/auth.json"

is_cloud_session() {
  [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]
}

has_encoded_auth() {
  [ -n "${CODEX_AUTH_B64:-}" ]
}

auth_file_is_usable() {
  [ -s "$AUTH_PATH" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$AUTH_PATH" 2>/dev/null
}

write_auth_file() {
  mkdir -p "$(dirname "$AUTH_PATH")" || return 1
  printf '%s' "$CODEX_AUTH_B64" | base64 -d > "$AUTH_PATH" 2>/dev/null || return 1
  chmod 600 "$AUTH_PATH" 2>/dev/null
  auth_file_is_usable
}

main() {
  is_cloud_session || exit 0
  has_encoded_auth || exit 0
  auth_file_is_usable && exit 0

  if write_auth_file; then
    echo "Codex の認証情報を復元しました: ${AUTH_PATH}"
  else
    echo "Codex の認証情報の復元に失敗しました。CODEX_AUTH_B64 を確認してください。" >&2
  fi
  exit 0
}

main "$@"
