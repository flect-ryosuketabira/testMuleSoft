@IsTest
private class EarthquakeSyncTest {

    private class MockOk implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"id":"eq1","occurredAt":"2026-10-13T11:27:00+09:00",'
                + '"issuedAt":"2026-10-13T11:31:53+09:00","hypocenterName":"熊本県天草・芦北地方",'
                + '"latitude":32.3,"longitude":130.5,"depthKm":0,"magnitude":3.5,'
                + '"maxScale":20,"maxScaleLabel":"2","domesticTsunami":"None",'
                + '"foreignTsunami":"Unknown","issueType":"DetailScale","issueSource":"気象庁",'
                + '"correct":"None","comment":"",'
                + '"points":[{"pref":"熊本県","addr":"八代市平山新町","scale":20}]}]');
            return res;
        }
    }

    private class MockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(502);
            res.setBody('{"message":"bad gateway"}');
            return res;
        }
    }

    @IsTest
    static void upsertIsIdempotent() {
        Test.setMock(HttpCalloutMock.class, new MockOk());
        Test.startTest();
        EarthquakeSyncService.sync(10);
        EarthquakeSyncService.sync(10);
        Test.stopTest();
        List<Earthquake__c> rows = [SELECT P2PQuake_Id__c, Magnitude__c, Max_Intensity__c FROM Earthquake__c];
        System.assertEquals(1, rows.size());
        System.assertEquals('eq1', rows[0].P2PQuake_Id__c);
        System.assertEquals(3.5, rows[0].Magnitude__c);
        System.assertEquals('2', rows[0].Max_Intensity__c);
    }

    @IsTest
    static void apiErrorThrows() {
        Test.setMock(HttpCalloutMock.class, new MockError());
        try {
            Test.startTest();
            EarthquakeSyncService.sync(10);
            Test.stopTest();
            System.assert(false, 'exception expected');
        } catch (EarthquakeApiClient.ApiException e) {
            System.assert(e.getMessage().contains('502'));
        }
    }

    @IsTest
    static void jobRuns() {
        Test.setMock(HttpCalloutMock.class, new MockOk());
        Test.startTest();
        System.enqueueJob(new EarthquakeSyncJob());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Earthquake__c]);
    }
}
