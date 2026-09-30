# Town building templates

Townは、外部Assetがなくても軽量なスタイライズド建物で動作します。Creator Store / Toolboxの候補を採用する場合は、存在しないAsset IDをコードへ直書きせず、Studioで実物を確認して次の場所へ保存してください。

```text
ServerStorage
└─ TownTemplates
   ├─ House01
   ├─ House02
   ├─ House03
   ├─ Shop01
   ├─ Shop02
   ├─ Office01
   └─ Warehouse01
```

同じテンプレートは色、向き、看板、小物を変えて再利用できます。すべて揃える必要はありません。欠けた名前や安全検査に失敗した名前だけコード生成版へ戻ります。
`default.project.json`は`TownTemplates`の未知の子を保持する設定なので、Rojo同期でStudioへ置いた候補を消しません。

## Toolbox検索の目安

Creator Storeで次の語を組み合わせ、ライセンスと制作者をStudio上で確認してください。

- 住宅3種: `stylized low poly house`, `cartoon suburban house`, `bright modular house`
- 店舗1〜2種: `stylized shop`, `cartoon storefront`, `low poly corner store`
- 倉庫1種: `stylized warehouse`, `low poly garage`, `cartoon workshop`
- 小型オフィス1種: `stylized office`, `low poly commercial building`

1モデルあたりの推奨上限はBasePart 40〜80、MeshPart 0〜24です。コード上の受入上限はBasePart 96、MeshPart 32、Collision Part 20、外形50×34×50 studsです。Textureを何枚も重ねたモデル、非常に細かい家具、透明Partを多用するモデル、Union/Meshが細分化されたモデル、動くドアやエレベーター、Vehicle、NPC、武器、管理コマンドを含むモデルは避けてください。

## Studioでの準備

1. 候補を空の検査用Placeへ挿入し、Explorerで全子孫を確認します。
2. `Script`、`LocalScript`、`ModuleScript`、Remote、Sound、Light、Particle、Prompt、ClickDetector、物理Moverを削除します。実行時コードも再度除去します。
3. Pivotを建物の地面中央へ設定し、正面をローカル`+Z`へ向けます。入口は幅10 studs以上、高さ7 studs以上、段差なしを推奨します。
4. 実際に遮蔽物にする単純な壁・屋根だけを子`Folder`の`Collision`へ入れるか、対象PartへBoolean属性`TownCollision = true`を付けます。装飾MeshをCollisionへ入れないでください。
5. Collisionは壁6〜10枚＋屋根1枚程度に簡略化します。窓枠、看板、雨樋、取手、家具、小物はCollisionにしません。
6. 上記の正確な名前で`ServerStorage/TownTemplates`へ移動します。元AssetのScriptが残っていてもServerStorageから直接Workspaceへ複製せず、`Town.lua`の検査済みcloneだけを使用します。

検査済みcloneでは、Collisionだけが`Anchored=true / CanCollide=true / CanQuery=true / CanTouch=false`になります。それ以外の見た目Partは`Anchored=true / CanCollide=false / CanQuery=false / CanTouch=false / Massless=true`です。危険・不要クラスはcloneがWorkspaceへ入る前に再帰削除されます。

## 採用判断

遠距離で住宅・店舗・倉庫の輪郭が識別でき、入口が看板や濃色窓より明確であることを優先します。見た目が良くても、正面と裏口の幅、左右の回り込み、BOTのPath、Lootとの間隔、弾のRaycast、スマホ画面の視認性を満たさない候補は採用しません。
