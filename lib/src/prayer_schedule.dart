import 'prayer.dart';
import 'prayer_times.dart';
import 'sunnah_times.dart';

/// Optional timeline adapter inspired by Salah. Night milestones are separate
/// from the obligatory-prayer enum and are sorted by their actual UTC instants.
enum ScheduleEventKind { fajr, sunrise, dhuhr, asr, sunset, maghrib, isha,
  middleOfNight, lastThirdOfNight, nextFajr }

typedef ScheduleEvent = ({ScheduleEventKind kind, DateTime time});

final class PrayerSchedule {
  final PrayerTimes prayers;
  final SunnahTimes? sunnahTimes;
  final List<ScheduleEvent> events;

  PrayerSchedule._(this.prayers, this.sunnahTimes, this.events);

  factory PrayerSchedule(PrayerTimes prayers) {
    final night = SunnahTimes.tryCalculate(prayers);
    final events = <ScheduleEvent>[
      (kind: ScheduleEventKind.fajr, time: prayers.fajr),
      (kind: ScheduleEventKind.sunrise, time: prayers.sunrise),
      (kind: ScheduleEventKind.dhuhr, time: prayers.dhuhr),
      (kind: ScheduleEventKind.asr, time: prayers.asr),
      (kind: ScheduleEventKind.sunset, time: prayers.sunset),
      (kind: ScheduleEventKind.maghrib, time: prayers.maghrib),
      (kind: ScheduleEventKind.isha, time: prayers.isha),
      if (night != null) ...[
        (kind: ScheduleEventKind.middleOfNight, time: night.middleOfTheNight),
        (kind: ScheduleEventKind.lastThirdOfNight, time: night.lastThirdOfTheNight),
        (kind: ScheduleEventKind.nextFajr, time: night.fajrTomorrow),
      ],
    ]..sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.kind.index.compareTo(b.kind.index);
    });
    return PrayerSchedule._(prayers, night, List.unmodifiable(events));
  }

  ScheduleEvent? nextEvent(DateTime now) {
    for (final event in events) {
      if (event.time.isAfter(now)) return event;
    }
    return null;
  }

  /// Remains distinct from optional events such as night milestones.
  Prayer currentPrayer(DateTime now) {
    final night = sunnahTimes;
    if (night != null && !now.isBefore(night.fajrTomorrow)) {
      return now.isAtSameMomentAs(night.fajrTomorrow) ? Prayer.fajr : Prayer.none;
    }
    return prayers.currentPrayer(now);
  }
}
