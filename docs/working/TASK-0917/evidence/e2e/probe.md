# TASK-0917 E2E probe（使い捨て）

このファイルは AC-4 / TC-11（実 PR 1 周の手動実走）のための**検証用ダミー**です。
Collector / Executor / Reconciler を実 PR に対して 1 周させ、fixture では
検出できない実 REST レスポンス形状・push の終了コード・pre-check の実挙動を
確認する目的だけに存在します。

**この PR はマージしません。** 検証後に close / branch 削除してください
（Executor は原理的に close も branch 削除も実行できません）。

- 実走記録: `docs/working/TASK-0917/evidence/e2e/`
