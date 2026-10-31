#!/usr/bin/env bash
# 同じセッションの途中でモデルを替えたとき、新しいモデルが前のモデルのキャッシュを読むかを調べる
# 1回の試行 ── MODEL_A で開始、MODEL_A で再開、MODEL_B で2回再開
# モデルが替わるのは手順3だけなので、そこで書き込みが増えればモデルの切り替えが原因と切り分けられる
# --resume にセッションが要るため、セッションは保存される
# 使い方 ── bash scripts/switch-in-session.sh [試行回数]（既定は3、モデルは MODEL_A / MODEL_B で変更）
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPTS/../output"
TRIALS="${1:-3}"
MODEL_A="${MODEL_A:-haiku}"
MODEL_B="${MODEL_B:-sonnet}"
mkdir -p "$OUT"

# 実際に動く Python 3 を選ぶ ── Windows では python3 が Microsoft Store の案内だけのことがあり、呼んでも失敗する
PY=""
for candidate in python3 python; do
  if command -v "$candidate" > /dev/null && "$candidate" -c "import sys; sys.exit(sys.version_info[0] < 3)" 2> /dev/null; then
    PY="$candidate"
    break
  fi
done
[ -n "$PY" ] || { echo "Python 3 が見つかりません" >&2; exit 1; }

for t in $(seq 1 "$TRIALS"); do
  # 先頭に試行ごとに異なる1行を置き、前の試行が残したキャッシュに当たらないようにする
  prompt="$OUT/switch-$t-system-prompt.txt"
  { echo "Nonce: $RANDOM-$RANDOM-$$-$(date +%s)"; cat "$SCRIPTS/system-prompt.txt"; } > "$prompt"

  result="$OUT/switch-$t-1-$MODEL_A.json"
  claude -p "Reply with OK only." --model "$MODEL_A" --system-prompt-file "$prompt" \
    --output-format json < /dev/null > "$result"
  "$PY" -I "$SCRIPTS/cache_tokens.py" "$result" "試行$t 手順1 $MODEL_A（新規セッション）"
  session_id="$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["session_id"])' "$result")"

  step=1
  for model in "$MODEL_A" "$MODEL_B" "$MODEL_B"; do
    step=$((step + 1))
    result="$OUT/switch-$t-$step-$model.json"
    claude -p "Reply with OK only." --resume "$session_id" --model "$model" --system-prompt-file "$prompt" \
      --output-format json < /dev/null > "$result"
    "$PY" -I "$SCRIPTS/cache_tokens.py" "$result" "試行$t 手順$step $model（再開）"
  done
done
