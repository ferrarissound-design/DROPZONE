# 公開前プレイテスト

## 自動チェック済み / 未確認の区別

- 自動チェック：全Luaソースの構文（Lua 5.4互換部分）、Evolution Draftの候補数・候補外拒否・二重選択拒否・時間切れ自動選択・死亡/Reset時破棄・Stack上限/逓減、連続ラウンドの状態クリア、人数補充計算、Shield/HP計算、過剰ダメージ集計、ゾーン全区間、次ゾーン包含、半径ゼロ、死亡の重複、順位、勝者、装填途中の持ち替え/死亡、発射間隔/弾切れ。
- コードレビュー：Remote入力境界、遅延コールバック、途中参加/退出、描画物の上限、状態リセット。
- **未実施：Roblox Studio実行、スマートフォン実機、Rojo実ビルド、複数クライアント、Server/Client Outputの無エラー確認。**

以下はチェック手順であり、確認済みという意味ではありません。

## 1人で連続2試合

1. 空のDROPZONE Placeへ同期し、Play。OutputをServer/Client両方開く。
2. ロビー→約12秒→分散スポーン。残り12人（自分 + BOT11体）。
3. 近くの発光武器を拾う。取得通知、銃の外観、武器名、Ammoを確認。
4. Rifle/Pistol/Shotgunで弾薬消費、弾切れ、装填、1/2/3の切替を確認。
5. 装填途中に持ち替えても別の武器へ弾が移らない。
6. 自分・BOT双方にHP/Shieldダメージ。壁越しに命中しない。
7. 撃破でKill/残数が1回だけ更新し、3枚のEvolution候補を確認。1枚選び、能力名/ランク/発光パーツの反映を確認する。選択中にも移動・射撃でき、他のBOT/プレイヤーが動き続ける。別の撃破で5秒放置し、候補から自動選択されることも確認。
8. 壁・床・坂を設置。Energy消費、通行、弾での破壊、寿命、障害物への重複拒否。
9. BOTがコンテナ/町/森で探索し、ゾーン外から帰還する。詰まった座標を記録。
10. ゾーンの現在/次の線とミニマップ、縮小タイマー、継続ダメージ。
11. 敗退後に射撃/取得/建築ができず、観戦対象を切替できる。
12. BOTを含む最後の1人が勝者になる。リザルトの順位/キル/ダメージ/生存時間。Stormで最後の複数人が同tickに倒れた場合は同順位のDRAW。ゾーンが375秒でゼロになる。
13. **Stopせず2試合目**。HP100、Shield0、Kill0、Damage0、Evolution0、Energy60。
14. 武器・変異パーツ・速度・ジャンプ・建築・Loot・BOT・ゾーン・通知が前戦から残らない。
15. 2試合目に別のEvolution候補が出る。死亡直後とVictory/Resultsへ遷移する瞬間にカードが閉じ、後から能力が加算されない。
16. HUDが1枚のみ。再度リロード、取得、撃破、勝者決定まで実行。
17. Server/Client両方のOutputにエラーがないことを確認。

## 複数クライアント / 異常系

- 2人→BOT10体。12人→BOT0体。途中参加はロビー待ち/観戦のみ。
- 試合中退出、死亡直後退出、最後の人間退出でも次の試合が止まらない。
- Starting中のキャラクター読み込み失敗/遅延で永久待機しない。
- RobloxメニューのReset Characterで敗退し、そのラウンドに復帰しない。
- 装填中に死亡/試合終了しても遅延処理が次戦の弾薬を変更しない。
- 候補番号の範囲外、期限後、死亡後、古いroundId/draftIdのEvolution要求は無効になる。同じDraftへの連続タップは1能力だけ取得する。
- UI上でカード領域がWall/Floor/Ramp、Build、Reload、武器Slotと重ならず、カードタップがそれらを発動しないことを確認する。カード外の射撃ボタンと移動/視点操作はDraft中も使える。
- 不正なFire引数、NaN、古いroundId、連続Build、弾切れFireが無効になる。
- 終盤半径ゼロで中心キャンプしても決着する。

## スマホ / 性能

