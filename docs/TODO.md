# 開発TODO

この順序はソース調査からの優先案。ユーザーの具体的依頼がある場合はそれを優先する。
短い指示「AGENTS.mdとdocs内の資料を読み、TODOのNOWを進めてください」で開始できるよう、各項目に対象と完了条件を置く。

## 運用

- NOWを上から1件ずつ進める。チェックなし=未完了。新しい大規模機能を自動追加しない。
- Studio/実機が必要なら、接続できる範囲で確認し、できない部分は未確認として具体的な手順を用意する。コード上の疑いだけでバグと断言せず、再現/根拠を得てから小さく修正する。
- 完了時にDONEへID・PR/コミット・確認結果を移す。CURRENT_STATEも更新する。
- 検証結果はQA_CHECKLISTの記録書式で残す。完了件数を増やすための不要なコード変更をしない。

## NOW: 新HUDを含む現行ゲームの回帰・初回体験確認

- [ ] N4 — Fireボタンドラッグ照準のStudio/スマートフォン回帰確認。
  - 対象: Main.client.lua、FireDrag.lua、PresentationConfig、[MOBILE_FIRE_DRAG_QA](MOBILE_FIRE_DRAG_QA.md)。
  - 実装: improve-mobile-fire-drag-aimingブランチのPR差分参照。client-onlyは249 assertions PASS、preplay PASS。全体tests/run.pyは基準main由来の未登録PresentationConfigでFAIL。
  - 完了条件: 実機でFire開始→ドラッグ→連射→離して停止、二重回転なし、移動+Jump/UIとの同時操作、反動/肩寄せ/Aim Assist/遮蔽、死亡/respawn/連続3試合とPC回帰。機種・感度・結果を記録。実機未確認のためチェックは残す。


- [ ] N0 — 開始スポーンの建物めり込み修正をStudioで回帰確認。
  - 対象: server/World.lua、QAのSpectate / ラウンド / Multiplayer。
  - 修正: 建物モデルのXZ footprintと実衝突物を避け、塞がれた外周スポーンは近傍→道路→外周再探索で安全位置へ補正する。
  - 完了条件: Soloを含む複数試合で開始直後に建物/壁/Tree/Coverへめり込まず移動でき、BOTも同じ安全スポーン群から開始する。Studio未確認のためチェックは残す。
- [ ] N1 — PC HUD / Draft / Spectateの回帰確認。
  - 対象: client/Hud.lua、Main.client.lua、Presentation.lua、HUD_PLAYTEST。
  - 手順: 既存オフライン2コマンド、QAのUI/Evolution/Spectate/ラウンド。PCの小窓・通常・ultrawideを確認する。
  - 完了条件: READY/V開閉、パネルクリック非貫通、選択中移動/射撃、5秒自動選択、死亡後Tab、次戦リセットが期待通り。実機未確認なら未完了を維持。再現した不具合だけ修正する。
- [ ] N2 — モバイルと2人以上の同一サーバー回帰確認。
  - 対象: QAのモバイル/Multiplayer/戦闘/移動。詳細PLAYTESTも参照。
  - 完了条件: 移動+視点+射撃の同時操作、Draftタップ、装備/姿勢/建築、死亡/退出/途中参加、連続3試合で破綻なし。機種/人数/ログを記録。
- [ ] N3 — 初回10分の実プレイを評価し、最重要の改善1件を選ぶ。
  - 対象: Roundの診断ログ、BOT、Loot、HUD。機能追加ではなく初動の迷い・射撃感・進化体験を観察。
  - 完了条件: 武器取得/初戦闘/初Draftまでの時間、迷った操作、BOT/Zone死の傾向を記録し、根拠付き改善をNEXTの先頭へ追加。理論値だけでバランスを変更しない。

## NEXT: 実測した問題と見た目・操作の仕上げ

- [ ] X1 — NOWで再現した最重要の不具合/操作障害を小さく修正。完了条件: 再現手順で解消、関連回帰+次戦確認、文書更新。
- [ ] X2 — 空のAnimation IDと足音/SlideLoopを段階的に補完。対象: AnimationConfig/AudioConfig、Animations/Audio/Presentation。完了条件: 許可済み素材、R6/R15とロード失敗fallback、死亡/リセットの停止、モバイル負荷確認。
- [ ] X3 — 武器/BOTの見た目を改善。対象: Cosmetics/Actors/Presentation。武器はStudio保存WeaponModels対応とfallback、肩越しAimのStudio確認まで完了。残りはBOT本体外観とスマートフォン/複数人での姿勢確認。完了条件: Combat/Actor/Draftの契約を保ち、装飾が衝突/Raycastへ混入しない。
- [ ] X4 — StudioのTownTemplates採用状況を確認し、必要なら候補を整備。完了条件: TOWN_BUILDINGSの検査、Rojo後の保持、入口/BOT経路/Loot/射線/スマホ視認性の確認。
- [ ] X5 — 実ログに基づくBOT圧力・Shotgun・Zone時間・建築Energyの調整。完了条件: 変更前後を比較し、初動/終盤/Evolutionを含む共通ルールと回帰を維持。

## LATER: 別途スコープを決める候補

- [ ] L1 — 低性能モバイルの実測最適化。BOT11+建築100+演出の計測を基に対象を絞る。
- [ ] L2 — 公開状況に応じた速度/teleport等の不正対策。信頼境界と誤検知を設計してから実装。
- [ ] L3 — オンボーディング/継続率の計測。個人情報を増やさず、最初の10分の改善仮説を比較する。
- [ ] L4 — 永続進行、降下演出、高度建築などの拡張検討。Evolutionの独自性・モバイル負荷・既存仕様との関係を先に決める。

## DONE

| ID | 完了項目 | 根拠 / 検証 |
| --- | --- | --- |
| D0 | AI開発用5文書の整備とRojo境界の静的確認 | この文書を追加するPRの差分を参照。基準mainはCURRENT_STATE。Studio/実機QAは完了に含めない。 |

完了追記例: `N1 | Draft入力回帰確認 | PR #番号 / commit SHA、PC解像度、PASS項目、未確認なし`。
