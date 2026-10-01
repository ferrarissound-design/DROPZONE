# DROPZONE: AI開発ガイド

## 対象と基本方針

- 変更対象は **ferrarissound-design/DROPZONE のみ**。他のリポジトリを変更しない。
- Roblox / Luau / Rojo 7のゲーム。スマートフォンで遊べる軽量なBattle Royaleを、PCにも対応させる。
- 独自の核は「撃破 → Evolution Draft → 能力と見た目が変化 → 次の戦闘」。既存の戦闘・建築・進化を壊さない。
- ユーザーの明示指示を優先する。機能追加・外部システムへの置換・大規模リファクタは、対象コードと既存仕様を確認し、依頼の範囲内で行う。

## 最短の開始手順

1. このファイル → [CURRENT_STATE](docs/CURRENT_STATE.md) → [TODO](docs/TODO.md)を読む。
2. NOWの未完了項目を上から1件選ぶ。目的・対象・完了条件を確認する。検証が必要な項目を、推測で完了扱いにしない。
3. [GAME_DESIGN](docs/GAME_DESIGN.md)の該当箇所と対象コードを読む。構造が必要なら[ARCHITECTURE](docs/ARCHITECTURE.md)、回帰項目は[QA_CHECKLIST](docs/QA_CHECKLIST.md)を参照する。
4. 小さい差分で実装・検証し、TODOとCURRENT_STATEを同じPRで更新する。実施できないStudio/実機検証は未実施と明記する。

全ファイルを毎回読み直さず、`rg`で関連モジュール・呼出元・テストを探す。コードが事実の基準であり、文書との不一致は確認して修正する。過去の文書の記述をそのまま現仕様と扱わない。

## Roblox / Luauルール

- サーバーがHP/Shield、弾薬、Raycast、Loot、建築、能力、順位、勝者を決める。クライアントからダメージ・命中対象・レアリティ・配置CFrameを受け取らない。
- 既存のAction / Snapshot / Effectsを利用し、roundId・生存・Active/FinalZone・型・有限数・頻度の検証を維持する。
- 遅延Reload、Draft、アバター読込、BOT経路探索は死亡・リセット・新ラウンドへ持ち越さない。既存トークン/世代の仕組みを確認する。
- ModuleScriptの責務と単一サーバースケジューラーを維持する。毎フレームのInstance生成、無制限のループ/経路探索/音声を避け、後始末を実装する。
- 装飾は原則CanCollide/CanTouch/CanQuery=false。戦闘用衝突面との境界を崩さない。
- 未確認のAsset IDを作らない。TownTemplatesは[TOWN_BUILDINGS](docs/TOWN_BUILDINGS.md)の検査・フォールバック規則に従う。
- ローカル回帰ランナーはLua 5.4を利用する。Luau専用構文を追加する場合は、既存テストとの互換性を確認する。

## 維持する仕様

- Draft中も移動・射撃が続き、無敵にもならない。展開パネル/カードへのポインター入力だけを背景射撃・Aimへ貫通させない。
- PC DraftはREADYまたはVで展開/収納、モバイルは自動展開。5秒の期限・サーバー自動選択を勝手に変更しない。
- 死亡・途中参加時の観戦、PCのTab切替を維持する。processed入力でも、テキスト入力中以外の観戦Tabが失われないこと。
- Common/Rare/EpicはReload/Spreadだけを改善する。ダメージ・射程・弾倉・発射間隔を変更しない。
- ZoneはShieldを貫通し、最終半径ゼロでもダメージがある。同tick環境死の同順位/DRAWを維持する。
- 試合内の装備/能力/建築はリセットする。永続化は現仕様にない。
- PCとタッチの入力・HUDを両方確認する。PCの簡素化をモバイルにそのまま適用しない。Staminaは未実装なので表示や仕様を捏造しない。

## Rojo境界

`default.project.json`の`$path`は次の3つだけ。

| ローカル | Studio |
| --- | --- |
| src/shared | ReplicatedStorage/DropzoneShared |
| src/server | ServerScriptService/DropzoneServer |
| src/client | StarterPlayer/StarterPlayerScripts/DropzoneClient |

ルートAGENTS.mdとdocs/はこの範囲外で、Studioへ同期されない。Markdownをsrcへ移動したり、リポジトリ全体を$pathに追加したりしない。
ServerStorage/TownTemplatesの`$ignoreUnknownInstances: true`を保持する。Studioに保存されたモデルの実物はGitHubのコードだけでは確認できない。

## 検証と文書更新

リポジトリ直下で`python3 tests/run.py`と`python3 tests/preplay_analysis.py`を実行する（Windowsはpython）。前者はPython 3 + liblua5.4、または既存のlupa.lua54が必要。失敗/環境不足を成功と報告しない。
コード変更では関連QA項目とラウンド終了→次戦を確認する。オフラインテストはStudio描画・物理・実機・通信の保証ではない。

文書だけの変更はリンク、ソース根拠、diff、Rojoの$path範囲を確認する。ゲームコード・設定の差分がないことを確認する。
CURRENT_STATEに調査したmainのSHA・日付と未検証事項を記録し、TODOの完了項目にはPR/コミット・検証結果を付ける。PRには変更目的、確認結果、未実施の確認を短く記載する。
