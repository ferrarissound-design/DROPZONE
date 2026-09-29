# DROPZONE

**撃破するほど自分自身が進化する、スマートフォン向けの高速バトルロイヤル。**
Roblox Studio + Rojo用の公開前検証版です。人間1人でもBOTを補充して開始します。

## 現在の実装

- Waiting → Intermission → Starting → Active → FinalZone → Results → Resettingのラウンド。
- 基本12体（人間1人ならBOT11体）、人間12人以上はBOTなし。参加枠は最大20人。
- 分散スポーン、死亡/退出で敗退、BOTを含む最後の1人が勝者。途中参加は観戦・次戦待ち。
- Rifle / Shotgun / Pistol、弾倉、予備弾、リロード、武器3スロット。
- サーバー射撃判定。発射間隔・生存状態・弾薬・射程・入力型・非有限数・ラウンドIDを検証。
- 設定した地点に武器・弾薬・回復・Shield・BUILD ENERGYを配置。接近で自動取得。
- 5段階の縮小ゾーン。現在/次の境界、ミニマップ、タイマー。ゾーン外ダメージはShieldを貫通。
- BOTの探索、移動、射撃、リロード、Loot取得、ゾーンへの退避、経路探索・ジャンプ・横移動による詰まり対策。
- Wall / Floor / Rampを前方グリッドへ設置。エネルギー消費、破壊、寿命、総数上限、重なり検査。
- 撃破ごとにサーバーが異なるカテゴリを混ぜて3つのEvolution候補を提示。5秒以内に選ばない場合は自動選択され、選択中も戦闘・移動は続きます。能力は最大3段階まで逓減Stackし、撃破ごとに構成が変化します。
- EvolutionはSwift Legs、Iron Skin、Hunter Eyes、Quick Hands、Builder、High Jump、Regenerationに加え、Scavenger、Adrenaline、Combat Shield、Overchargeを収録。BOTも状況に応じて候補から自動選択します。
- 能力に応じた発光Mutationを付与します。追加パーツは衝突・接触・Raycast判定を持たず、ラウンド終了時に破棄されます。
- 日本語中心のHUD、横画面タッチ操作、軽い照準補助、観戦、順位/キル/ダメージ/生存時間/進化数のリザルト。
- Town / Warehouse / Forest / Hill / Coreのコード生成マップ。
- 試合ごとにキャラクター、装備、能力、建築、Loot、BOT、ゾーンを再生成。

**注意：コードの構文・ロジック検証は実施済みですが、Roblox Studioでの実行・スマホ実機テストは未実施です。公開前に [プレイテスト手順](docs/PLAYTEST.md) を実施してください。**

## 基本ルール

1. ロビーで約12秒待つと試合準備が始まります。アバター読込待ちは別途最大15秒。
2. 武器のそばまで歩いて自動取得。全スポーン付近に武器があります。BOTはピストルを所持します。
3. 撃破して能力と建築エネルギーを獲得します。倒されるとその試合には復帰できません。
4. 青い現在ゾーンと白い次ゾーンを確認して移動します。黄色い点は自分の位置です。
5. 最後の1人が勝利。12秒のリザルト後に全状態を消して次の試合へ。

ゾーンは合計375秒（6分15秒）で半径ゼロになります。戦闘で早く決着することもあります。
ゼロ地点でもダメージを受けるため、中心に隠れて無限に生存できません。
最終フェーズ後30秒の決着保護ではキル→ダメージ→固定IDの順で勝者を選びます。通常は到達前に決着します。
同一tickに環境ダメージで複数人が脱落した場合は同順位にし、最後の複数人が同時に脱落した場合はDRAWです。死亡/退出で同時に誰も残らない場合もDRAWです。

