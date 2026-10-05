# 現在の実装状態

- 調査日: 2026-10-05
- 調査対象: ferrarissound-design/DROPZONE のmain
- 基準コミット: `43c87c6`（2026-10-05時点のorigin/main）
- この記録はソース調査。コードに存在することと、Studio/実機で正常動作したことは区別する。以下の実装一覧は実機検証済みの意味ではない。
- 更新時は最新mainとの差分を確認し、基準SHAと実施した検証を更新する。

## 実装済み

[GAME_DESIGN](GAME_DESIGN.md)にルールを集約。以下は調査時点の実装と入口。

| 領域 | ソースで確認した実装 |
| --- | --- |
| ラウンド | Round/Actors: 7状態、参加上限20、標準12体にBOT補充、途中参加待機、死亡/退出、勝敗/DRAW、全リセット |
| Combat | Combat/WeaponStats: 3武器、3レアリティ、サーバー命中、Shotgun減衰、Reload世代、装備/上位取得 |
| Loot/Build | 自動取得と排他的claim、回復/Shield/Energy、Wall/Floor/Ramp、重なり拒否、破壊/期限/上限 |
| Evolution | 11能力、3候補、5秒自動選択、最大III、カテゴリ多様性、キュー、BOT選択、Mutation |
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
