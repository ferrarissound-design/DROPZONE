# 現在の実装状態

- 調査日: 2026-10-09
- 調査対象: ferrarissound-design/DROPZONE のmain
- 基準コミット: `055bcded6dd018b7f7374a305d610cf84fd89c7e`（2026-10-09 スマホUI・しゃがみ修正時main）
- この記録はソース調査。コードに存在することと、Studio/実機で正常動作したことは区別する。以下の実装一覧は実機検証済みの意味ではない。
- 更新時は最新mainとの差分を確認し、基準SHAと実施した検証を更新する。

## 2026-10-09 スマホUI・しゃがみ修正

- ブランチ: `fix/mobile-ui-grounded-crouch-20261009`。補助操作ボタン64→52（18.75%縮小）、背景透明度.35→.62。FIREは72を維持しオレンジ背景、建築切替との縦間隔8→22。AIM/FIRE独立とFireDrag入力処理は維持。ミニマップ122×78→104×66。安全領域・可変キャンバス・PCのHUD/入力は変更しない。
- PR #34 Codex P2対応: ミニマップを縮小した後も固定中心(61,39)/倍率78のままだった問題を修正。Hudの現行Minimap Sizeから中心・等方倍率を算出し、現/次Zone円とマーカーを同じ座標系で描画する。モバイル104×66とPC122×78の中心・座標投影・リング直径の回帰テストを追加。Studio実画面での見た目は未確認。
- 根本原因: Crouch/SlideアニメーションIDが空のままHipHeightを1.15下げていたため、脚を曲げず身体全体を地面へ沈めていた。HipHeightを初期値に保ち、CrouchPoseでR15の股関節/膝/足首、R6の股関節を曲げる。リグ寸法と関節C0/C1から脚の短縮量・足の最下点を計算し、胴体だけを下げ、両足の静止時の高さと水平位置を補正する。
- RootPartのCFrame・速度・衝突サイズを姿勢のために書き換えず、接地/斜面/段差は既存Humanoidへ委ねる。C0は状態切替時だけ更新、立つ/Jump/Sprint/死亡/リセットで元値を復元。R6は膝なしのため簡易姿勢。標準Motor6Dチェーンのないカスタム/AnimationConstraintリグはHipHeight維持の安全fallback（視覚的なしゃがみは未対応）。未確認Asset IDを追加しない。
- 自動検証: `python3 tests/run.py` PASS。R6/R15×3体格×5回切替で足最下点/水平位置/全C0復元など307 assertions。画面サイズ別配置1054 assertions、既存戦闘/建築/移動/射撃/AIM/次戦回帰もPASS。`python3 tests/preplay_analysis.py`・`git diff --check` PASS。
- Studio/スマホ/PCの実描画・実物理は未実施。歩行アニメーションとの合成、斜面/段差、機械化装甲、root基準の銃との位置関係、滑走の見た目は[MOBILE_CROUCH_QA](MOBILE_CROUCH_QA.md)で確認する。静止時の数値検証を実機成功と扱わない。

## 2026-10-08 PR #33 カメラ透明度レビュー修正

- 対象: PR #33、レビュー時head `30c575ac82b0739b35fab2ad7cdda0faf6e7b253`。main基準は上記SHA。
- EvolutionVisibilityが通常時にも登録時の透明度を毎フレーム書き戻し、カメラの一人称非表示を上書きしていた。AIM開始時のLocalTransparencyModifierを保存し、AIM中だけ非表示、解除時に一度復元して以降はカメラへ制御を返す方式へ修正。
- clearもAIMで所有していた値だけ復元。AIM外のカメラ透明度を変更しない。AIM開始前/解除後のカメラ変更、反復フレーム、AIM中/外のclearを両Rigの模擬テストで確認。
- tests/run.py・preplay_analysis.py PASS。Studioの一人称ズーム、肩越しAIMとの往復、実機描画は未検証。PR #33は未マージ。

## 2026-10-08 プレイヤー専用進化外見

