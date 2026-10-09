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
- 人間プレイヤーは能力別の機械装甲で進化します。1〜2回で初期改造、3〜4回で共通シャーシ、5回以上で胸部コア/背部ユニットの高度形態。BOTは能力だけ進化し、外見は維持。装甲は非衝突/非Raycast、AIM中は自分の画面だけ非表示、Resultsで破棄。[確認手順](docs/PLAYER_EVOLUTION_QA.md)はStudio/実機で未検証。
- 日本語中心のHUD、横画面タッチ操作、軽い照準補助、観戦、順位/キル/ダメージ/生存時間/進化数のリザルト。
- 初回は武器取得→撃破→Evolution選択の3ステップミッションをHUD左上に表示。初進化後はセッション中非表示。観戦時は追跡対象名を表示、Zone縮小10秒前には1フェーズ1回の音声警告。
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
| 構え / 右肩越しAim | 右クリック長押し。離すと通常カメラへ戻る |
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
通常は戦闘モードで、**AIM**ボタンと**FIRE**ボタンが別々に表示されます。AIMは右肩越しの近距離カメラへ切り替えるトグルで、押すだけでは弾を消費しません。FIREは長押しで射撃でき、指を動かせば照準もドラッグできます。FIREを離してもAIMのON/OFFは維持されます。
**建築**ボタンで建築モードへ切り替え、壁・床・坂を選んで**PLACE**で設置。**戦闘**で戻ります。建築中はAIM/FIREが非表示になり、誤射を抑えます。通常時の武器切替はAIMを解除しません。
「走る」はSprint切替。「しゃがみ」ボタンはSprint中に「スライド」へ変わります。Slide後はCrouchになり、もう一度押すかJumpで立ちます。空中に出るとSprintは解除されるので着地後に再入力してください。
撃破後のEvolutionは画面中央寄りの大きな3カードからタップして選びます。カードを選ぶまで移動・戦闘は続き、5秒後は自動選択されます。
下中央に武器3枠、右下は標準ジャンプ用の空間です。通常の腰撃ちでは照準近くの敵に弱い射撃方向補正が入ります。**スマホでAIM ON中だけ**近くの敵を視界に捉えると、照準がゆっくり敵を追うソフトトラッキングも有効になります。手動の視点スワイプ・FIREドラッグを優先し、操作後約0.28秒は追従を停止します。追従中も自動射撃はせず、FIREを押す必要があります。壁や屋根に隠れた敵、背後の敵、遠くの敵には追従しません。PCのマウスAIMには追従は追加しません。

### スマホAIMトラッキングのテスト

- AIM OFFで敵の方向にカメラが勝手に回転しないことを確認。
- AIM ONで照準から約6度以内・140stud以内の見える敵にゆっくり追従し、突然大きく吸い付かないことを確認。
- FIREを触らない限り弾薬が減らず、FIRE長押し中は通常の発射間隔を守ることを確認。
- 指で視点を動かしたときは操作を優先し、指を離したあと自然に追従が再開することを確認。
- 建物の壁越し・敵死亡後・建築モード・Sprint・観戦・ラウンド切替では追従しないことを確認。
- ロック維持角9度、最大追従13度/秒、追従応答3.0、検出間隔0.08秒は`src/shared/PresentationConfig.lua`で調整可能。
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

HTTP、API Services、DataStoreは不要です。SoundはCreator Storeの選定済みAsset IDをAudioConfigで使用します。Animation IDは未設定でも動作します。

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
src/server/Town.lua         Town建物、外部テンプレート検査、軽量フォールバック
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
さらに `tests/preplay_analysis.py` を実行し、武器理論TTK、Zone総時間、Build economy、20,000回のRarity抽選、10,000回のfresh Evolution Draft相当を決定論的に検査します。

プレリリース中は `Config.PlaytestDiagnostics = true` です。Results時だけServer Outputへラウンド集計を出し、武器別Shot/Hit/Damage、Build、Pickup、Zone damage、Evolution履歴などを最初の実機テストから記録できます。
初回体験のボトルネックを測るため、プレイヤー行には開始からの `firstWeapon` / `firstShot` / `firstKill` / `firstEvolution`（秒）も記録します。未達成は `-`、リセット後は持ち越さず、DataStoreや外部送信はしません。診断値はGameplay判定には使用しません。

Luau型検査、Roblox物理、ネットワーク、Pathfinding、実機性能の代わりにはなりません。
詳細は [事前分析](docs/PREPLAY_ANALYSIS.md)、[プレイテスト手順](docs/PLAYTEST.md)、[設計・制限](docs/ARCHITECTURE.md) を参照してください。

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
- 道路の装飾ラインは非衝突・非接触・Raycast対象外。武器・能力は追加していません。音声は後述のCreator Store選定Assetを使用します。

