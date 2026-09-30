/// Weather conditions for a single hour.
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.precipitationProbability,
    required this.relativeHumidity,
    required this.windSpeed,
    required this.uvIndex,
    required this.weatherCode,
  });

  /// Local time at the forecast location (the API is called with timezone=auto).
  final DateTime time;

  /// Air temperature at 2 m, in °C.
  final double temperature;

  /// "Feels like" temperature, in °C.
  final double apparentTemperature;

  /// Chance of rain, 0–100 %.
  final int precipitationProbability;

  /// Relative humidity at 2 m, 0–100 %.
  final int relativeHumidity;

  /// Wind speed at 10 m, in km/h.
  final double windSpeed;

  /// UV index (0 at night, 11+ is extreme).
  final double uvIndex;

  /// WMO weather code (0 = clear sky, 61 = rain, 95 = thunderstorm, ...).
  final int weatherCode;
}

/// The full hourly forecast returned by Open-Meteo.
class HourlyForecast {
  const HourlyForecast({
    required this.timezone,
    required this.hours,
    this.utcOffsetSeconds,
    this.cachedAt,
  });

  /// When this forecast was originally fetched, if it was loaded from the
  /// offline cache because the network failed. `null` for fresh data.
  final DateTime? cachedAt;

  /// True when this is saved data shown because the network failed.
  bool get isFromCache => cachedAt != null;

  /// A copy of this forecast marked as loaded from the cache.
  HourlyForecast asCached(DateTime cachedAt) {
    return HourlyForecast(
      timezone: timezone,
      hours: hours,
      utcOffsetSeconds: utcOffsetSeconds,
      cachedAt: cachedAt,
    );
  }

  /// IANA timezone name of the location, e.g. "Asia/Kolkata".
  final String timezone;

  /// The location's offset from UTC, e.g. 19800 (+5:30) for India.
  /// `null` means "same as this device".
  final int? utcOffsetSeconds;

  /// The current time at the forecast location, in the same local-time form
  /// as [HourlyWeather.time], so the two can be compared directly.
  ///
  /// [deviceNow] is the phone's clock, e.g. `DateTime.now()`.
  DateTime nowAtLocation(DateTime deviceNow) {
    final offset = utcOffsetSeconds;
    if (offset == null) return deviceNow;

    final t = deviceNow.toUtc().add(Duration(seconds: offset));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  /// One entry per hour, in chronological order.
  final List<HourlyWeather> hours;

  /// Builds a forecast from the decoded Open-Meteo JSON response.
  ///
  /// Open-Meteo sends each variable as its own array, where index `i` in every
  /// array belongs to the same hour. This zips those arrays into one
  /// [HourlyWeather] per hour.
  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>;

    final times = hourly['time'] as List<dynamic>;
    final temperatures = hourly['temperature_2m'] as List<dynamic>;
    final apparentTemperatures =
        hourly['apparent_temperature'] as List<dynamic>;
    final precipitationProbabilities =
        hourly['precipitation_probability'] as List<dynamic>;
    final humidities = hourly['relative_humidity_2m'] as List<dynamic>;
    final windSpeeds = hourly['wind_speed_10m'] as List<dynamic>;
    final uvIndexes = hourly['uv_index'] as List<dynamic>;
    final weatherCodes = hourly['weather_code'] as List<dynamic>;

    final hours = <HourlyWeather>[
      for (var i = 0; i < times.length; i++)
        HourlyWeather(
          time: DateTime.parse(times[i] as String),
          temperature: (temperatures[i] as num).toDouble(),
          apparentTemperature: (apparentTemperatures[i] as num).toDouble(),
          precipitationProbability: (precipitationProbabilities[i] as num)
              .toInt(),
          relativeHumidity: (humidities[i] as num).toInt(),
          windSpeed: (windSpeeds[i] as num).toDouble(),
          uvIndex: (uvIndexes[i] as num).toDouble(),
          weatherCode: (weatherCodes[i] as num).toInt(),
        ),
    ];

    return HourlyForecast(
      timezone: json['timezone'] as String,
      hours: List.unmodifiable(hours),
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt(),
    );
  }
}
