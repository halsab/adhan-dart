import 'package:adhan/adhan.dart';
import 'package:adhan/src/data/calendar_util.dart';
import 'package:test/test.dart';

void main() {
  test('leap year and UTC date resolution', () {
    expect(CalendarUtil.isLeapYear(2000), isTrue);
    expect(CalendarUtil.isLeapYear(1900), isFalse);
    expect(CalendarUtil.resolveTimeByDateComponents(DateComponents(2020, 1, 1)),
        DateTime.utc(2020, 1, 1));
  });

  test('round nearest, ceiling, none, rollover, pre-epoch', () {
    final exact = DateTime.utc(2026, 1, 1, 12, 0);
    expect(CalendarUtil.roundedMinute(exact, Rounding.up), exact);
    expect(CalendarUtil.roundedMinute(exact.add(const Duration(seconds: 29))), exact);
    expect(CalendarUtil.roundedMinute(exact.add(const Duration(seconds: 30))),
        exact.add(const Duration(minutes: 1)));
    final seconds = exact.add(const Duration(seconds: 1));
    expect(CalendarUtil.roundedMinute(seconds, Rounding.none), seconds);
    expect(CalendarUtil.roundedMinute(seconds, Rounding.up),
        exact.add(const Duration(minutes: 1)));
    expect(CalendarUtil.roundedMinute(DateTime.utc(2026, 1, 1, 23, 59, 59)),
        DateTime.utc(2026, 1, 2));
    expect(CalendarUtil.roundedMinute(DateTime.utc(1969, 12, 31, 23, 59, 30)),
        DateTime.utc(1970));
  });
}
