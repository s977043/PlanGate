# TEST CASES — TASK-0134 (#571)

## AC → TC
### AC-01: --progress で逐次表示
- TC-01: stub reviewer 2本で `--progress` 実行時、`[done 1/2] <provider> ok|failed` と `[done 2/2] ...` が完了順に出力。種別: 機械（HO適用後）
### AC-02: 後方互換
- TC-02: `--progress` 無しの出力が変更前と完全一致（diff 空）。種別: 機械
### AC-03: collect/assemble 不変
- TC-03: R-NNN 集約結果と decision-log の parallel_review イベントが従来と同一。種別: 機械
### AC-04: privacy 遵守
- TC-04: 進捗出力に token/sec/throughput/出力抜粋が含まれない（provider名・完了数・ok/failed のみ）。種別: 機械(grep)+レビュー
### AC-05: status 破損の安全側 + 完了検出の区別（Refs: R-001）
- TC-05: 子プロセス終了検出後に status_NNN が空/欠落のとき `[done X/N] <provider> failed` と表示。種別: 機械
- TC-06: 未完了（status 未作成・子稼働中）を `done` と誤カウントしない（完了数は子終了検出数と一致）。種別: 機械

### AC-06: 引数互換（Refs: R-002）
- TC-07: 既存オプションとの併用順序違いで壊れない / 未知オプションは従来どおりエラー / `--progress` が `_review_parallel` 以外の経路へ漏れない。種別: 機械

## Edge cases
- EC-01: reviewer 1本（並列でない単体）でも --progress が壊れない
- EC-02: 全 reviewer 失敗時も全件 [done] 表示後に collect が従来どおり警告
- EC-03: --progress はポーリング sleep 1s で busy-loop しない