- ブランチ: `feat/player-evolution-visuals-20261008`。確認mainは上記SHA。段階/能力対応/検証手順は [PLAYER_EVOLUTION_QA](PLAYER_EVOLUTION_QA.md)。
- 新しいserver/PlayerEvolutionVisualsで0/1〜2/3〜4/5以上の4外見段階を管理。11能力の部位別パーツを共存させ、能力IIIで増大・発光強化。最大形態で胸部コアと背部ユニット/タワーを追加。BOTは旧Mutationを含め進化装飾なし、能力/AIは既存どおり。
- サーバー確定後に約0.45秒のTween/Highlight/小パルス。全能力IIIの常設50Part、ハード上限64、人の同時演出4。Particle/Lightなし。R6/R15の各身体部位へ非衝突Weldで接続。
- 自分のAIM中はclient/EvolutionVisibilityで装飾だけローカル非表示。旧ローカルPulseを撤去し効果音は維持。Resultsで全装飾破棄、死亡で演出停止、Actor再登録で残留除去。
- オフライン: tests/run.pyとpreplay_analysis.py PASS。実装を実行する両Rig/Stack/能力混在/全能力/欠損部位/BOT/同時演出/連続callback/AIM/リセットの模擬回帰を追加。Studio描画/物理/通信・スマホFPS/兵士素材実物は未検証。TODOの確認項目を未完了のまま残す。

## 2026-10-08 実プレイ計測の準備

- 実装ブランチ: `feat/first-match-playtest-metrics-20261008`（PR #32）。基準main `805fd4a`。
- 人間の初Weapon pickup、初Shot、初Kill、初Evolutionまでの経過秒数をActorの既存診断辞書へ1回だけ記録。成功したサーバーActionと既存イベントを使用し、クライアント申告値に依存しない。ログはResults時にだけ出す。
- 未達成の項目は `-`、達成は小数第1位の秒数。Build/Loot/Evolution/Combatの判定、命中/抽選/確率、UI、通信、DataStoreを一切変更しない。
- `Config.PlaytestDiagnostics` の既存スイッチで出力を停止できる。レコードは各ラウンドのActor破棄と共に消滅。実機でログを収集し、初動でどこに迷うかを評価するN3は引き続き未完了。

## 2026-10-08 初回体験の小型リリース改善

- 実装ブランチ: `feat/first-match-release-polish-20261008`、PR #31。基準main `530a43d`。
- Hud: 現在使用していないEvolution小型ラベルを再利用し、初心者へ「武器取得→初撃破→進化選択」を段階表示。最大90秒/試合、初Evolution取得後はセッション中繰り返さず4秒の達成表示。サーバーSnapshotの既存 `weapon`、`kills`、`evolutionDraft`、`evolutions` のみ使用。端末間に進行保存はしない。
- Main/Hud: 観戦中のActor ID追従に合わせ、その対象の表示名を左上に表示。RichTextエスケープ済み、戦闘へ復帰すれば非表示。
- Presentation: Zoneの保持時間が残り10秒以下になった最初のSnapshotで音声を1回再生。従来の縮小開始警告は維持。死亡・結果・次のラウンドでフェーズ記録をリセット。
- テスト: クライアント観戦と名前、HUDのガイド段階・終了・再試合・記号名、Zone通知フェーズ数を模擬検証。Studio/実機での安全領域・出音・Draft重なりは未確認。TODO N9参照。

## 2026-10-08 全コード再監査の修正記録

