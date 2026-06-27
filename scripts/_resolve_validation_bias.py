#!/usr/bin/env python3
"""_resolve_validation_bias.py — TASK-0147 / #527 follow-up

model-profiles.yaml の指定 profile key から validation_bias を解決して stdout に出力する。

Usage:
    python3 scripts/_resolve_validation_bias.py <profile_key> [model-profiles.yaml path]

出力:
    stdout に解決した bias（normal|strict|lenient のいずれか）を 1 行で出力。
    解決できない場合（未知 key / yaml 欠落・破損 / pyyaml 未導入）は安全側で
    "normal" を stdout に出力し、理由を stderr に警告出力する（サイレント失敗防止）。

終了コード:
    0  正常解決（strict/normal/lenient を出力）
    0  fallback（normal を出力 + stderr 警告）— 呼び出し側を止めない安全側
    2  引数不足（profile_key 未指定）
"""
import sys

VALID_BIASES = ("normal", "strict", "lenient")


def _warn(msg):
    sys.stderr.write("[validation-bias] WARN: %s (fallback=normal)\n" % msg)


def main(argv):
    if len(argv) < 2 or not argv[1].strip():
        sys.stderr.write("Usage: _resolve_validation_bias.py <profile_key> [yaml_path]\n")
        return 2

    profile_key = argv[1].strip()
    yaml_path = argv[2] if len(argv) >= 3 else "docs/ai/model-profiles.yaml"

    try:
        import yaml
    except Exception:
        _warn("pyyaml not available")
        print("normal")
        return 0

    try:
        with open(yaml_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        _warn("model-profiles.yaml not found: %s" % yaml_path)
        print("normal")
        return 0
    except Exception as e:
        _warn("failed to parse %s: %s" % (yaml_path, e))
        print("normal")
        return 0

    if not isinstance(data, dict):
        _warn("model-profiles.yaml is not a mapping")
        print("normal")
        return 0

    models = data.get("models")
    if not isinstance(models, dict):
        _warn("no 'models' mapping in %s" % yaml_path)
        print("normal")
        return 0

    profile = models.get(profile_key)
    if not isinstance(profile, dict):
        _warn("unknown profile key: %s" % profile_key)
        print("normal")
        return 0

    bias = profile.get("validation_bias")
    if bias not in VALID_BIASES:
        _warn("profile '%s' has no valid validation_bias (got: %r)" % (profile_key, bias))
        print("normal")
        return 0

    print(bias)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
