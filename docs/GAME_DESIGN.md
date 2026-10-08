# DROPZONE ゲーム設計

現状の設計要約。実装の基準点・不足は[CURRENT_STATE](CURRENT_STATE.md)、次の作業は[TODO](TODO.md)。数値の正本はsrc/shared/Config.lua・Weapons.lua・WeaponStats.lua。

## コンセプトと試合

撃破するほど自分が進化する、スマートフォン向けBattle Royale。BOT補充により人間1人でも試合が成立する。
街・倉庫・森林・丘・中央Coreを巡り、武器を拾い、縮小するZoneへ移動しながら生き残る。

Waiting → Intermission → Starting → Active → FinalZone → Results → Resetting。
標準12体、人間が12人以上ならBOTなし、参加枠最大20人。途中参加は現在の戦闘員に追加せず観戦/次戦待ち。
人間は分散スポーンし近くの保証武器を取得、BOTはPistolを持って開始する。空中降下や降下地点選択はない。
死亡・退出で敗退し同じ試合へ復活しない。最後の生存者が勝者で、人間/BOT共通。結果後に次戦へ移る。

## 主要システム

| システム | 現在の挙動 | 主なソース |
| --- | --- | --- |
| Combat | サーバーRaycast、弾倉/予備弾/Reload、3スロット。Shotgunは7ペレット・距離減衰 | server/Combat.lua、shared/Weapons.lua |
| Rarity | Common/Rare/Epic。上位はReloadとSpread改善、同種は上位を保持 | shared/WeaponStats.lua、server/Loot.lua |
| Loot | 武器/Ammo/Health/Shield/Energyを固定地点へ配置。接近で自動取得、Eでも要求可能。回復/Shieldは即使用 | server/Loot.lua |
| Building | Wall/Floor/Rampを前方の地表グリッドへ設置。Energy、衝突検査、HP、破壊、寿命、総数上限 | server/Building.lua |
| Movement | Sprint、Crouch、Slide、Jumpで姿勢解除。空中ではSprint解除、Slide終了後は接地時Crouch | server/Movement.lua |
| BOT | 安全なZoneを優先し、Loot/敵/探索へ移動。Reload、武器選択、視線射撃、遮蔽破壊、Pathfinding、詰まり回避 | server/Bots.lua |
| Zone | 5段階の保持/縮小。現在/次の円とミニマップ。外側ダメージはShield貫通 | server/Zone.lua、Round.lua |
| Spectate | 死亡/途中参加後に生存対象を観戦。Tab/ボタンで変更 | client/Main.client.lua |
| HUD | HP/Shield、装備/弾薬/枠、人数/Zone時計、ミニマップ、通知、Draft、結果 | client/Hud.lua |
| Feedback | 反動、FOV、右肩Aim、発砲/着弾、確認済みダメージ数字、Hit Marker、撃破反応、音声 | client/Presentation.lua、Effects.lua、DamageFeedback.lua、Audio.lua |
| World/Town | Town/Warehouse/Forest/Hill/Core。生成建物と任意のStudio内TownTemplates、衝突と装飾を分離 | server/World.lua、Town.lua、MapVisuals.lua |
| Round/Diagnostics | 世代管理、読込待ち、結果統計、状態破棄。Resultsで有界の診断ログ | server/Round.lua、Actors.lua |

表のソースはsrc/からの相対パス。Buildingは地表設置で、多層積み上げ・編集機能はない。

## Evolution Draft: 残すべき独自要素

撃破で建築EnergyとDraftを獲得し、カテゴリの異なる方向を優先した3候補から能力を選ぶ。各能力は最大III、段階ごとに増分が逓減する。
プレイヤーは5秒以内に選択、期限後はサーバーが状況に応じて自動選択する。BOTは即時自動選択。能力は試合内だけで、非衝突の発光Mutationとして身体にも表れる。

| カテゴリ | 能力 | 効果の方向 |
| --- | --- | --- |
| Mobility | SwiftLegs / HighJump / Adrenaline | 移動 / 跳躍 / 撃破後5秒の加速 |
| Attack | HunterEyes / QuickHands | Spread / Reload改善 |
| Survival | IronSkin / Regeneration / CombatShield | 最大HP / 8秒無被弾後の回復 / 撃破時Shield |
| Utility | Builder / Scavenger / Overcharge | 建築費 / 弾薬取得量 / 最大Energy |

選択中も世界・移動・射撃を止めない。この「戦いながら構成を決める」圧力、撃破による変化、BOTを含む共通ルールがDROPZONEの核。
パネル上のクリックだけを背景操作へ貫通させない。死亡/結果でDraftと待機キューを破棄する。
能力が出揃って候補を3つ生成できない場合、新規Draftは終了する。

## PCとモバイル

PC: WASD/マウス、左射撃、右Aim、R Reload、1/2/3装備、Shift Sprint、Ctrl Crouch/Slide、Space姿勢解除/Jump、Q建築、Z/X/C建築種、E取得、V Draft開閉、Tab観戦。
モバイル: 標準スティック/Jumpと横画面タッチHUD。AIMトグルとFIRE長押し/ドラッグは独立。戦闘/建築モード、パーツ選択→PLACE、Sprint切替、姿勢ボタン、装備/Reload。見えている敵への軽い照準補助。

PC HUDは左下HP/Shield、右下武器/弾薬、上中央人数/Zone。DraftはREADY/Vで開き、建築情報は操作後3秒、Loot名は取得範囲内で最寄り1件、初回ガイドは習得後消える。
モバイルは安全領域内で760×360基準から可変キャンバスへ配置し、自動Draft展開を維持。現在Staminaはない。

## 決着・リセット・設計境界

Zoneの全スケジュールは375秒、最終半径ゼロ。さらに30秒後の決着保護はキル→ダメージ→固定ID順。
同tick環境死は同順位、最後の複数人の同時環境死はDRAW。結果には順位/キル/ダメージ/生存時間/進化構成を表示。
次戦で装備・能力・建築・Loot・BOT・Zoneを再生成し、永続DataStoreは使用しない。

軽量性と画面の見やすさを優先する。外部の武器/敵/建物を採用しても、Evolutionとサーバー権威・回帰保証を維持する。
永続育成、課金、複雑な建築、別の攻撃システムへの移行は現実装として記載しない。追加は別途スコープを決める。
