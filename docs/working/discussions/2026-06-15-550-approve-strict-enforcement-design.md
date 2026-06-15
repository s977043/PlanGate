# #550 approve 承認境界の strict enforcement — 設計ノート

> **Status**: 設計ノート（2026-06-15）。実装は HO のため別途（人間適用）。
> **位置づけ**: EPIC #527（Enforcement Integrity）子 / #500（仕様↔強制実態ギャップ）の具体実例。
> **発端**: #546 の `plangate approve`（L1-L4 Human-presence）が Codex レビューで **best-effort**（疑似 TTY バイパス可・`PLANGATE_FAKE_PPID_COMM` 本番残存）と判明。

---

> **用語**: 本ノートの「HO」は **Hardening Override**（自己改変ガード対象パス）。人間責務は「Human-owned」と表記し区別（#553 review）。

## 1. 問題

現状 L1-L4（isatty / env / ppid / nonce）は「非対話 stdin・既知 agent env・AI 親プロセス」を拒否するが、**承認の証跡が "agent が観測・応答できる" 経路（画面表示 nonce）にある**ため、疑似 TTY を持つ自動化は理論上突破できる。承認境界を「best-effort」から「**検証可能な boundary**」へ引き上げる。

核心原則（今セッションの学び）: **承認は agent が観測・応答できない out-of-band な人間アクションに紐付ける**。

## 2. 選択肢比較

| 案 | 仕組み | provenance 強度 | コスト | AI 突破耐性 |
|----|--------|----------------|--------|------------|
| **A: HMAC 署名トークン** | 人間だけが持つ secret で `HMAC(task_id‖plan_hash‖ts)` を生成。EH-3/validate が検証。**`ts` は `c3.json.approved_at` と同一値（ISO8601 UTC・秒精度）に固定**し、文字列表現のブレで検証不一致を起こさない | secret の置き場次第 | 中 | secret が AI 不可達なら強。env/file 置きは無効 |
| **B: GitHub Approve 連携** | C-3 を GitHub PR review で承認（C-4 と同方式）→ CI が c3.json 生成 | 高（GitHub 認証=out-of-band） | 高（exec 前 PR 必須） | 強（AI は GitHub 認証を持たない） |
| **C: OS keychain / Touch ID** | approve が macOS Keychain から secret 取得（Touch ID/login 必須） | 高（生体/OS 認証） | 中 | 強（AI プロセスは keychain 不可達） | 
| D（現状）: L1-L4 nonce | 画面表示 nonce を人間が打鍵 | 低〜中（best-effort） | 低 | 弱（疑似 TTY で突破可） |

### 評価
- **B が最も provenance が強く、既存 C-4（GitHub Approve）と一貫**。ただし「plan 段階で PR を要する」コストが PlanGate の plan→exec フローに摩擦。
- **A（HMAC）は #420（EH-3 provenance hardening: HMAC + プロセス系譜）と統合可能**。secret を OS keychain（C）に置けば A+C で「AI 不可達な署名鍵」が成立。
- **推奨: A（HMAC）+ C（keychain で鍵保護）を #420 と統合**。B は「重い承認」が許容される文脈（critical/リリース）でオプション化。

## 3. 段階導入

| Phase | 内容 | 層 |
|-------|------|----|
| **P0（最小ハードニング・即）** | (a) `PLANGATE_FAKE_PPID_COMM` を本番無効化（テスト専用フラグ化） (b) 対話 `read` → `read -r` (c) 既存 c3.json 上書きを既定拒否（`--force` 必須）。**ただし plan_hash が変化した場合（＝正当な Replan→再承認）は摩擦回避のため自動許可**し、同一 plan_hash の再書込のみ拒否（無意味な再承認の抑止） | bin/plangate(HO)+apply-script |
| **P1（署名基盤）** | approve が HMAC 署名を c3.json に付与。鍵は OS keychain（無ければ環境変数フォールバックを明示警告）。EH-3/validate が署名検証 | #420 統合・HO |
| **P2（強制化）** | 署名不一致/未署名の c3.json で exec を hard block（warning でなく default block） | #527 EH strict 化と連動 |
| **P3（重い承認）** | critical/リリースは GitHub Approve（案B）必須に格上げ | #487 Phase R と連動 |

## 4. 「best-effort」表現の是正（横断）

実装が P2 に到達するまでは、docs・PR・plan で **「best-effort 多層防御（絶対 boundary ではない）」** と表現する（#546 で docs 訂正済。plan.md など hash 凍結分は追補で対応）。

## 5. 未決
- [ ] secret の標準置き場（keychain 必須 vs env フォールバック許容範囲）
- [ ] #420 の HMAC 設計との具体統合点
- [ ] P0 の最小ハードニングを単独 PR にするか P1 と束ねるか
- [ ] B（GitHub Approve）を C-3 にも適用する場合の plan 段階 PR コスト許容

## 6. 一行サマリ
> #550 = approve を best-effort から「AI 不可達な署名（HMAC+keychain / #420 統合）で検証可能な boundary」へ。P0 最小ハードニング即実施、強制化は #527 と連動。
