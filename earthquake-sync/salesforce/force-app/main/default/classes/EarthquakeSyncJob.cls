/**
 * Queueable(コールアウト実行)。
 * Schedulable とは同時に実装できないため、定期起動は EarthquakeSyncScheduler に分離。
 * 手動実行:
 *   System.enqueueJob(new EarthquakeSyncJob());
 */
public with sharing class EarthquakeSyncJob implements Queueable, Database.AllowsCallouts {

    public static final Integer FETCH_LIMIT = 100;

    public void execute(QueueableContext qc) {
        Integer n = EarthquakeSyncService.sync(FETCH_LIMIT);
        System.debug('Earthquake upserted: ' + n);
    }
}