候補はSwift Legs、Iron Skin、Hunter Eyes、Quick Hands、Builder、High Jump、Regeneration、Scavenger、Adrenaline、Combat Shield、Overchargeです。最初の取得効果はそれぞれ移動+8%、最大HP+20、Spread-10%、Reload-12%、Build Energy消費-15%、JumpPower+12%、静穏時2 HP/s、Ammo取得+20%、撃破後5秒Speed+8%、撃破時Shield+10、最大Energy+25です。同じ能力は最大3段階まで積めますが、段階ごとに効果が小さくなります。

3候補はサーバーが提示し、プレイヤーは画面上の大きなカードから選択します。5秒で自動選択に切り替わり、ゲーム世界は停止せず無敵にもなりません。候補選択中は移動や射撃を続けられます。BOTはHP、ゾーン、武器、Shieldを参考に候補を自動選択します。Evolutionは次の試合に持ち越しません。永続データ/DataStoreはまだ使用しません。
回復・Shieldは取得時に即使用する仕様です。建築は地表設置のみで、多層の積み上げ・編集はありません。

## PC操作

| 操作 | 入力 |
|---|---|
| 移動 / 視点 | WASD / マウス（通常は中央固定、Evolution Draft中はカード選択のため解除） |
| 射撃 | 左クリック長押し |
| リロード | R |
| ジャンプ / Slide・Crouch解除 | Space |
| Sprint | Shift長押し（離すと通常移動） |
| Crouch / Slide | Ctrl。Sprint中はSlide、通常時はCrouch切替 |
| 武器切替 | 1 / 2 / 3 |
| 建築 | Q |
| 壁 / 床 / 坂を選択 | Z / X / C |
| 取得 | 接近で自動、またはE |
| 観戦対象変更 | Tab / 観戦ボタン |

PCの建築はキャラクターが向いている方向に配置されます。置きたい方向へ移動してからQを押してください。

## スマホ操作

横画面でプレイします。左親指はRoblox標準の移動スティック、右側スワイプで視点を操作します。
右側の大きい「射撃」を長押し、「装填」「建築」はタップ。壁・床・坂を先に選択します。
「走る」はSprint切替。「しゃがみ」ボタンはSprint中に「スライド」へ変わります。Slide後はCrouchになり、もう一度押すかJumpで立ちます。空中に出るとSprintは解除されるので着地後に再入力してください。
撃破後のEvolutionは画面中央寄りの大きな3カードからタップして選びます。カードを選ぶまで移動・戦闘は続き、5秒後は自動選択されます。
下中央に武器3枠、右下は標準ジャンプ用の空間です。照準の近くに見えている敵だけ弱い照準補助が働きます。
切り欠き/上部メニューの安全領域を使い、画面サイズに合わせてHUDを縮尺調整します。

## Roblox Studio / Rojo

前提：Git、Rojo 7、Roblox Studio、StudioのRojoプラグイン。
すでにリポジトリを取得済みなら、そのDROPZONEフォルダで実行してください。

```powershell
git clone https://github.com/ferrarissound-design/DROPZONE.git
cd DROPZONE
# 公開済みmainを同期する。未マージPRの確認時だけPRブランチへ切り替える
git switch main
git pull --ff-only
rojo serve default.project.json
```

PRマージ後は `git switch main` → `git pull --ff-only origin main` → `rojo serve default.project.json`。

1. **DROPZONE専用の新規Place**をStudioで開きます。他のゲームのPlaceへ同期しないでください。
2. 初期テンプレートのBaseplateとSpawnLocationは削除してください。地面とロビーはスクリプトが生成します。
3. Rojoプラグインで `localhost:34872` にConnectし、同期内容を確認してAccept。
4. Playを押すとロビーが表示され、1人でもBOTと試合が始まります。
5. 複数人テストはStudioのServer & Clientsで2クライアント以上を起動します。
6. ゲーム設定の最大プレイヤー数を20以下にしてください。新規Placeではまず12推奨。
7. 検証後に**Robloxに公開**します。Rojoの同期だけでは公開中のゲームは更新されません。

同期せずにファイルとして開く場合：

```powershell
rojo build default.project.json -o DROPZONE.rbxlx
```

外部アセット、HTTP、API Services、DataStore、アセットID設定は不要です。

