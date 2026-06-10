# tests/extras/ta-35-yaml-schema.sh
# Sourced by tests/run-tests.sh
# Issue #521: yaml 設定ファイルの schema 検証（Shadow Spec 解消）。
# 依存（pyyaml / jsonschema）欠如時はスキップ（CI には導入済み）。

printf '\n=== TA-35: yaml schema validation (#521) ===\n'

_t35_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if ! python3 -c 'import yaml, jsonschema' >/dev/null 2>&1; then
  printf '[SKIP] TA-35 — pyyaml/jsonschema 未導入\n'
else
  # TC-01: 既知ペアの一括検証が PASS
  _t35_out="$(python3 "$_t35_root/scripts/validate-yaml-schemas.py" 2>&1)" && _t35_rc=0 || _t35_rc=$?
  if [ "$_t35_rc" -eq 0 ]; then
    printf '[PASS] TA-35 TC-01: 既知 yaml が全て schema PASS\n'; pass=$((pass + 1))
  else
    printf '[FAIL] TA-35 TC-01: rc=%s out=%s\n' "$_t35_rc" "$_t35_out"; fail=$((fail + 1))
  fi

  # TC-02: 壊した yaml で FAIL する（ネガティブ検証 — 検証器が機能している証明）
  _t35_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ta35.XXXXXX")"
  sed 's/family: gpt-5$/family: not-a-valid-family/' "$_t35_root/docs/ai/model-profiles.yaml" > "$_t35_tmp/broken.yaml"
  if python3 "$_t35_root/scripts/validate-yaml-schemas.py" \
       --file "$_t35_tmp/broken.yaml" --schema "$_t35_root/schemas/model-profile.schema.json" >/dev/null 2>&1; then
    printf '[FAIL] TA-35 TC-02: 壊した yaml が PASS してしまう（検証が機能していない）\n'; fail=$((fail + 1))
  else
    printf '[PASS] TA-35 TC-02: 壊した yaml を FAIL として検出\n'; pass=$((pass + 1))
  fi
  rm -rf "$_t35_tmp"
fi
