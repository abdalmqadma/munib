// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_day.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrayerDayAdapter extends TypeAdapter<PrayerDay> {
  @override
  final int typeId = 0;

  @override
  PrayerDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerDay(
      date: fields[0] as String,
      fajr: fields[1] as String,
      sunrise: fields[2] as String,
      dhuhr: fields[3] as String,
      asr: fields[4] as String,
      maghrib: fields[5] as String,
      isha: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerDay obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.fajr)
      ..writeByte(2)
      ..write(obj.sunrise)
      ..writeByte(3)
      ..write(obj.dhuhr)
      ..writeByte(4)
      ..write(obj.asr)
      ..writeByte(5)
      ..write(obj.maghrib)
      ..writeByte(6)
      ..write(obj.isha);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
