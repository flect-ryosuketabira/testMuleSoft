/**
 * Schedulable(定期起動) → Queueable(コールアウト実行)。
 * 登録例(5分毎):
 *   EarthquakeSyncJob.scheduleEvery5Min();
 * 手動実行:
 *   System.enqueueJob(new EarthquakeSyncJob());
 */
public with sharing class EarthquakeSyncJob implements Schedulable, Queueable, Database.AllowsCallouts {

    private static final Integer FETCH_LIMIT = 100;

    public void execute(SchedulableContext sc) {
        System.enqueueJob(new EarthquakeSyncJob());
    }

    public void execute(QueueableContext qc) {
        Integer n = EarthquakeSyncService.sync(FETCH_LIMIT);
        System.debug('Earthquake upserted: ' + n);
    }

    public static void scheduleEvery5Min() {
        for (Integer m = 0; m < 60; m += 5) {
            System.schedule('EarthquakeSync_' + String.valueOf(m).leftPad(2, '0'),
                '0 ' + m + ' * * * ?', new EarthquakeSyncJob());
        }
    }
}
