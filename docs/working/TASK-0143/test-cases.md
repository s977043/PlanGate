# TASK-0143 テストケース定義 — hook 6→12 配線

## 受入基準 → テストケース マッピング

| 受入基準（#527 / 本PBI） | テストケース |
|------------------------|-------------|
| AC-1: hook-enforcement.md 配線表が 12/12 | TC-07 |
| AC-2: doctor / CI が配線 drift を機械検出 | TC-04, TC-05 |
| AC-3: 群A（EH-4/5/7）が各フェーズで発火 | TC-01, TC-02, TC-03 |
| AC-4: 群B（EHS-1〜3）が strict 時のみ発火・既定は非発火 | TC-06, TC-08 |
| AC-5: 既存6 hook 配線・既定挙動が非退行 | TC-09 |

## テストケース一覧

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-01 | test-cases.md 不在の TASK | V-1 フェーズ呼出 | EH-4 が warning（strict 時 block） | Integration |
| TC-02 | evidence/verification.md 不在 | PR 作成フェーズ呼出 | EH-5 が warning（strict 時 block） | Integration |
| TC-03 | c3/c4 いずれか未 APPROVED | merge フェーズ呼出 | EH-7 が warning（strict 時 block） | Integration |
| TC-04 | 群A未配線状態（settings/conductor から呼出欠落） | `bin/plangate doctor --check-settings` | exit≠0 + drift 明示 | Unit |
| TC-05 | 群A配線済み | `bin/plangate doctor --check-settings` | exit 0 | Unit |
| TC-06 | `validation_bias: strict` プロファイル | standard mode で V-3 なし PR | EHS-1 が block | Integration |
| TC-07 | 配線完了後 | hook-enforcement.md 配線表 + doctor 出力 | 12/12 が両者一致 | Unit |
| TC-08 | 非strict（既定）プロファイル | handoff 6要素欠落 / fix loop 6回 | EHS-2/EHS-3 **非発火**（既定挙動不変） | Integration |
| TC-09 | 既存 EH-1/2/3/6/9 配線 | `sh tests/run-tests.sh` | 全 PASS（退行なし） | Regression |

## エッジケース

- **E1**: 群A配線を default=warning で導入した直後、`PLANGATE_HOOK_STRICT=1` 設定時に block へ昇格すること（段階化の両モード確認）
- **E2**: EH-7 が hook 側 block と GitHub branch protection の二重化未完でも、hook 側単独で warning/block 判定できること（GH連携は別PBIでも本PBIの配線は成立）
- **E3**: doctor wiring 検証が、コメント行（`_comment_`）だけの hook 記述を「配線済み」と誤判定しないこと（実 command 行の存在で判定）
- **E4**: 群B発火層が未確定（C-3保留）の場合、群A配線のみで run-tests が PASS し段階リリース可能なこと
