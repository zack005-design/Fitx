import 'package:equatable/equatable.dart';

class VitalsData extends Equatable {
  final DateTime date;
  final List<String> readErrors;
  final double? restingHeartRate; // bpm
  final double? hrv; // ms (SDNN)
  final double? spo2; // %
  final double? respiratoryRate; // breaths/min
  final List<HeartRateSample> heartRateSamples;

  const VitalsData({
    required this.date,
    this.readErrors = const [],
    this.restingHeartRate,
    this.hrv,
    this.spo2,
    this.respiratoryRate,
    required this.heartRateSamples,
  });

  factory VitalsData.empty(DateTime date) => VitalsData(
        date: date,
        heartRateSamples: [],
      );

  @override
  List<Object?> get props => [date, restingHeartRate, hrv];
}

class HeartRateSample extends Equatable {
  final DateTime time;
  final double bpm;

  const HeartRateSample({required this.time, required this.bpm});

  @override
  List<Object?> get props => [time, bpm];
}
