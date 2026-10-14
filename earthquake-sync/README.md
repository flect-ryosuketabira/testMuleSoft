# 地震情報連携 (Salesforce → MuleSoft → P2P地震情報)

## 構成

```
Salesforce                    MuleSoft (Mule 4 / CloudHub)           P2P地震情報
Schedulable(5分毎)
 └ Queueable ── HTTPS ──▶ GET /earthquakes?limit=100  ── HTTPS ──▶ GET /v2/history?codes=551
      ▲   (Named Credential, x-api-key)   └ DataWeaveで正規化 ◀── JSON ──┘
      └─ upsert Earthquake__c (外部ID: P2PQuake_Id__c) ◀── 正規化JSON ──┘
```

- 取得方式: Salesforceからポーリング。Schedulableは直接コールアウト不可のためQueueableへ委譲
- 対象: 情報コード551(地震情報)のみ
- 冪等性: 外部ID upsert。重複取得・再実行で重複しない
- P2PQuake側仕様: 履歴APIは `limit`(最大100) / `offset` / `codes` 指定。時刻はJST文字列、`-1`は不明値

## Mule APIコントラクト

| 項目 | 内容 |
|---|---|
| `GET /earthquakes` | クエリ `limit`(既定100, 上限100), `offset` |
| 認証 | ヘッダ `x-api-key`(config.yamlの`api.key`と照合)。不一致は401 |
| 上流障害 | 502 |
| 変換 | 日時→ISO8601(+09:00)、-1→null、最大震度コード→ラベル(10→"1", 45→"5-", 50→"5+" ...) |

## Salesforce項目マッピング (Earthquake__c)

| JSON | 項目 |
|---|---|
| id | P2PQuake_Id__c (外部ID/ユニーク) |
| occurredAt / issuedAt | Occurred_At__c / Issued_At__c |
| hypocenterName | Hypocenter_Name__c |
| latitude / longitude / depthKm / magnitude | Latitude__c / Longitude__c / Depth_Km__c / Magnitude__c |
| maxScale / maxScaleLabel | Max_Scale_Code__c / Max_Intensity__c |
| domesticTsunami / foreignTsunami | Domestic_Tsunami__c / Foreign_Tsunami__c |
| issueType / issueSource / correct / comment | Issue_Type__c / Issue_Source__c / Correct__c / Comment__c |
| points[] | Points_JSON__c (JSON文字列) |

## セットアップ

1. Mule: `mule/` をAnypoint Studioにインポート → `config.yaml`の`api.key`を設定 → CloudHub 2.0等へデプロイ
2. Salesforce:
   - Named Credential `Mule_Earthquake_API` を作成 (URL=MuleのベースURL。例 `https://xxx.cloudhub.io/api`)。`x-api-key`ヘッダにAPIキーを付与(External Credentialのカスタムヘッダ)
   - `sf project deploy start -d salesforce/force-app`
   - ユーザの権限セットに Named Credential の外部資格情報プリンシパルアクセス、Earthquake__c のFLS、Apexクラスアクセスを付与
   - 匿名Apex実行: `EarthquakeSyncJob.scheduleEvery5Min();`
3. 動作確認: `System.enqueueJob(new EarthquakeSyncJob());` → Earthquake__c に件数が入る

## GitHub → Anypoint 自動デプロイ

`.github/workflows/deploy.yml` (main push or 手動実行で CloudHub 2.0 へデプロイ)

GitHub Settings → Secrets and variables → Actions に登録:

| 種別 | 名前 | 値 |
|---|---|---|
| Secret | ANYPOINT_CLIENT_ID / ANYPOINT_CLIENT_SECRET | Connected App(client credentials)。Deploy Applications 等のスコープ |
| Secret | API_KEY | Mule `x-api-key` 用の値 (Salesforce側と同値) |
| Variable | ANYPOINT_ENV | 例 Sandbox |
| Variable | ANYPOINT_TARGET | CloudHub 2.0 の Shared/Private Space 名 |
| Variable | ANYPOINT_APP_NAME | アプリ名 (一意) |

Shared Space前提のため publicUrl は未設定(URLは自動採番)。Private Spaceで独自ドメインを使う場合は pom.xml の deploymentSettings/http/inbound/publicUrl と deploy.yml の `-Danypoint.public.url` を追加する。

## 未検証・要確認事項

- GitHub Actions/CloudHub 2.0 デプロイは未実行。`target`・`publicUrl`・Exchange認証(`~~~Client~~~`形式)は環境依存で要検証

- 本環境でMule/Salesforceへのデプロイ・実行は未実施。DataWeave/Flow XML/Apexは未コンパイル。初回デプロイ時に要確認
- pom.xmlのコネクタ/ランタイムバージョンは環境に合わせて調整
- P2PQuake APIは無償公開で、アクセス頻度に配慮が必要(5分毎100件は許容範囲想定。利用規約要確認)。負荷を下げるなら Mule側でキャッシュ、または offset差分取得に変更
- 観測点を検索・集計したい場合は子オブジェクト `Earthquake_Point__c` へ分離(現状はJSON格納)
- 本番化時: API Managerでclient id enforcement、Secure Properties、失敗時の通知(Platform Event/メール)を追加
