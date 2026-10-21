/**
 * Schedulable(定期起動) → EarthquakeSyncJob(Queueable) を投入。
 * 登録(5分毎):
 *   EarthquakeSyncScheduler.scheduleEvery5Min();
 */
public with sharing class EarthquakeSyncScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        System.enqueueJob(new EarthquakeSyncJob());
    }

    public static void scheduleEvery5Min() {
        for (Integer m = 0; m < 60; m += 5) {
            System.schedule('EarthquakeSync_' + String.valueOf(m).leftPad(2, '0'),
                '0 ' + m + ' * * * ?', new EarthquakeSyncScheduler());
        }
    }
}
