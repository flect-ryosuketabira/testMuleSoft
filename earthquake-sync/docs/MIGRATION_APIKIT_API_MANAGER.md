# 移行手順: APIkit + API Manager (Client ID 強制)

現行 (自前の `x-api-key` 照合) から、Design Center の RAML + API Manager のポリシーによる認証へ移行する。

## 0. 変更の全体像

| 項目 | 現行 | 移行後 |
|---|---|---|
| 認証 | Mule フロー内で `x-api-key` を照合 | API Manager の Client ID 強制ポリシー (`client_id` / `client_secret` ヘッダ) |
| 仕様 | RAML は参考 (未使用) | RAML を APIkit が読み、ルーティング・入力検証に使用 |
| エンドポイント | `GET /earthquakes` | `GET /api/earthquakes` (Named Credential の URL 末尾を `/api` にする。Apex は変更不要) |
| Mule 設定 | `api.key` | `api.id` + 環境の Client ID/Secret (Auto-discovery 用) |

実装ファイル (本リポジトリで更新済み):
- `mule/src/main/mule/earthquake-api.xml` (APIkit ルーター + Auto-discovery)
- `mule/src/main/resources/api/earthquake-api.raml`
- `mule/src/main/resources/config.yaml`
- `mule/pom.xml` (APIkit 依存追加、CloudHub プロパティ変更)
- `.github/workflows/deploy.yml` (新しいプロパティを渡す)

## 1. 事前準備: ブランチを切る
動作中の構成を残すため、移行はブランチで行う。
```bash
git switch -c apikit-apimanager
```

## 2. Design Center で API 仕様を作成・公開
1. Anypoint Platform → Design Center → Create → New API Specification
2. Project name: **`Earthquake REST API`** / API type: REST API / RAML 1.0
3. `mule/src/main/resources/api/earthquake-api.raml` の内容を貼り付ける
4. 右上 Publish → Version `1.0.0`、LifeCycle `Stable`、**Asset ID は `earthquake-rest-api`**
   - Mule アプリ自身の Exchange 資産 ID は `earthquake-api`。同じ組織で ID が重複すると衝突するため、API 仕様は別名にする

## 3. API Manager に API を登録
1. API Manager → 環境 `Sandbox` を選択 → Add API → **Add new API**
2. Runtime: **Mule Gateway** (Mule 4)
3. API: Select API from Exchange → `Earthquake REST API` (1.0.0)
4. Proxy type / Implementation: **Basic endpoint** (プロキシは作らず、Mule アプリに直接ポリシーを適用)
5. Save → Deploy は **不要** (Auto-discovery で Mule アプリと紐付く)
6. 作成後の API 画面で、**API ID** (数字) と **Autodiscovery** の情報を控える

## 4. Client ID 強制ポリシーを適用
1. API Manager → 対象 API → Policies → Apply New Policy → **Client ID Enforcement**
2. 設定:
   - Client ID Expression: `#[attributes.headers['client_id']]`
   - Client Secret Expression: `#[attributes.headers['client_secret']]`
3. Apply。ポリシーは、Mule アプリが API Manager に接続した後に反映される (通常は数分以内)

## 5. クライアントアプリ (Salesforce 用) の作成
1. Exchange → `Earthquake REST API` → **Request access**
2. Application: **Create a new application** → 名前 `salesforce-app` (Redirect URI は不要)
3. API instance: 手順3の API を選択 → Request access
   - 承認が必要な設定の場合は、API Manager → Client Applications で承認する
4. 作成したアプリの **Client ID / Client Secret** を控える (Access Management → Applications でも確認可)

## 6. Mule アプリ用の環境クレデンシャルを控える
Auto-discovery は、環境の Client ID/Secret で API Manager に接続する。
- Access Management → Environments → `Sandbox` → **Client ID / Client Secret**
- 手順5のクライアントアプリの値とは別物。取り違えないこと

## 7. GitHub の設定を変更
Settings → Secrets and variables → Actions
- Secrets (新規): `ANYPOINT_ENV_CLIENT_ID`、`ANYPOINT_ENV_CLIENT_SECRET` (手順6の値)
- Variables (新規): `API_ID` (手順3の API ID)
- Secret `API_KEY` は不要になる (削除してよい)

## 8. コードを反映してデプロイ
```bash
git add -A
git commit -m "Migrate to APIkit + API Manager (Client ID enforcement)"
git push -u origin apikit-apimanager
```
`deploy.yml` は `main` への push で起動する。ブランチ運用の場合は、`workflow_dispatch` で `apikit-apimanager` ブランチを選んで実行するか、`main` にマージして実行する。

デプロイ成功後、Runtime Manager のログで確認する項目:
- `api-gateway` / `autodiscovery` に関するエラーがないこと
- API Manager の API ステータスが **Active** (Auto-discovery の状態) になっていること
- ステータスが Unregistered / Inactive の場合は、`API_ID` と環境クレデンシャルを再確認する

## 9. 疎通確認
```bash
URL="https://<Runtime ManagerのPublic Endpoint>"
# 認証なし: 401 になる (ポリシーが効いている証拠)
curl -i "$URL/api/earthquakes?limit=1"
# 認証あり: 200
curl -i -H "client_id: <手順5のClient ID>" -H "client_secret: <手順5のClient Secret>" "$URL/api/earthquakes?limit=3"
```
- 認証なしで 200 が返る場合は、ポリシー未反映。数分待つか、API のステータスを確認する

## 10. Salesforce 側の変更
1. 外部資格情報 `Mule_Earthquake_EC` のプリンシパル `Mule_Principal`
   - 認証パラメーター `ApiKey` を削除し、`ClientId` と `ClientSecret` を追加する (手順5の値)
2. 外部資格情報のカスタムヘッダー
   - `x-api-key` を削除する
   - `client_id` = `{!$Credential.Mule_Earthquake_EC.ClientId}`
   - `client_secret` = `{!$Credential.Mule_Earthquake_EC.ClientSecret}`
3. Named Credential `Mule_Earthquake_API` の URL を `https://<Public Endpoint>/api` に変更する (末尾スラッシュなし)
4. `System.enqueueJob(new EarthquakeSyncJob());` で動作確認する (Apex の変更は不要。呼び出しパスは `/earthquakes` のまま)

## 11. 切り戻し
問題が出た場合は `main` ブランチ (旧構成) を再デプロイし、Salesforce の外部資格情報とURLを元に戻す。

## 12. 未検証の事項 (初回実行時に確認)
- APIkit 1.10.4 とランタイム 4.6.x の組み合わせ (依存解決エラーが出る場合は 1.11.x などに変更)
- Auto-discovery のプロパティ名 `anypoint.platform.client_id` / `anypoint.platform.client_secret` と CloudHub 2.0 での動作
- `ignoreBasePath` の設定と RAML の `baseUri` (`/api`) の整合
- Client ID の資格情報は CloudHub のプロパティに平文で保存される。本番運用では Secure Properties の利用を検討する
- 無償トライアルでの API Manager の機能制限 (ポリシー数など)
