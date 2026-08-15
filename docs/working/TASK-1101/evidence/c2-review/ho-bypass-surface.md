# C-2 evidence — HO 迂回面の実測（TASK-1101）

> 実施: 2026-08-15 / `origin/main` = `dfaeebb` / 実施者: オーガナイザー（C-2 統合時の裏取り）
> 目的: 敵対レビュー R-002 / R-003 の主張を一次実測で確認し、`ta-65` TC-07 の 4 ケースが**部分集合**であることを固定する。

## 実測方法

```sh
probe() {
  PLANGATE_HOOK_TASK=TASK-9999 PLANGATE_HOOK_FILE="$1" \
    sh scripts/hooks/check-plan-hash.sh </dev/null >/dev/null 2>&1
  printf "  rc=%s  %s\n" "$?" "$1"
}
```

- `PLANGATE_HOOK_TASK` を設定した **TASK 文脈**で測定（#1089 の是正後、HO は TASK 文脈でも評価される）
- `</dev/null` は stdin ハング回避（既知の運用上の注意点）
- **rc=2 = HO が block（期待値）** / **rc=0 = 迂回成立**

## 結果

### ベースライン（正規表記は正しく block される）

| 入力 | rc | 判定 |
|---|---|---|
| `CLAUDE.md` | **2** | ✅ block |
| `/Users/user/Documents/GitHub/plangate/CLAUDE.md`（絶対パス） | **2** | ✅ block（repo root 除去が効く） |
| `./CLAUDE.md` | **2** | ✅ block（`./` 除去が効く） |
| `scripts/hooks/../../scripts/hooks/x.sh` | **2** | ✅ block（`scripts/hooks/*.sh` の glob が先頭一致するため**偶然**塞がる） |

### 迂回が成立するケース（rc=0）

| 入力 | 種別 | `ta-65` TC-07 に含まれるか |
|---|---|---|
| `bin/../bin/plangate` | `..` 往復 | **含まれる**（既知 4 件） |
| `docs/../CLAUDE.md` | `..` 往復 | **含まれる**（既知 4 件） |
| `CLAUDE.MD` | 大小文字 | **含まれる**（既知 4 件） |
| `"CLAUDE.md "` | 末尾空白 | **含まれる**（既知 4 件） |
| **`/Users/.../plangate/../plangate/CLAUDE.md`** | **repo root 跨ぎ** | ❌ **未収録** |
| **`bin/./plangate`** | **`/./` セグメント** | ❌ **未収録** |
| **`bin//plangate`** | **連続スラッシュ** | ❌ **未収録** |
| **`./bin/../bin/plangate`** | **`./` + `..` の複合** | ❌ **未収録** |
| **`.//CLAUDE.md`** | **`./` + 連続スラッシュ** | ❌ **未収録** |

## 結論

1. **`ta-65` TC-07 の 4 ケースは迂回面の部分集合**。少なくとも **5 種類が未収録**で、`/./` と `//` は `..` とも大小文字とも異なる**独立した変換クラス**。
2. **`scripts/hooks/../../scripts/hooks/x.sh` が block されるのは設計ではなく偶然**（glob の先頭一致）。同じ形でも `bin/../bin/plangate` は通る＝**パターン形状に依存**しており、体系的に塞がれていない。
3. したがって **AC-1 を「既知 4 ケースが rc=2」で定義すると、4 件だけを狙い撃ちする実装が全 AC を PASS したまま穴を残せる**（敵対レビュー R-003 の指摘は成立）。

### AC への反映（R-003 の修正案を支持する根拠）

AC-1 は **「HO 9 カテゴリ × 表記変換クラス（`./` 前置 / `//` / `/./` / `..` 往復 / repo root 跨ぎ / 大小文字 / 末尾空白）およびその 2 種複合の直積が全件 rc=2」** とすべき。変換クラスは本実測で **7 種**が確認されている（当初 plan は 3 種を想定）。

## 鮮度

本実測は **`dfaeebb` 時点**。`check-plan-hash.sh` は HO 対象パスであり Human 適用でのみ変わるが、**着手時に再実測すること**（件数・rc を契約値として固定しない）。
