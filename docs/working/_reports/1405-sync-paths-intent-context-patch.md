# PR #1405: sync-plugin-plangate.yml の paths: に intent_context_contract.py を加える HO patch

`scripts/sync-plugin-plangate.sh` は PR #1405 から `$REPO_ROOT/scripts/intent_context_contract.py`
を `plugin/plangate/skills/ai-loop-cycle/scripts/` へ同梱する。この入力は
`.github/workflows/sync-plugin-plangate.yml` の `on.push.paths` / `on.pull_request.paths`
に載っていないため、このファイルだけを変える PR では drift-check が起動しない。

`.github/workflows/**` は Hardening Override の対象なので、AI は適用しない（Human-owned）。

## 適用前後の ta-71

| TC | 適用前（PR #1405 head） | 適用後 |
|----|------------------------|--------|
| TC-20 未被覆 × KNOWN-GAP 宣言 | FAIL（宣言に無い gap: `UNCOVERED push/pull_request scripts/intent_context_contract.py`） | PASS |
| TC-22 非対称 × KNOWN-GAP 宣言 | FAIL（TC-20 と同じ GAPDECL=mismatch を共有） | PASS |
| TC-23 入力インベントリ | PASS | PASS |
| ta-61 TC-12（ta-71 の standalone rc） | FAIL（rc=1） | PASS 見込み（ta-71 standalone rc=0 を複製環境で実測） |

`tests/fixtures/sync-paths-known-gap-1249.flag` には本入力を**追加しない**。flag は #1249 の
既知 gap の列挙であり、新しい未被覆入力を吸収する用途ではないため。

## 適用手順（Human）

main 上（本 PR のマージ後）で実行する。

```sh
DOC=docs/working/_reports/1405-sync-paths-intent-context-patch.md
T="$(mktemp)"
awk 'BEGIN{q=sprintf("%c",96)}
     /^<!-- PG-PATCH-BEGIN -->$/{b=1;next}
     /^<!-- PG-PATCH-END -->$/{exit}
     b && substr($0,1,1)==q{f=!f;next}
     f' "$DOC" > "$T"
git apply --check "$T" && git apply "$T"
sh tests/extras/ta-71-ci-static-lint.sh   # [FAIL] 0 件・rc=0 を確認
# 戻す場合: git apply -R "$T"
```

<!-- PG-PATCH-BEGIN -->

```diff
diff --git a/.github/workflows/sync-plugin-plangate.yml b/.github/workflows/sync-plugin-plangate.yml
index 6626f65c..e4accf29 100644
--- a/.github/workflows/sync-plugin-plangate.yml
+++ b/.github/workflows/sync-plugin-plangate.yml
@@ -15,6 +15,7 @@ on:
       - 'docs/workflows/ai-loop/**'
       - 'scripts/ai-loop/**'
       - 'scripts/_ai_loop_link_rewrite.py'
+      - 'scripts/intent_context_contract.py'
       - 'scripts/sync-plugin-plangate.sh'
       - 'scripts/install-plangate-skills-to-codex.sh'
       - 'plugin/plangate/**'
@@ -27,6 +28,7 @@ on:
       - 'docs/workflows/ai-loop/**'
       - 'scripts/ai-loop/**'
       - 'scripts/_ai_loop_link_rewrite.py'
+      - 'scripts/intent_context_contract.py'
       - 'scripts/sync-plugin-plangate.sh'
       - 'scripts/install-plangate-skills-to-codex.sh'
       - 'plugin/plangate/**'
```

<!-- PG-PATCH-END -->

## 検証記録（2026-09-25）

- 複製 clone（PR head `3f083b0d` + 本 PR の ta-71 静的入力表の追従）へ上の patch を当て、
  YAML として読めることと `sh tests/extras/ta-71-ci-static-lint.sh` の rc=0 / `[FAIL]` 0 件を確認した
- `docs/working/TASK-1232/patches/sync-plugin-paths.patch`（#1249 の未適用 patch）とは別の
  行に当たる。両方を適用する場合は 1 本ずつ適用して ta-71 を再実行すること
