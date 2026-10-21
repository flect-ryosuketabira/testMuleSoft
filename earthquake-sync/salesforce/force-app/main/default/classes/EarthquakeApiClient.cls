/**
 * MuleSoft経由で地震情報を取得するクライアント。
 * Named Credential: MuleEarthquakeAPI(URL=MuleのベースURL, x-api-keyヘッダ付与)
 */
public with sharing class EarthquakeApiClient {

    public class EarthquakeDto {
        public String id;
        public Datetime occurredAt;
        public Datetime issuedAt;
        public String hypocenterName;
        public Decimal latitude;
        public Decimal longitude;
        public Decimal depthKm;
        public Decimal magnitude;
        public Integer maxScale;
        public String maxScaleLabel;
        public String domesticTsunami;
        public String foreignTsunami;
        public String issueType;
        public String issueSource;
        public String correct;
        public String comment;
        public List<PointDto> points;
    }

    // JSON.deserialize は Object 型を扱えないため、型付きクラスで受ける
    public class PointDto {
        public String pref;
        public String addr;
        public Boolean isArea;
        public Integer scale;
    }

    public class ApiException extends Exception {}

    public static List<EarthquakeDto> fetch(Integer maxCount) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:MuleEarthquakeAPI/earthquakes?limit=' + maxCount);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ApiException('Mule API error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (List<EarthquakeDto>) JSON.deserialize(res.getBody(), List<EarthquakeDto>.class);
    }
}
