# MUnit テスト (現行 main 構成: x-api-key 版)

対象フロー: `get-earthquakes-flow` (`mule/src/main/mule/earthquake-api.xml`)

## 追加ファイル
- `mule/src/test/munit/earthquake-api-test.xml` — テスト本体 (6 件)
- `mule/src/test/resources/p2pquake-sample.json` — P2PQuake のモック応答

## テスト一覧

| テスト名 | 検証内容 |
|---|---|
| normalizes-upstream-response | 日時が ISO8601(+09:00)、震度コード→ラベル(20→"2")、-1→null、ポイント配列の引継ぎ |
| limit-defaults-to-100 | limit 未指定で 100 |
| limit-is-capped-at-100 | limit=500 → 100 |
| limit-is-passed-through | limit=5 → 5 |
| upstream-connectivity-error-returns-502 | HTTP:CONNECTIVITY 時に httpStatus=502、メッセージ "Upstream P2PQuake error" |
| upstream-500-error-returns-502 | 上流 500 (HTTP:INTERNAL_SERVER_ERROR) も 502 に変換 |

P2PQuake への HTTP 呼び出しは `mock-when processor="http:request"` でモック化しており、外部通信は行わない。
`x-api-key` は `config.yaml` の `api.key` (`p('api.key')`) を使うため、キーの値に依存しない。

## pom.xml への追加 (main の `mule/pom.xml`)

`<dependencies>` 内に追加:
```xml
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-runner</artifactId>
    <version>3.2.1</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-tools</artifactId>
    <version>3.2.1</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>
```

`<build><plugins>` 内に追加:
```xml
<plugin>
    <groupId>com.mulesoft.munit.tools</groupId>
    <artifactId>munit-maven-plugin</artifactId>
    <version>3.2.1</version>
    <executions>
        <execution>
            <id>test</id>
            <phase>test</phase>
            <goals>
                <goal>test</goal>
                <goal>coverage-report</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <coverage>
            <runCoverage>true</runCoverage>
            <formats>
                <format>html</format>
            </formats>
        </coverage>
    </configuration>
</plugin>
```

## 実行方法
- Anypoint Studio / Code Builder: テストファイルを右クリック → Run MUnit suite (推奨。EE ランタイムは Studio が保持)
- Maven: `cd earthquake-sync/mule && mvn clean test`
  - 結果: `target/munit-reports/`、カバレッジ: `target/site/munit/coverage/`
- 注意: 現行の `deploy.yml` は `-DskipTests` を付けているため、CI では MUnit は実行されない (意図的)

## 未検証・要確認
- 本環境で MUnit は未実行。MUnit 3.2.1 は Mule 4.6.x 向けの想定 (版は要確認。ランタイムを変える場合は MUnit も合わせる)
- Maven 経由の実行には、Mule EE 実行環境 (`ee:transform` を使うため) の取得に MuleSoft の Nexus 認証が必要になる場合がある。CI で実行する場合は `settings.xml` に認証情報が必要
- `upstream-*` のテストは、`on-error-propagate` が変更したペイロード/変数を呼び出し元が参照できる前提 (Mule 4 の標準動作)
- 日時・数値の比較は `as String` で型差を避けている。失敗時は、実際のペイロードをログ出力して期待値を調整する

## APIkit 移行後 (`apikit-apimanager` ブランチ) の場合
- フロー名が `get:\earthquakes:earthquake-api-config` に変わり、`x-api-key` の照合がなくなる
- テストの `flow-ref name` を新フロー名に変更し、`set-event` の `x-api-key` を削除する
- 上流障害の期待値は同じ (httpStatus=502)
