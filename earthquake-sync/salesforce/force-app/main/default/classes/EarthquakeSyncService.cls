/**
 * 地震情報を取得し Earthquake__c へ upsert (外部ID: P2PQuake_Id__c)。冪等。
 */
public with sharing class EarthquakeSyncService {

    public static Integer sync(Integer maxCount) {
        List<EarthquakeApiClient.EarthquakeDto> dtos = EarthquakeApiClient.fetch(maxCount);
        List<Earthquake__c> records = new List<Earthquake__c>();
        for (EarthquakeApiClient.EarthquakeDto d : dtos) {
            records.add(toRecord(d));
        }
        if (records.isEmpty()) {
            return 0;
        }
        Database.UpsertResult[] results =
            Database.upsert(records, Earthquake__c.P2PQuake_Id__c, false);
        Integer ok = 0;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                ok++;
            } else {
                System.debug(LoggingLevel.ERROR, 'upsert failed id=' + records[i].P2PQuake_Id__c
                    + ' ' + results[i].getErrors());
            }
        }
        return ok;
    }

    @TestVisible
    private static Earthquake__c toRecord(EarthquakeApiClient.EarthquakeDto d) {
        return new Earthquake__c(
            P2PQuake_Id__c      = d.id,
            Occurred_At__c      = d.occurredAt,
            Issued_At__c        = d.issuedAt,
            Hypocenter_Name__c  = d.hypocenterName,
            Latitude__c         = d.latitude,
            Longitude__c        = d.longitude,
            Depth_Km__c         = d.depthKm,
            Magnitude__c        = d.magnitude,
            Max_Scale_Code__c   = d.maxScale,
            Max_Intensity__c    = d.maxScaleLabel,
            Domestic_Tsunami__c = d.domesticTsunami,
            Foreign_Tsunami__c  = d.foreignTsunami,
            Issue_Type__c       = d.issueType,
            Issue_Source__c     = d.issueSource,
            Correct__c          = d.correct,
            Comment__c          = d.comment,
            Points_JSON__c      = d.points == null ? null : JSON.serialize(d.points)
        );
    }
}
