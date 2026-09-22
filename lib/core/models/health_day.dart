/// Local calendar days, including across daylight-saving transitions.
DateTime healthDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime shiftHealthDay(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
String healthDayKey(DateTime date) =>
    healthDay(date).toIso8601String().substring(0, 10);
