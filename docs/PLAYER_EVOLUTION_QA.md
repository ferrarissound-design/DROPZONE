# プレイヤー進化ビジュアル — 実装と確認

基準main: `4c3e7e4dec98267c85bd9e666410030141e3472a`。実装ブランチ: `feat/player-evolution-visuals-20261008`。

## 段階と能力

進化回数は見た目専用。11能力の数値・最大III・Draftの3択/5秒/Stack処理は既存どおり。

| 累計回数 | 外見 |
| --- | --- |
| 0 | 元アバター、装甲/演出なし |
| 1〜2 | 選択能力の機械装甲と発光ユニット |
| 3〜4 | 能力パーツに加え肩・腕・脚の共通シャーシ |
| 5以上 | 重肩装甲、胸部装甲/中央コア、背部ユニットと2本の発光タワー |

| 能力 | 装着部位 / 外見 |
| --- | --- |
| Swift Legs | 両脚の加速装置とシアンのライン |
| Iron Skin | 胸部装甲、両肩装甲、オレンジの発光シーム |
| Hunter Eyes | 頭の機械ブロウと赤いバイザー |
| Quick Hands | 右前腕のガントレット、発光表示、II以上でフィン |
| Builder | 左前腕の建築支援装置、発光表示、II以上でフィン |
| High Jump | 両脚の後方ブースターと発光排気口 |
| Regeneration | 胸部左側の緑色再生コア |
| Scavenger | 腰の左右補給パックと発光残量表示 |
| Adrenaline | 胸部と両腕のシアンのエネルギーライン |
| Combat Shield | 胸部右側の青いシールド装置、両肩の発光ノード |
| Overcharge | 背部リアクター、II以上で追加エネルギーセル |

同一能力は同じキーのPartを再利用し、サイズ/厚さ/発光面積と不透明度を強化する。異なる能力は共存。服・アクセサリーを置換/削除しないが、装甲が一部を覆う。R15は下腕/下脚、肩は上腕、胸/腰はUpperTorso/LowerTorso。R6は対応するArm/Leg/Torso。存在しない部位はスキップする。

## 処理境界と負荷

- `PlayerEvolutionVisuals`: サーバーで生成しWorkspaceのキャラクターへ複製。人間のみ。BOTの旧Mutationだけ除去し、DroneShell/兵士モデルと能力/AIは保持。
- `Evolution`: 手動選択・5秒自動選択・grantの確定後に共通入口を呼ぶ。能力計算と描画は分離。
- 演出: 約0.45秒のHighlight、装甲Size/Transparencyの展開Tween、胸部の小型エネルギーパルス。既存EvolutionApplied音を維持し、旧ローカルHighlightは撤去。
- 上限: 常設Part 64個/人のハード上限。全11能力III+最終装甲のテスト実測は50個、演出時のみ追加Part 1個。Highlight/パルスはサーバー全体で同時4人まで。上限超過時も常設装甲は更新し、一時演出だけ省略。
- ParticleEmitter/Light/Trail/外部Meshなし。全PartはCanCollide/CanTouch/CanQuery=false、Massless=true、影なし。元の戦闘判定面・射撃Raycast・移動ロジックは変更しない。
- `EvolutionVisibility`: 自分の装飾のみAIM開始〜解除ブレンド終了までLocalTransparencyModifierで隠す。AIM開始時の透明度を保存して解除時に一度だけ復元し、通常時はRobloxカメラの透明度更新を上書きしない。サーバーTransparency/他人の外見/観戦対象は変更しない。DescendantAddedで新規装飾を登録し、毎フレーム全キャラクター探索をしない。
- 死亡でTween/パルスを停止し既存装甲は遺体に残す。Resultsで全Actorの所有装飾を破棄。Actor再登録/clearでも古い所有装飾を削除。タイマーは状態オブジェクトの同一性で古い進化の破棄を防ぐ。

## オフライン確認

`python3 tests/run.py`、`python3 tests/preplay_analysis.py`を実行。`tests/evolution_visuals.lua`は実装Moduleをengine doubleで実行し、両Rig、0/1/2/3/4/5/33回、Stack成長、複合装甲、全能力の部位、非衝突Weld、BOT旧Mutation除去、欠損部位、古いPulse callback、同時演出上限、自分のみAIM非表示/解除、新着装飾、死亡停止/次戦リセット、他人の所有権を検証。

既存回帰はDraft手動/自動選択から描画入口が呼ばれること、Resultsのclear、戦闘/移動/建築/観戦/モバイル入力を検証。模擬環境は描画・物理・通信・実機の保証ではない。

## Studio / 実機 — 未検証

1. R6/R15の人間プレイヤーで0→1→3→5回の進化を確認。服装・アクセサリーの異なるアバター、小型/大型BodyScaleでも、肩/胸/腕/脚/背部が意図した位置か確認。
2. 同じ能力I→II→III、複数能力混在、5秒自動選択を試す。約0.45秒の展開・音・発光の同期、短時間連続取得のちらつきを確認。
3. サーバー2人以上で相手の進化を確認。死亡後の観戦からも同じ外見が見え、BOT兵士外観は進化前後で変わらないこと。
4. Rifle/Shotgun/Pistol、PC右クリック/スマホAIMトグルを確認。装甲が照準/銃口/肩越し視点を隠さず、AIM解除で復元し、他人側では外見が維持されること。通常PCカメラを一人称へズーム→AIM→解除→三人称へ戻し、カメラが設定する非表示/復元を装甲処理が妨げないこと。
5. Sprint/Crouch/Slide/Jump/Reload、戦闘⇔建築、Draft選択中の移動・射撃を確認。装甲が関節をまたいで固定されず、当たり判定・射線・接触を増やさないこと。
6. 死亡・退出・Results・再生成・次戦を3試合続け、装甲/Highlight/パルスの残留と重複がないこと。
7. スマホ実機で初期/中級/高度、複数人の同時進化、建築多めの条件でFPS/メモリ/描画時間を比較。50Partの構造上限だけで低負荷達成と判定しない。

GitHubにStudio保存の兵士アセット実物はないため、その素材を変更・検証したとは扱わない。外部モデル追加や手作業での装甲配置は不要。
