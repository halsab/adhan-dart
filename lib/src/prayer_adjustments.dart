/// Immutable per-event offsets in minutes.
final class PrayerAdjustments {
  final int fajr, sunrise, dhuhr, asr, maghrib, isha;

  const PrayerAdjustments({
    this.fajr = 0, this.sunrise = 0, this.dhuhr = 0,
    this.asr = 0, this.maghrib = 0, this.isha = 0,
  });

  PrayerAdjustments copyWith({
    int? fajr, int? sunrise, int? dhuhr, int? asr, int? maghrib, int? isha,
  }) => PrayerAdjustments(
    fajr: fajr ?? this.fajr, sunrise: sunrise ?? this.sunrise,
    dhuhr: dhuhr ?? this.dhuhr, asr: asr ?? this.asr,
    maghrib: maghrib ?? this.maghrib, isha: isha ?? this.isha,
  );
}