- 調査main: `205df68`。実装: `fix/full-audit-round-combat-20261008`（PR #30）。
- Combat.lua: 150度のアバター正面制限を解除。通常の三人称カメラが後方を向く場合も発砲できるようにした。型・有限数・弾薬・発射間隔・サーバー起点Raycastと既存レート制限は継続。これはaimbot検出を実装したことを意味しない。
- Round.lua: ロビー/開始の非同期LoadCharacterAsyncにloadTokenを導入し、古い完了処理が新しいロックを解除するのを防止。遅着者のロビー送還を明示。全プレイヤーが退出した試合は勝利を授与しない。
- Cosmetics.lua: 保存WeaponModelsの既存関節・制約を安全に削除後、各部品をRootへ新しいWeldConstraintで接続。現物モデルのサイズ/位置/動作はStudioで未確認。
- Bots.lua: 射撃するBOTの胴体を敵に向け、逃走MoveToと見た目の銃口方向が食い違いにくいように変更。射撃をしない場合はAutoRotateを復元。
- Main.client.lua: モバイルSprintの未確認入力状態を短時間保持し連続ON/OFFを正しく送信。観戦対象を配列番号でなくActor IDで維持。
- Presentation.lua: AnimationConstraintのTransformが次のアニメ評価でリセットされなかった場合、前回の追加姿勢を再び掛けないように補正の元Transformを記録。
- 回帰: tests/spawns.lua、tests/client.lua、tests/regression.lua、tests/run.pyを更新。GitHub ActionsのLua回帰/Preplay分析PASSを確認。Studio・実機・通信遅延・テンプレアセット実物の検証は残る。
- 検証タスクは [TODO N8](TODO.md) に未完了で記録。

## 実装済み

[GAME_DESIGN](GAME_DESIGN.md)にルールを集約。以下は調査時点の実装と入口。

| 領域 | ソースで確認した実装 |
| --- | --- |
| ラウンド | Round/Actors: 7状態、参加上限20、標準12体にBOT補充、途中参加待機、死亡/退出、勝敗/DRAW、全リセット |
| Combat | Combat/WeaponStats: 3武器、3レアリティ、サーバー命中、Shotgun減衰、Reload世代、装備/上位取得 |
| Loot/Build | 自動取得と排他的claim、回復/Shield/Energy、Wall/Floor/Ramp、重なり拒否、破壊/期限/上限 |
| Evolution | 11能力、3候補、5秒自動選択、最大III、カテゴリ多様性、キュー、BOT選択、プレイヤー専用の段階装甲 |
| Movement | Sprint/Crouch/Slide、接地と速度確認、Jump解除、死亡/結果時姿勢リセット |
| BOT/Zone | 有界Pathfinding、開幕10秒のLoot優先（被弾時反撃）、視線射撃、Zone退避、5段階縮小/ゼロ半径 |
| HUD/Spectate | 日本語中心HUD、PCの状況表示、モバイル操作、READY/V、Tab/ボタン観戦、ミニマップ、結果 |
| 演出 | Audio/Animations/Presentation/Effects/DamageFeedback、相対FOV、反動、確認済みダメージ/撃破、プール上限 |
| マップ | World/Town/Cosmetics/MapVisuals、5 POI、生成建物、外部テンプレート検査と生成版fallback |
| 通信/診断 | Action/Snapshot/Effects、roundId、生存/型/有限数、20要求/秒・burst30、5Hz Snapshot、Results診断 |

## 未完成・改善余地・未確認

| 項目 | 分類 / 根拠 | 次の判断 |
| --- | --- | --- |
| PC新HUD、Aimと近距離遮蔽、観戦/次戦 | Studio検証未記録。HUD_PLAYTESTとSHOT_FEEDBACK_PLAYTESTに確認手順あり | NOWのプレイテストで再現条件を記録 |
| モバイル入力/安全領域/負荷 | ソースとテストの模擬環境だけでは実機の描画・入力・FPSを保証できない | 実機で複数同時操作・連続試合・最大建築負荷を確認 |
| カスタムAnimation | AnimationConfigのR6/R15 IDがすべて空。コントローラーはあるが専用Trackは設定されていない | NEXTで許可済みAssetを選び、未設定fallbackを維持 |
| 足音/SlideLoop | AudioConfigのFootstep・SprintFootstep・SlideLoopは空。他の効果音には外部IDあり | 適切な単発/Loop素材とロード確認 |
| BOT・武器の見た目 | 武器は任意のStudio保存WeaponModelsを利用でき、欠落時は手続き生成へfallback。BOT本体は簡易Rig | BOT外観と各端末での武器姿勢を段階的に改善 |
| TownTemplates実物 | 対応コードあり。ただしStudio保存モデルは本リポジトリに含まれず、採用済みとは断言できない | Studio側で存在・Collision・経路を確認 |
| バランス/初動 | PREPLAY_ANALYSISは理論値。武器感触、Zone死比率、初回進化までの時間は実測なし | 診断ログと実プレイで判断 |
| 移動の不正検知 | 通常のRoblox character network ownership。完全な速度/teleport/aimbot検知なし | LATER。サーバー射撃検証は保持 |
| 降下/永続化/高度建築/Mantle | 現在未実装。地上スポーン、試合ごとリセット、地表建築 | 要求がない限り自動追加しない |

