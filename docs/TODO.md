# 開発TODO

この順序はソース調査からの優先案。ユーザーの具体的依頼がある場合はそれを優先する。
短い指示「AGENTS.mdとdocs内の資料を読み、TODOのNOWを進めてください」で開始できるよう、各項目に対象と完了条件を置く。

## 運用

- NOWを上から1件ずつ進める。チェックなし=未完了。新しい大規模機能を自動追加しない。
- Studio/実機が必要なら、接続できる範囲で確認し、できない部分は未確認として具体的な手順を用意する。コード上の疑いだけでバグと断言せず、再現/根拠を得てから小さく修正する。
- 完了時にDONEへID・PR/コミット・確認結果を移す。CURRENT_STATEも更新する。
- 検証結果はQA_CHECKLISTの記録書式で残す。完了件数を増やすための不要なコード変更をしない。

## NOW: 新HUDを含む現行ゲームの回帰・初回体験確認

- [ ] N9 — 初回ミッション・観戦名・縮小10秒前通知の実機体験確認（ブランチ `feat/first-match-release-polish-20261008`）。
  - 実装: 既存の非表示Evolutionラベルを再利用。初戦は武器→撃破→3候補Draft、初Evolution後はセッション中の案内を終了。途中脱落なら次の試合で再挑戦。観戦時は追跡対象名をRichTextエスケープして表示。Zoneの保持残り10秒でフェーズ1回の警告音。
  - 完了条件: PC/スマホで3段階と初進化完了を観察。入退場/再試合で表示が復旧し、Draft/通知/ミニマップ/スティック/建築と重ならず、名前に記号を含むプレイヤーも安全。全Zoneフェーズで早期警告が1回だけ鳴り、縮小時の既存警告も維持。最低3試合と複数画面サイズを実機確認して記録。未実施なのでチェックは残す。



- [ ] N8 — 2026-10-08全コード再監査のStudio/実機検証（基準main `205df68`、修正ブランチ `fix/full-audit-round-combat-20261008`）。
  - 実装済み: 三人称通常射撃の誤拒否解消、BOT射撃時の向き、武器テンプレ全パーツのRoot溶接、非同期LoadCharacterのtoken保護、Sprint連打、観戦対象ID維持、AnimationConstraintの姿勢補正重複回避、全員退出の棄権処理。
  - 自動検証: GitHub Actions `tests/run.py` + `tests/preplay_analysis.py` PASS。Robloxのエンジン上の物理・テンプレ実物・高Ping・タッチ操作・実描画は未確認。
  - 完了条件: PC通常視点の全方位射撃、スマホSprint連打、観戦中の他プレイヤー死亡、BOTの後退射撃、3武器のStudio保存モデルが分離しないこと、遅いアバター読み込み/再参加、全員退出、R6/R15アニメ姿勢を含む連続3試合を確認。未確認なのでチェックは残す。


- [ ] N7 — 近接肩越しAIMのStudio/実機検証。
  - 実装: `feat/close-shoulder-aim`、基準main `dd97341`。run.py/preplay PASS。手順: [SHOULDER_AIM_QA](SHOULDER_AIM_QA.md)。
  - 完了条件: PC/スマホで3武器の上半身構図、壁際のカメラ遮蔽と射撃、AIM解除の距離復元、Reload/移動/建築/Draft/観戦/次戦を連続3試合確認。Studio描画/実機未確認のため未完了。


- [ ] N6 — スマホ戦闘/建築HUDの実機検証。
  - 実装ブランチ: `feat/mobile-combat-build-hud`、基準main `a9cf399`。オフラインrun.py/preplay PASS。操作と配置図は[MOBILE_HUD_QA](MOBILE_HUD_QA.md)。
  - 完了条件: 小型/ノッチ付きiPhone・タブレットで標準操作との干渉、AIM弾薬不変、保持Fireから建築への切替、選択→PLACE、移動/視点/Jump、Draft、死亡/結果→次戦、PC回帰を連続3試合確認。実機未確認。


- [ ] N5 — 連射ジッター/観戦Shot配信の実機回帰確認。
  - 対象: server/Combat.lua、tests/regression.lua。修正ブランチ `fix/fire-jitter-spectator-feedback`。
  - オフライン: run.py PASS（gameplay 973 assertions）、preplay PASS。10要求のジッター、発射上限、待機1件、死亡/Reload/装備/Results/次戦/退出の取消、遠方観戦/途中参加/生存者距離制限を模擬確認。
  - 完了条件: PC/スマートフォンの長押し連射、通信遅延を加えた射撃、待機中の死亡/Reload/装備切替、遠方対象の観戦Tab切替、途中参加、結果→次戦を連続3試合確認。実機未確認のため未完了を維持。


- [ ] N4 — Fireボタンドラッグ照準のStudio/スマートフォン回帰確認。
  - 対象: Main.client.lua、FireDrag.lua、PresentationConfig、[MOBILE_FIRE_DRAG_QA](MOBILE_FIRE_DRAG_QA.md)。
  - 実装: PR #23参照。client-onlyは249 assertions PASS、preplay PASS。PR #23時点の全体tests/run.pyは基準main由来の模擬環境不足でFAILだったが、fix/connect-round-safe-spawnsでテスト環境を補完し全体PASSを確認。
  - 完了条件: 実機でFire開始→ドラッグ→連射→離して停止、二重回転なし、移動+Jump/UIとの同時操作、反動/肩寄せ/Aim Assist/遮蔽、死亡/respawn/連続3試合とPC回帰。機種・感度・結果を記録。実機未確認のためチェックは残す。
  - AIM / FIRE分離後は、AIMを複数回トグルしても弾薬不変、AIM中のFIREドラッグ、FIRE解除後もAIM維持、解除後の通常カメラ復帰も確認する。


- [ ] N0 — 開始スポーンの建物めり込み修正をStudioで回帰確認。
  - 対象: server/Round.lua、World.lua、tests/spawns.lua、QAのSpectate / ラウンド / Multiplayer。
  - 修正: fix/connect-round-safe-spawnsブランチで人間/BOTの配置直前にresolverを接続、共通28 studs予約、島内探索、BOT補充削減/人間次戦待ち、遅延読込除外。PR #21は生成時のみresolver使用で、開始時の再検査が欠けていた。
  - オフライン: tests/run.py・preplay_analysis PASS。人間/BOTの呼び出しを個別に外すmutationでテストが失敗することも確認。詳細と基準SHAはCURRENT_STATE。
  - 完了条件: Solo/複数人で連続3試合、TownTemplates/Warehouse/Collision/Tree/Coverへのめり込みなし・即移動可能・全組合せ28 studs間隔・候補不足/塞がれた候補/読込遅延/結果→次戦の復旧を確認。Studio未確認のためチェックは残す。
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
- [ ] X3 — 武器/BOTの見た目を改善。対象: Cosmetics/Actors/Presentation。武器はStudio保存WeaponModels対応とfallback、肩越しAim、Rifle / ShotgunのR15両手構えまで実装済み。残りはBOT本体外観とスマートフォン実機/複数人での静止・移動・Sprint・Slide・射撃・Reload姿勢確認。完了条件: Combat/Actor/Draftの契約を保ち、装飾が衝突/Raycastへ混入しない。
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