## 主要ファイル

```text
src/shared/Config.lua       人数、試合時間、ゾーン、建築、能力上限
src/shared/Weapons.lua      武器3種のパラメータ
src/shared/Rules.lua        独立した計算・判定ロジック
src/server/Main.server.lua  起動、Remote入口、単一スケジューラー
src/server/Round.lua        ラウンド進行、参加、結果、リセット
src/server/Actors.lua       プレイヤー/BOT、生存、HP、死亡、順位
src/server/Combat.lua       サーバー射撃、装備、リロード
src/server/Zone.lua         ゾーン進行と次の境界
src/server/Bots.lua         低頻度AI・上限付き経路探索
src/server/Loot.lua         Loot配置と取得
src/server/Building.lua     設置・衝突・破壊・寿命
src/server/Evolution.lua    能力と見た目
src/server/World.lua        固定マップ、ロビー、配置地点
src/client/Main.client.lua 入力、照準、カメラ、観戦
src/client/Hud.lua         HUD、リザルト、ミニマップ
src/client/Effects.lua     ローカル境界線、弾道
```

RemoteEventは `DropzoneRemotes/Action`, `Snapshot`, `Effects` の3つです。RemoteFunctionは使いません。
UIはStarterPlayerScriptsから1回生成し、リスポーン時に重複させません。

## 検証

```sh
python3 tests/run.py
```

LinuxのPython 3 + システムの `liblua5.4` を使用します。
実際のLuaモジュールの構文と、エンジンを簡略化したテスト環境でダメージ/ゾーン/順位/リロード/リセットを確認します。
Luau型検査、Roblox物理、ネットワーク、Pathfinding、実機性能の代わりにはなりません。
詳細は [プレイテスト手順](docs/PLAYTEST.md) と [設計・制限](docs/ARCHITECTURE.md) を参照してください。

## 次に改善すること

まずStudioで2試合連続テストを完了し、BOTの経路とスマホ操作を調整します。
その後、音声・武器/歩行アニメーション・降下演出、マップの視覚品質を改善します。
建築の高度化、Evolutionの出現率・効果量の調整、永続統計はプレイテスト後に検討します。現在の3択は実装済みで、候補外の能力IDをクライアントから直接取得することはできません。

## Release Readyチェック状況

**判定：NOT READY（Studio・実機の公開ゲート未実施）。** コード検証の成功だけで公開可能とは判断しません。

- Draft初回表示時のColor3型エラーを修正。実際のカード描画メソッドを型検査付きUIダブルで実行する回帰テストを追加。
- 開始9秒の短いガイド、初期武器の「武器を拾え」表示、撃破通知、被弾時HP欄フラッシュ、縮小/境界警告、Resultの主要Build表示。
- Spawnを半径245の外周へ移し、町の屋根や森の幹から初期武器への導線を離しています。実際の到達性は全24地点で検証してください。
- BOTが距離でRifle/Shotgun/Pistolを選択。敵/拾得物の高さを維持し、屋根へ追跡する問題を軽減。Path生成の例外でもジョブ枠を解放。
- 同じ武器Slotの連打で装填取消や外観Part再生成が起きないよう修正。静止Zoneの96境界Partへの更新を省略。
- 道路の装飾ラインは非衝突・非接触・Raycast対象外。新しい武器、能力、外部Sound Assetは追加していません。

武器・Evolution・建築の数値は維持しています。Pistolは22 damage/0.32秒、Rifleは16/0.14秒、Shotgunは11×7/0.85秒で距離減衰します。BOTの射撃は0.35秒判断と意図的な照準誤差で制限されています。机上の数値確認は対人/実機バランステストの代わりにはなりません。

## Visual Identity — Colorful Combat Experiment

明るい未来の戦闘実験フィールドとして、Paper / Sky Blue / Cyan / Orange / Yellowを基調に統一しました。外部Asset・Texture・Iconは使用していません。