- Device Emulatorの小さい横画面・タブレット、その後実際のスマホで確認。
- 左スティック、右カメラ、射撃長押し、ジャンプが同時に使える。
- 射撃タッチをボタン外で離しても射撃が止まる。バックグラウンド復帰後も止まる。
- 武器枠、壁/床/坂、装填、建築が押せる。標準ジャンプと重ならない。
- 16:9と幅の狭い横画面でEvolutionカードの能力名/Rank/効果/カテゴリが読める。3枚目がBuild/Reload/Wall/Floor/Rampの入力域に触れない。
- PCはDraft中にマウスカーソルが解放され、3枚すべてをクリックで選択できる。カードクリックで射撃・Build・Reloadが発動しない。
- セーフエリア、照準と実際の着弾点、観戦カメラを確認。
- BOT11体、建築100個付近、Shotgun連射時のフレーム時間とメモリを測定。
- Studio Script Performance/MicroProfilerでAI経路探索が滞留していないか確認。

調整は `Config.lua` / `Weapons.lua` を起点に行い、検証後に公開してください。

## Release gate（全項目未実施・公開前必須）

実行した日付、Studio版、端末、人数、Output、問題座標を記録してください。P0/P1、重要UI重複、継続エラーが1件でもあれば公開しません。

- [ ] Solo + BOT11で開始し、勝敗まで完走。Stopせず2試合、可能なら3試合。
- [ ] 全24スポーンで初期武器へ到達可能。屋根・壁・木に埋まらず、BOTも取得可能。
- [ ] 初見の人が30秒以内に武器取得・敵・Zone・進化の目的を理解できる。
- [ ] 初回Draftを開いてClient OutputにColor3エラーなし。手動/Auto Pick、死亡、Results、Resetで残留なし。
- [ ] HP/Shield低下のフラッシュ、撃破通知、進化取得、Zone警告、Victory/Build結果が読める。
- [ ] 16:9と狭い横画面で移動/Jump/視点/Fireを維持し、Draft・建築・装填・Slotの誤操作なし。
- [ ] BOTが武器を持ち替え、町内部の敵を追い、Zoneへ戻り、障害物で永久停止しない。
- [ ] PistolでもBOTを倒せる。Shotgun遠距離と最大Stackが過剰でない。Wall/Ramp/Floorが役立つ。
- [ ] 途中参加/退出/全員退出/ロード遅延、同tickのZone複数死亡で進行停止なし。
- [ ] BOT11、Build100、Shotgun、Mutation、Loot同時表示時の実機FPS/メモリ/通信量を記録。2試合目に増え続けない。
- [ ] Rojo実ビルド/同期とServer・Client Outputの無エラーを確認。

Offlineでは `python3 tests/run.py` を実行。809 assertionsはゾーン時系列の反復検査を含む件数で、809種類の実機シナリオではありません。UIダブルはカード色の型と送信中/次Draftの復帰を実行検証しますが、タッチ入力・Robloxレイアウト・物理・経路探索・ネットワークの実機検証は代替しません。

## Visual Identity確認（Studio・実機では未実施）

- [ ] 3武器の輪郭を小さい画面でも見分けられる。R6/R15の手へ正しく装着され、持ち替え/死亡/2試合目に旧武器が残らない。
- [ ] 武器/Drone装甲/Mutation/建築Frame越しのRaycastは装飾を無視し、以前と同じ本体Hitboxへ命中する。
- [ ] 白いDroneとプレイヤーを区別でき、進化後も顔・武器・胴体が読める。
- [ ] Coreリングは上空にありFinal Battleの移動や視界を妨げない。Townの入口・Loot・Warehouseの通路は従来通り使える。
- [ ] Hillは従来の斜面を登れる。Sceneryの色面や低い装飾岩が床/遮蔽物と誤認されない。
- [ ] 全Loot種類を形で区別でき、取得/Resetでモデル全体が消える。武器Pickupが地面に埋まらない。
- [ ] Wall/Floor/RampのFrameが本体に沿い、破壊/寿命/Reset時に一緒に消える。
- [ ] 16:9・狭い横画面で能力名/Rank/効果/カテゴリを読める。カードのクリック/タップ領域は従来の190×127。右側操作・Slot・標準Stick/Jumpを遮らない。
- [ ] 最大長のRegeneration III / Combat Shield IIIがカード内に収まる。選択中表示は取得確定と混同されない。
- [ ] HP/Shield/最大Stack時のEnergyバー、弾倉とReserve、大きなVictory/主要Buildが正しく表示される。
- [ ] Rojo同期後のLightingが明るく、Neonの白飛び・強いBloom・Fogによる視認性低下がない。
- [ ] 前版と同条件で低性能スマホのFPS/メモリを比較。BOT11、Build100、最大Loot、Shotgun、Mutation同時表示を測定する。

