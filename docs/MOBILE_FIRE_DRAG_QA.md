# Mobile Fire Drag QA

調査main: `4ca51bba259e444f22b3a43b3c1f504ebcd17f7e`。2026-10-05。

## 操作と実装

射撃ボタンに指を置く → 即時射撃 → 指を置いたまま上下左右へ滑らせる → 照準とカメラを回転しつつ既存の間隔で射撃 → 指を離すと停止。ボタンの矩形から外れても、同じ指の保持中は追跡する。解除時はsetCombatAim(false)の既存短時間hold/recoveryに戻る。

Fire GUIから始まったInputObjectだけを捕捉する。別の指やDraft/Reload/装備等から始まった指は照準入力にしない。開始時のDraftパネル矩形も除外する。Draft表示中でも別のFire指による戦闘は維持する。入力の移動量は1フレームに1回だけ消費し、dtで再乗算しない。

更新順: Camera priority - 1でundoCamera → FireDrag回転 → Roblox標準カメラ → Camera priority + 1で既存Presentation.step → 長押し射撃。表示されたカメラを既存aim()が読み、既存Aim Assistとdirectionのみの通信を維持する。初回射撃は従来どおり即時。FireDragは反動用appliedには含めず、解除時に視点を元へ巻き戻さない。

Fire.Active=trueで開始したTouchを標準CameraInputがprocessedとして保持する前提。通常の画面ドラッグは標準のまま。Scriptableカメラへの回転は行わない。Focus、距離を維持して周回し、標準カメラに被写体追従・Zoom・遮蔽を任せる。

参考一次ソース:
- https://github.com/Roblox/avatar/blob/main/ReferenceBodyCreator/StarterPlayerScripts/PlayerModule/CameraModule/CameraInput.lua （touches[input]に開始時のsunkを保持し、未消費Touchだけでpan/pinch）
- https://github.com/Roblox/avatar/blob/main/ReferenceBodyCreator/StarterPlayerScripts/PlayerModule/CameraModule/ClassicCamera.lua （既存カメラlookを基準に新しいカメラを計算）

## 自動確認結果

| コマンド | 結果 |
| --- | --- |
| python3 tests/run.py --client-only | PASS: 全src構文検査、249 client/server assertions（47追加） |
| python3 tests/preplay_analysis.py | PASS: 武器・Zone・建築・Rarity・Evolution理論値 |
| python3 tests/run.py | FAIL: regression.lua:15 nativeRequire(nil)。未変更のmainでも同一失敗 |

全体ランナーの既存regression doubleはCosmeticsのPresentationConfig依存を登録していない。対象外のゲームコードは変更せず、client-onlyで実際のMain/FireDrag/Combatを検証する。全体テストのPASSは主張しない。

追加テストは開始・方向/感度・距離・ピッチ上限と逆ドラッグ・ボタン外追跡・連射と新しい照準方向・無移動時の非累積・別指・解除・キャンセル・フォーカス・キャラクター再生成・roundId・死亡・Results・Draft境界・他HUD・Scriptable・破棄・反動前後順・既存Assist/LOS/角度/距離を確認。既存PCクリック/右Aim/キー/装備/観戦と実Combat数値テストも通過。

## Studioで確認が必要（全項目未実施）

| 項目 | 確認手順 / 合格条件 |
| --- | --- |
| 実機Fire Drag | iOS/Android横画面でRifle長押し、上下左右へドラッグ。画面上の照準で動くBOTを追いながら連射できる。ボタン外でも継続し、離すと止まる |
| 標準カメラとの競合 | 同じ移動量で不自然な二重回転・振動・反動累積・解除時の巻き戻りなし。通常右画面ドラッグと別指併用、近壁のZoom/遮蔽も確認 |
| 複数Touch/UI | 移動+射撃ドラッグ+Jump、別指Reload/Sprint/Crouch/Build/装備、Draft選択で誤照準なし。Fire指を離しても他の指へ所有権が移らない |
| Assist/壁 | 見えている敵の約5度以内で既存補助が有効。壁を挟んで補助/命中が発生しない。近距離肩越し遮蔽も確認 |
| Presentation | 反動/肩寄せ/FOVの遷移・復帰、Sprint/Slide/Build時の既存Aim取消、Pistol/Shotgun/Rifle切替を確認。武器姿勢の見た目修正は別タスク |
| リセット | 押したまま死亡、リセット/respawn、Results→次戦、バックグラウンド化。復帰後に勝手に撃たず新Touchで動く。連続3試合 |
| PC回帰 | 左射撃/右Aim/マウス、Reload、Sprint、Crouch/Slide、Build、Draft、Spectate。長押しのcadenceと最新カメラによる方向を確認 |
| Studioアセット | Rojo同期後にTownTemplates/WeaponModels/手動配置物が維持される。今回はproject JSONとアセットへの変更なし |

## 残る懸念

実際のprocessed Touch保持、標準CameraModuleとの連携、描画/物理/通信、端末ごとの画面pixel感度はオフラインdoubleでは証明できない。.18度/pixelは初期値で実機調整が必要。標準Classic/Custom以外の独自カメラやFollow/VRはこの作業の実機検証対象外。既存全体テストdoubleの追従不足は別途修正が必要。