武器・Evolution・建築の数値は維持しています。Pistolは22 damage/0.32秒、Rifleは16/0.14秒、Shotgunは11×7/0.85秒で距離減衰します。BOTの射撃は0.35秒判断と意図的な照準誤差で制限されています。机上の数値確認は対人/実機バランステストの代わりにはなりません。

## Visual Identity — Colorful Combat Experiment

明るい未来の戦闘実験フィールドとして、Paper / Sky Blue / Cyan / Orange / Yellowを基調に統一しました。外部Asset・Texture・Iconは使用していません。

- Rifleは青いレシーバーと大きいMagazine、ShotgunはオレンジのPump/Stockと太い銃身、Pistolは黄色いSlide。武器ごとに4〜6Part。
- Combat Droneは白いHelmet、シアンVisor、オレンジChest Core、青いShoulder。既存R6のHitboxは維持。
- Evolutionカードは能力名を最大の文字にし、Mobility=Cyan、Attack=Orange、Survival=Green、Utility=Purple。選択時は0.3秒の枠フラッシュで送信中を示します。取得確定はサーバーSnapshot後です。
- HP/Shield/Energyバー、大きい装弾数、Gold Victory。通常HUDは主要能力1つ、Resultは最大3つを表示し、小画面での文字過密を抑えます。
- Townは住宅3系統、店舗2系統、小型オフィス、倉庫を役割別シルエット・色・看板・大きな入口で区別。正面/裏口と広い側面通路を持つ軽量フォールバックを同梱します。
- Lootは武器モデル／Ammo box／Medical case／Shield canister／Energy cell。建築は既存本体に白いFrameを2Part追加。
- 明るい昼、弱いBloom。戦闘を隠すFogや大量Light/Particleを追加していません。

主な表示専用ファイル：`src/shared/VisualTheme.lua`、`src/server/Cosmetics.lua`、`src/server/MapVisuals.lua`。外部建物の選定・安全な保存方法は [Town building templates](docs/TOWN_BUILDINGS.md) を参照してください。
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

## Action Presentation / 音とAnimationの設定

武器別の軽いCamera Recoil、HeldWeapon Kick、最大8枠のMuzzle Flash、Reload傾き、Sprint FOV、Slide/Crouchの視点オフセット、進化適用時の0.45秒Pulseを追加しています。音・Animationが空でもこれらは動作します。反動は照準計算から取り除き、Damage・Ammo・Reload時間・Movement・Evolution効果は従来のサーバー判定を維持します。

- `src/shared/AudioConfig.lua`：各キーの `Id` に利用許可のあるSound IDを設定。`Volume` / `Cooldown` と3D減衰距離もここで管理します。
- `src/shared/AnimationConfig.lua`：各アクションの `R6` / `R15` に対応するAnimation IDを設定。未対応Rigは空欄のままにしてください。Movement優先のSprint/Crouch/Slide、Action優先のFire/ReloadをCharacter単位で再利用します。
- `src/shared/PresentationConfig.lua`：武器別反動・戻り速度・Kick・Flash、相対FOV、視点高さ、Reload角度を設定します。通常FOVは現在のCamera値を保存し、Sprint +5 / Slide +6から滑らかに復帰します。
- `src/client/Audio.lua` / `Animations.lua` / `Presentation.lua`：最大12音声、8Flash、1PulseとキャッシュしたTrackを管理。死亡・Results・Round変更・Character消滅で停止・復帰します。

**SoundはCreator Storeで確認した短い効果音をAudioConfigへ設定済みです。Animation IDは引き続き空欄です。** Rifle / Shotgun / Pistol、Reload、Empty、Shield/HP Hit、Elimination、Pickup、Evolution、Slide開始/終了、Zone、UIに音を割り当てています。Footstep / SprintFootstep / SlideLoopは、見つかった素材が長いシーケンスまたはループ不向きだったため意図的に空欄です。実際の利用権限・音量・聞こえ方はStudioで確認し、問題があるAssetはAudioConfigのIDを空に戻せば安全に無効化できます。

発砲音と他プレイヤーのSlide開始音は距離減衰する3D音。足音とSlide Loopは本人の近傍演出に限定し、BOT全員へ追加Track/足音処理を割り当てません。命中音はServer確定Damageのみ、PickupはServer取得イベント、Reload/移動/EvolutionはSnapshotに連動します。`EvolutionSelect` / `Button` / `Empty` は入力受付・現在表示中の弾数に対するローカルFeedbackで、成功や能力獲得の確定ではありません。`Error` キーは将来の明示的な失敗通知用に予約しています。

