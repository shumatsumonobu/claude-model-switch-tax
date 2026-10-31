#!/usr/bin/env bash
# 同じ内容を別のセッションで送ったとき、プロンプトキャッシュが読まれるかを調べる
# 1回の試行 ── MODEL_A に2回、続けて MODEL_B に2回
# --no-session-persistence を付けるため、どの呼び出しも新しいセッションになる
# 使い方 ── bash scripts/across-sessions.sh [試行回数]（既定は3、モデルは MODEL_A / MODEL_B で変更）
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
  prompt="$OUT/across-$t-system-prompt.txt"
  { echo "Nonce: $RANDOM-$RANDOM-$$-$(date +%s)"; cat "$SCRIPTS/system-prompt.txt"; } > "$prompt"

  step=0
  for model in "$MODEL_A" "$MODEL_A" "$MODEL_B" "$MODEL_B"; do
    step=$((step + 1))
    result="$OUT/across-$t-$step-$model.json"
    claude -p "Reply with OK only." --model "$model" --system-prompt-file "$prompt" \
      --output-format json --no-session-persistence < /dev/null > "$result"
    "$PY" -I "$SCRIPTS/cache_tokens.py" "$result" "試行$t 手順$step $model"
  done
done
