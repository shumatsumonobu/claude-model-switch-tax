"""claude -p --output-format json の結果から、プロンプトキャッシュのトークン数を取り出して表示する。

write はキャッシュに新しく書き込んだ分（cache_creation_input_tokens）、
read はキャッシュから読み込んだ分（cache_read_input_tokens）。
括弧内は書き込みの TTL ごとの内訳で、1h が TTL 1時間、5m が TTL 5分。

使い方: python cache_tokens.py <結果のJSON> <ラベル>
"""
import json
import sys


def main() -> None:
    path, label = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as f:
        result = json.load(f)
    usage = result["usage"]
    ttl = usage.get("cache_creation", {})
    line = (
        f"{label}: "
        f"write={usage['cache_creation_input_tokens']} "
        f"read={usage['cache_read_input_tokens']} "
        f"(1h={ttl.get('ephemeral_1h_input_tokens', 0)} "
        f"5m={ttl.get('ephemeral_5m_input_tokens', 0)})\n"
    )
    # print は Windows だとコンソールの文字コード（cp932 など）で書き出そうとして日本語が壊れるため、
    # UTF-8 のバイト列を直接書き出す
    sys.stdout.buffer.write(line.encode("utf-8"))


if __name__ == "__main__":
    main()