装飾予算：Map追加193Part、武器4/5/6Part、Drone追加7Part、消耗品Loot3Part、武器Loot4〜6Part、建築追加2Part/個（上限時200Part）。すべてイベント時/初期化時の生成で、毎Frame生成・追加Particle・追加Light・外部Meshなし。描画負荷はゼロではないため、実測で公開可否を決めてください。

`tests/visuals.lua` は実コンストラクタをengine doubleで実行し、装飾フラグ、Part数、持替え/破棄、Drone本体寸法、HUDバーとDraft終了、UI再生成を確認します。536 assertionsは各Partの反復検査を含みます。描画・物理・タッチの再現テストではありません。

## Movement / Rarity / Combat Feel（Studio・実機未確認）

- [ ] ShiftでSprint、CtrlでSlide→Crouch、CtrlでStand。SpaceでSlide/Crouch解除。Shiftが標準Shift Lockを動かさない。
- [ ] スマホ「走る」「しゃがみ/スライド」を、移動Stick・Fire・標準Jumpと同時操作。16:9と狭い横画面でDraft/Build/Reload/Slotとの重なり・誤操作なし。
- [ ] 空中/死亡/ResultsでSprint・Slide要求を拒否。フォーカス喪失でSprint解除。Sprint→Jump→着地後の再入力が自然。
- [ ] 平地/Hill/Build RampでSlideが減速し、壁へ押し続けない。0.65秒後に滑走が残らず、Jump取消でも2.1秒の再使用待ちは残る。
- [ ] Swift Legs III + Adrenaline IIIでもWalkSpeed32以下。Draft中の選択・Auto Pickで速度/姿勢が崩れない。
- [ ] 同じRifleのCommon/Rare/EpicでDamage・連射間隔・弾倉数が同じ、Reload/Spreadだけ少し改善する。
- [ ] Common→Epicの自動更新、Epic→Commonで非降格。装填中の更新で古いコールバックが弾を増やさない。
- [ ] 同時に2人が同じLootへ入っても1回だけ取得。BOTもレア武器を拾い、射撃/Reloadできる。
- [ ] レア度マーカーとラベルが地面や草と区別できる。足元マークは非衝突・非Raycast。取得・Resetで消える。
- [ ] 命中時だけHP/Shield数値。Shotgunが7枚の数字を乱発せず、過剰ダメージを表示しない。ミス/建築への命中では敵ダメージ数字なし。
- [ ] 撃破フラッシュ→Evolutionカード、最後の撃破→Victoryが読める。古いroundIdの数値は表示されない。
- [ ] 2試合連続でSprint/Slide/Crouch、Inventory rarity、Loot rarity、数値表示、Tween、HUDが残らない。
- [ ] BOT11 + 最大Build + 全Loot時の実機FPS/メモリ、ダメージ表示連発でも表示枠8個以下。高Pingでも滑走終了とサーバー速度が一致する。

自動検証：既存を含む870 gameplay assertions、558 visual/pickup/pool assertions、全Lua構文、UI矩形の非重複、Movement RemoteのRound/Alive共通ガード。件数にはPartやゾーンの反復チェックを含みます。標準Stick/Jumpのエンジン配置は矩形テストの対象外です。

Mantle拡張案：前方の低い障害物をサーバーRaycastで確認し、上面・頭上空間・着地のCapsule相当範囲とZone/Map境界を検証。Build Wallと動的物体を除外し、短いCooldownと移動距離上限を設ける。現行の所有権/斜面/低い遮蔽物で安全な検証ができるまでは実装しません。