## 開発用検証と既存資料

- `python3 tests/run.py`: 構文、ゲーム回帰、表示/入力のengine double、照準数学など。
- `python3 tests/preplay_analysis.py`: 武器/Zone/建築の理論値、レアリティ/Draftの決定的サンプル。
- [QA_CHECKLIST](QA_CHECKLIST.md): 今後の回帰確認と結果記録。
- [PLAYTEST](PLAYTEST.md): 詳細なStudio手順。[HUD_PLAYTEST](HUD_PLAYTEST.md) / [SHOT_FEEDBACK_PLAYTEST](SHOT_FEEDBACK_PLAYTEST.md): 入力・表示・戦闘演出。
- [ARCHITECTURE](ARCHITECTURE.md): 境界/権威/負荷。[TOWN_BUILDINGS](TOWN_BUILDINGS.md): 外部建物。[AIM_RAYCAST_FIX](AIM_RAYCAST_FIX.md): 照準修正の背景。
- 古い資料には「Audioは延期/外部Assetなし」など過去時点の記述がある。現在はAudioConfigに効果音IDが存在する。READMEの旧操作表より、PC READY/Vとパネル入力は最新コード・HUD_PLAYTESTを優先する。

## Rojo同期の確認

default.project.jsonの全`$path`を調査: `src/shared`、`src/server`、`src/client`のみ。ルートAGENTS.mdとdocs/*.mdは全て対象外。
TownTemplatesとWeaponModelsは各フォルダ内だけ`$ignoreUnknownInstances: true`とし、Studio保存モデルをRojo同期から保護する。ServerStorage全体には設定しない。

## 今回の確認結果（2026-10-01）

- python3 tests/run.py: PASS（ゲーム938、表示810、クライアント/サーバー202のassertion表示とソース検査）。
- python3 tests/preplay_analysis.py: PASS。
- 既存/新規Markdownの相対リンクとRojo $path範囲外を静的検証: PASS。
- Studio/Rojo実接続・スマートフォン・複数人実プレイ: 今回未実施。

## 開始スポーンめり込み修正（2026-10-04）

- ユーザー実プレイで「ラウンド開始時に建物内部へめり込み、移動不能」を確認。
- 原因: 24個の開始候補が半径245の固定円周で、Townの配置とStudio保存TownTemplatesの最大50x34x50 footprintが交差し得る一方、開始前に建物占有を検査していなかった。
- 修正: Worldが建物モデル全体のXZ footprint（余白4 studs）と実際の衝突物を検査し、塞がれた候補は外周近傍、空いた道路、外周再探索の順に安全位置へ補正する。スポーン間隔28 studsも維持する。
- tests/run.pyに実装契約のソースガードを追加。Studio/Rojo接続・実機/複数試合の物理確認はこの環境では未実施で、TODO N0とQA_CHECKLISTに確認項目を追加した。

## 肩越しAimと武器外観テンプレート（2026-10-05）

- R15 Aimはカメラ水平向きへのRoot回転、Aim中のAutoRotate停止、左右IK、上半身補正、武器別Presentation offsetを使用する。Aim解除、Sprint/Slide、武器切替、死亡、ラウンド終了で復元する。R6はIKを作らず既存表示へfallbackする。
- `ServerStorage/WeaponModels/{Pistol,Rifle,Shotgun}`が存在すれば、安全化した外観だけをHeldWeaponへ複製する。Script/Tool/Remote/Humanoid等は複製後にも除去し、全BasePartを非Collide/Touch/Query・Masslessにする。テンプレート欠落時は従来のPart生成を維持する。
- Studio保存モデル: Classic pistol w slide（13916503156）、Assault Rifle (Rivals)（110214445805991）、rigged shotgun（10806289779）。3モデルとも銃床/グリップが肩側、Muzzleが前方になるよう外観方向を確認・反転済み。モデル実体はPlace側にありGitには含まれない。
- Studio Soloで3武器の取得・切替・Aim開始/解除・各1発・Reload・死亡/respawnを確認。各武器でWeaponModel/PresentationJointが1個、Aim中は左右IK=1かつAutoRotate=false、解除後はIK=0かつAutoRotate=true、respawn後は旧HeldWeapon/IKなし。スマートフォン実機と複数人は未確認。

## モバイルFireボタンドラッグ照準（2026-10-05）

- 基準main: `4ca51bba259e444f22b3a43b3c1f504ebcd17f7e`。FireのTouch保持はあったが、移動を照準へ反映する処理はなかった。
- `FireDrag`がFireから始まったInputObjectだけを保持。ボタン外でも移動量を蓄積し、Camera priority - 1で前回反動を外した後にFocus周りを回転する。標準カメラ更新、既存Presentationの反動/肩寄せ/FOV処理、長押し連射の順。最初の1発は従来どおり即時。
- Fire GUIのActive=trueと、Roblox CameraInputが開始時のprocessed状態を保持する仕組みを利用して同じ指の二重回転を避ける。標準画面ドラッグ、PlayerModule、CameraTypeは置換しない。実際の入力消費と標準カメラ追従/衝突はStudio実機未確認。
- 感度/垂直感度/ピッチ上限はPresentationConfigに集約（.18度/pixel、.18度/pixel、±80度）。Aim Assist、Combat.lua、Presentation.lua、武器/姿勢/マップ/Rojo保護設定は変更なし。
- `python3 tests/run.py --client-only`: PASS、全src Lua構文検査と249 client/server assertions（47追加）。`python3 tests/preplay_analysis.py`: PASS。
- `python3 tests/run.py`: FAIL。未変更の基準mainでも同じ`regression.lua:15 nativeRequire(nil)`を再現。Cosmeticsが参照するPresentationConfigが既存regression doubleに登録されていない。今回の変更による失敗ではないが、全体テスト成功とは扱わない。関連clientを独立実行するオプションを追加した。
- 詳細な操作、懸念、未実施項目: [MOBILE_FIRE_DRAG_QA](MOBILE_FIRE_DRAG_QA.md)。Studio/スマートフォン/複数人実プレイは未実施。

## Round開始処理への安全スポーン接続（2026-10-05）

- 履歴確認: PR #21の実装コミット`9e717b1`はWorld.luaのみ変更し、マージ`43c87c6`から基準mainまでRound.lua/World.luaへの後続変更はない。Round:startは人間/BOTともWorld.groundで配置し、BOTは位置不足時に未検査のself.world.spawns[i]へ戻っていた。
- ただしPR #21はWorld.createでresolveSpawnを実際に呼び、候補群を生成時に安全補正していた。「resolverが完全に未使用だった」は不正確。固定マップならその補正は有効だが、配置直前の再検査、候補不足、BOT fallbackには穴が残っていた。今回の実プレイ再発がこの穴だけによるかは、Studio実物と物理の確認が必要。
- Round:startが人間/BOTともresolveSpawnを配置直前に呼ぶ。シャッフルした候補を優先し、非yieldの共通予約で全組合せのXZ間隔28 studsを維持。返された配置座標をそのままPivotToへ渡し、速度をクリアする。
- Worldの既存近傍→道路→外周探索の後に有界の島内グリッドを追加。実際の地面Raycast命中が必要で、重なり検査はCanCollide基準・件数打切りなし。建物footprint/衝突/間隔チェックをfallbackにも適用する。
- 候補がゼロ/不足でも安全探索を継続。BOT用安全位置不足は補充を減らして開始。人間用位置がない場合はActor登録せずLobbyで次戦待ち。全員失敗ならstartはfalseで終わり、既存runのreset→次戦へ進む。アバター読込期限後のcallbackはBOT予約を消費せず、新しいroundへ登録しない。
- ServerStorage/WeaponModels・TownTemplates・default.project.json・建物生成/モデル/Studio保存Assetは変更しない。
- `python3 tests/run.py`: PASS（spawn 9710、gameplay 938、visual 810、client/server 249 assertionsと既存source guards）。`python3 tests/preplay_analysis.py`: PASS。人間/BOTのresolver呼び出しを個別にgroundへ置換するmutation確認は両方FAILを検出（元に復元済み）。`git diff --check`: PASS。
- 既存全体ランナーの基準main由来の模擬環境不足も補完: PresentationConfig、ServerStorage、PreSimulation、CFrame/Vectorの必要プロパティ。ゲーム側のPresentation/Cosmeticsは変更なし。
- Studio/Rojo/スマートフォン/複数人/連続3試合の物理検証は未実施。TODO N0とQA_CHECKLISTのスポーン確認項目は未完了のまま。

## 連射ジッターと観戦Shot配信修正（2026-10-07）

- 修正ブランチ: `fix/fire-jitter-spectator-feedback`。基準mainは`d79466b`。
- 人間の射撃要求がcooldownより最大50ms（武器間隔の半分以下）早く届いた場合、Actorごとに1件だけ期限まで待機する。期限前には弾薬・Raycast・演出を適用しない。実際の発射から次のcooldownを設定するため、連射上限は変えない。
- 待機は死亡、HPゼロ、Reload世代、装備スロット/Inventory、roundId、退出で無効化。新しい発射が先に受理された場合も旧callbackを破棄する。BOTの射撃と既存Action ingress制限は維持。
- Shotは接続中のPlayers全体から送信先を選ぶ。生存者は従来の330 studs範囲、死亡者/Actorのない途中参加者は観戦位置がサーバーにないため全Shotを受信し、既存の位置音声と演出プールを利用する。
- `python3 tests/run.py`: PASS（spawn 9710、gameplay 973、visual 810、client/server 249 assertionsとsource guards）。`python3 tests/preplay_analysis.py`: PASS。
- 150ms間隔10要求・交互40ms/0ms追加遅延を模擬し10発を確認。発射間隔140ms以上、100要求spamでも待機1件、死亡/装備/Reload/Results/次戦/退出時の取消、死亡地点から490 studs離れた観戦と途中参加への配信、生存者の距離制限を確認。
- Studio/スマートフォン/複数人/実ネットワークでの連続3試合は未実施。以下TODO N5で実機検証を残す。

## Rifle / Shotgunの両手構え（2026-10-08）

- 原因調査で、R15の長物は非Aim時のIKが0のため右手から垂れ下がり、Aim時は手首Transform IKと大きいShoulder補正が競合して銃身が身体を横切ることを確認した。Tool/Gripは使用せず、HeldWeaponのPresentationJointと左右IKで表示している。
- Rifle / Shotgunだけは正規化済みWeaponModelsのRootをHumanoidRootPart基準へ置き、右手をGrip、左手をBarrel / PumpへPosition IKで追従させる。銃床は右肩付近、Muzzleはキャラクター前方を維持し、通常・移動中も武器別のIK blendを残す。Pistolの既存Aim設定は変更しない。
- R15限定の長物処理とし、武器切替・死亡・ラウンド終了ではPresentationJointの元Part0/C0とIKを復元する。R6は従来の右手接続へfallbackする。
- Studio SoloでR15、外観Rootの前方、Stock / Grip / Barrel / Pumpマーカー、通常時の左右IKと武器切替後の復元を確認。Studio Pluginのバージョン不一致により端末シミュレーターは使用できず、スマートフォン実機、複数人、全移動状態の目視回帰は未確認。

## モバイルAIM / FIRE分離（2026-10-08）

- モバイルHUDに独立したトグル式AIMを追加。AIMは`Presentation:setAimHeld`だけを切り替え、Fire Remoteを呼ばず、アクティブ中は青色の`AIM ON`表示になる。Sprint、Build、死亡/リスポーン、ラウンド終了、フォーカス解除で必ず解除する。
- FIREは射撃だけを開始/停止し、Aim状態を変更しない。既存FireDragのタッチ所有権、ボタン外ドラッグ、マルチタッチ分離、長押し連射、武器別発射間隔は維持する。PCの左/右マウス操作は変更しない。
- FIREを92x92、AIMを76x56とし、既存のReload / Build / Sprint / Crouch / Draftと重ならない右側配置にした。Combat.lua、Raycast、Damage、Ammo、Aim Assist、BOTは変更なし。

## スマホ戦闘・建築HUD（2026-10-08）

- `feat/mobile-combat-build-hud`: タッチ専用のCombat/Build切替、選択→PLACE、即時の可視/Active切替、保持Fire/Aim取消と死亡/次戦等での復帰を実装。
- `MobileLayout`で安全領域内の可変キャンバスと端寄せ配置。標準スティック/Jumpは維持し予約領域を空ける。建築中はEnergy、戦闘中は弾薬表示。PCキーとサーバー/Raycast/Presentation/Rojo構成は維持。
- run.py PASS（spawn 9710 / gameplay 973 / visual 824 / client 271 / layout 1032）、preplay PASS、diffチェックPASS。
- Studio/実機は未確認。[MOBILE_HUD_QA](MOBILE_HUD_QA.md)に配置プレビューと確認手順。TODO N6は実機確認まで未完了。

## 近接肩越しAIM（2026-10-08）

- 基準main: `dd97341b539b1a0368eae06b4fb257c8cc2af85e`。実装ブランチ: `feat/close-shoulder-aim`。
- 旧AIMはFOV/CameraOffsetのみで距離は不変。PresentationがAIM中と解除遷移中だけPlayerのzoom boundsを管理し、Rifle 4.2 / Shotgun 4.6 / Pistol 4.0 studsへ指数補間する。解除時は開始時の表示距離へ戻し、元のmin/maxを復元する。通常時のzoomは変更しない。
- 標準カメラの前にzoom、後に既存FOV/反動/武器を更新する。CameraType/PlayerModuleを置換せず、標準のorbit・タッチ・遮蔽処理を維持。右肩オフセット1.55、上方向.45、相対FOV -12で上半身を画面左へ寄せる設計。描画上の最終構図は未確認。
- 3武器のAIM位置を調整し、PistolもR15でroot基準＋左右Position IKへ統一。表示銃は既存Fireの照準点（モバイル補助含む）へ向ける。Reload中は既存傾きを優先。R6の右手接続fallbackを維持。銃モデルの軸/マーカー実物はStudioで確認が必要。
- Combat、弾薬、spread、root+1.4のサーバー射撃起点、遮蔽判定は変更なし。表示の銃口とサーバー射撃起点は同一ではなく、至近距離/壁際の見え方は実機QAが必要。
- `python3 tests/run.py`: PASS（spawn 9710 / gameplay 973 / visual 879 / client 271 / layout 1032、構文/source guards含む）。`python3 tests/preplay_analysis.py`: PASS。
- 追加検証: zoom収束/復元/連続切替/武器切替/Sprint/Slide/死亡/Results/次戦、3武器位置から上下左右の照準点への数値回転、通常時/Reloadの姿勢保護。
- Studio・スマートフォン・PC実プレイは未実施。[SHOULDER_AIM_QA](SHOULDER_AIM_QA.md)に手順。N7は未完了。