- Rifleは青いレシーバーと大きいMagazine、ShotgunはオレンジのPump/Stockと太い銃身、Pistolは黄色いSlide。武器ごとに4〜6Part。
- Combat Droneは白いHelmet、シアンVisor、オレンジChest Core、青いShoulder。既存R6のHitboxは維持。
- Evolutionカードは能力名を最大の文字にし、Mobility=Cyan、Attack=Orange、Survival=Green、Utility=Purple。選択時は0.3秒の枠フラッシュで送信中を示します。取得確定はサーバーSnapshot後です。
- HP/Shield/Energyバー、大きい装弾数、Gold Victory。通常HUDは主要能力1つ、Resultは最大3つを表示し、小画面での文字過密を抑えます。
- Townの外壁色・窓・ひさし、Warehouseの色分け、丸い樹冠、道路境界/横断帯、草地の色面、Hill裾の低い岩、上空のEvolution Core。
- Lootは武器モデル／Ammo box／Medical case／Shield canister／Energy cell。建築は既存本体に白いFrameを2Part追加。
- 明るい昼、弱いBloom。戦闘を隠すFogや大量Light/Particleを追加していません。

主な表示専用ファイル：`src/shared/VisualTheme.lua`、`src/server/Cosmetics.lua`、`src/server/MapVisuals.lua`。
新規装飾は非衝突・非接触・非Raycast・Massless。Map装飾は地面探索対象のMapフォルダから分離しています。Spawn、地形の当たり判定、移動、武器/能力/建築/Lootの性能は変更していません。EnergyバーのためSnapshotにサーバー算出のmaxEnergyを追加しています。

**見た目の最終承認はStudio/スマホ実機で行ってください。** Offlineのモデル構築・破棄・UI状態テストは、Robloxの描画品質や実測FPSを保証するものではありません。

## Movement / Loot / Combat Feel

- Sprintは通常速度の1.3倍、Swift LegsとAdrenalineを合成してもWalkSpeedは32以下。開始に0.25秒のクールダウンがあります。空中/死亡/Resultsでは開始不可。PC標準Shift Lockは無効にし、既存の照準用Mouse Lockとの競合を避けています。
- Sprint中に水平速度20以上でSlide可能。初速34、0.65秒で減速しCrouchへ。再使用2.1秒。Jumpで解除しても再使用待ちは残ります。空中へ出た場合も滑走を終了し、死亡/Results/Resetで状態を消します。
- 坂道専用の加速とMantleは未実装です。既存Humanoid Physicsを使い、今回の変更では自動テレポートや壁乗り越えを追加しません。
- 武器レア度：Common（白）/ Rare（青）/ Epic（紫）。通常Weapon Lootは72% / 22% / 6%、Spawn付近の武器はCommonです。
- RareはReload時間−4%、Spread−6%。EpicはReload時間−8%、Spread−12%。Damage・FireRate・Magazine・Rangeは共通。既存Evolutionによる補正と乗算します。
- 同種武器は最大1枠。上位を拾うとアップグレードし、現在の弾倉を保持。低位/同位を拾うと予備弾を補充し、品質は下がりません。上位への更新が装填中なら、その装填を取消して再装填できます。
- Lootのレア度はサーバーが決定・保持。静的なNeon足元マークと75stud表示のラベルで発見しやすくしています。全Lootの常時浮遊/回転、Particle、PointLightは追加していません。
- サーバー確定ダメージをHP（金）/Shield（シアン）で0.65秒表示。Shotgunは敵ごとに集約。クライアントは最大8表示枠を再利用し、10Hzでフェード、Round切替/Resultsで消去します。射撃は照準の短い拡大、命中は色変化、撃破は短いフラッシュからEvolution Draftにつながります。
- HUDには現在のレア度とスロットのC/R/E表記。Movementは2ボタンのまま、Draft/Build/Reload/Slotと重ならない配置です。

詳細な検証は [PLAYTEST](docs/PLAYTEST.md) を参照してください。オフラインテストの成功は滑走感・ネットワーク所有権・実機FPSの検証を代替しません。
