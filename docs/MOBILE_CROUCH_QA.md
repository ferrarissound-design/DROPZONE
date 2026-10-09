# スマホUI・しゃがみ回帰確認

対象: `fix/mobile-ui-grounded-crouch-20261009`、基準main `055bcded6dd018b7f7374a305d610cf84fd89c7e`。

## 自動確認

- `python3 tests/run.py`: PASS。姿勢数値307、画面配置1054 assertionsと既存回帰。
- `python3 tests/preplay_analysis.py`: PASS。`git diff --check`: PASS。
- 数値テストは標準Motor6Dリグの静止姿勢。Roblox物理・歩行Transform・IK合成・実機操作の保証ではない。

## Studio / 実機で未実施の確認

1. 小型横画面、ノッチ付きiPhone、タブレット、縦横切替で確認。FIREがオレンジで押せる大きさ、補助ボタンとミニマップが縮小、FIRE/建築が離れ、標準Jump/スティック/装備/Draft/他ボタンが重ならない。
2. AIMを繰り返しタップして弾薬が減らないこと。FIRE長押し＋ドラッグ、移動＋射撃＋Jump、FIRE保持から建築切替、Wall/Floor/Ramp選択→PLACE→戦闘復帰を確認。
3. R15/R6と小型/標準/大型アバターで、静止→しゃがみ→歩行→立つを10回。足が地面の上に残り、立つ位置に累積ずれがないこと。R6は膝関節なしの簡易股関節姿勢。
4. 坂を上り/下り、坂を横切り、段差端/建築Ramp/Floorで繰り返す。めり込み・浮き・引っ掛かり・地面の下への移動がないか実物理で確認。姿勢処理はRootPartの位置やHipHeightを下げず標準Humanoidの接地処理を使う。
5. Sprint→Slide→Crouch、Crouch/SlideからJump、CrouchからSprintで立ち姿勢へ戻る。空中・死亡・Results・次戦に姿勢が残らない。
6. 3武器の通常射撃/AIM/Reloadと進化装甲0/1/3/5段階。胴体が下がるため、既存root基準の表示銃・左右IK・装甲と干渉せず自然に見えるか重点確認。射撃サーバー起点は変更していない。
7. PCのWASD/左射撃/右AIM/Shift/Ctrl/Space/Q、通常のHUD配置を回帰。複数人で他プレイヤーの姿勢が見えるか確認し、最低3試合継続。

標準Root/RootJoint＋両脚Motor6Dチェーンがないカスタム/AnimationConstraintリグは身体を沈めず元の地上クリアランスを維持する。視覚的しゃがみ対応は別途必要。

記録: 日付、機種/解像度、R6/R15/リグ方式、人数、試合数、足元/歩行/斜面/段差/武器/装甲/操作/次戦の結果とOutputエラー。未実施項目をPASSにしない。
