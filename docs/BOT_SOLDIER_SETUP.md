# Studioの兵士モデルをBOTに使う

通常のDROPZONEはコードから旧型ドローンを組み立てます。**兵士モデルをツールボックスに持っているだけではゲームに配置されません。**
コードは `ServerStorage > BotModels > Soldier` にあるStudio所有のモデルだけを読み込むようにしました。

## Studioでの登録

1. DROPZONEのPlaceを開き、**編集モード**（Play停止中）にします。
2. Explorerで `ServerStorage` を開きます。Rojo同期後、`BotModels` フォルダが見えるはずです。なければフォルダを作り、名前を正確に `BotModels` としてください。
3. Toolboxの兵士を一度Workspaceに挿入し、Explorerの中身を確認します。**元のモデルに紛れ込んだScript/LocalScriptなどは実行させないため、必ずPlay停止中に作業してください。** 不明なスクリプトは手作業でも削除することを推奨します。
4. 兵士の最上位が `Model` であり、直下に `Humanoid`、`HumanoidRootPart`、`Head`、`Torso`（R6）または `LowerTorso`（R15）、腕・脚と正常な `Motor6D` があることを確認します。単なる一枚のMeshPartや飾りモデルは、そのままでは歩くBOTにできません。
5. モデルを **`Soldier`** と正確に改名し、**Workspaceから `ServerStorage/BotModels` に移動**します。フォルダに一体だけ登録すれば、試合では必要な数を複製します。
6. Rojoが接続中なら同期ダイアログを確認し、`BotModels` と `Soldier` が保持されていることを確認します。**`default.project.json` にはBotModelsを `$ignoreUnknownInstances=true` で登録済み**です。GitHubにモデル本体は保存されず、StudioのPlaceファイルに保存されるので、**Placeを保存／公開**してください。

## 仕様と注意点

- テンプレートが有効なら、11体のBOTにも同じ兵士外見を使用できます。武器、HP、AI、射撃判定、BOTの数は今までどおりです。
- Toolbox素材のスクリプト、危険な力・Remote類、音・エフェクトはゲームへの複製時に削除します。装飾部品は非衝突にするため、動きに干渉しにくくなります。
- `HumanoidRootPart` を持つ正常なR6/R15キャラクターが必要。連結Motor6Dと基本胴体／頭／手足を要求し、テンプレートは最大160 descendants／80 BaseParts。条件に合わなければ**旧型ドローンを使用**し、Studioの**Output**に `[DROPZONE] BotModels/Soldier:` で理由を一度だけ表示します。
- Roblox Studioの **Play** でBOTの見た目、手持ち銃、歩行、衝突、死亡・次ラウンドの再生成を確認してください。**Rigのサイズ・関節が変則的なAssetは、物理的に問題が出る可能性があります。**
- Toolboxのモデルを後で消しても、すでにServerStorageに複製・保存されたモデルは残ります。反対にStudioの`Soldier`を消した場合は旧型BOTに戻ります。
- まだStudio上の実モデルはこのチャットから直接操作できません。**GitHubの修正と、Studioでのモデル登録は別作業**です。
