import 'package:flutter/material.dart';

/// Система генерации советов на основе погодных данных
/// Анализирует текущую погоду, прогноз и время суток
class TipsSystem {
  
  /// Главный метод анализа погоды и генерации совета
  /// ПРИОРИТЕТЫ: рассвет > закат > снег > дождь > обычная погода
  Map<String, dynamic>? analyzeWeatherForTips(
    Map<String, dynamic>? weatherData, 
    Map<String, dynamic>? forecastData
  ) {
    if (weatherData == null) return null;
    
    final now = DateTime.now();
    final sunrise = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunrise'] * 1000);
    final sunset = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunset'] * 1000);
    
    final timeToSunrise = sunrise.difference(now).inHours;
    final timeToSunset = sunset.difference(now).inHours;
    
    // ПРИОРИТЕТ №1: Рассвет через час
    if (timeToSunrise >= 0 && timeToSunrise < 1) {
      return _createSunriseTip(sunrise);
    }
    
    // ПРИОРИТЕТ №2: Закат через час
    if (timeToSunset >= 0 && timeToSunset < 1) {
      return _createSunsetTip(sunset);
    }
    
    // Получаем прогноз на следующий час
    final nextHourData = _getWeatherForNextHour(forecastData);
    
    // ПРИОРИТЕТ №3: Снег в ближайший час
    if (nextHourData != null && _willSnowInNextHour(nextHourData)) {
      return _createSnowTip();
    }
    
    // ПРИОРИТЕТ №4: Дождь в ближайший час
    if (nextHourData != null && _willRainInNextHour(nextHourData)) {
      return _createRainTip(nextHourData);
    }
    
    // ПРИОРИТЕТ №5: Обычный совет по текущей погоде (с учётом времени суток)
    return _createWeatherTip(weatherData);
  }
  
  /// Получение данных о погоде на следующий час
  Map<String, dynamic>? _getWeatherForNextHour(Map<String, dynamic>? forecastData) {
    if (forecastData == null) return null;
    
    final now = DateTime.now();
    final nextHour = now.add(const Duration(hours: 1));
    
    Map<String, dynamic>? closestForecast;
    Duration smallestDiff = const Duration(days: 365);
    
    for (var item in forecastData['list']) {
      final forecastTime = DateTime.parse(item['dt_txt']);
      final diff = forecastTime.difference(nextHour).abs();
      
      if (diff < smallestDiff && diff <= const Duration(minutes: 90)) {
        smallestDiff = diff;
        closestForecast = item;
      }
    }
    
    return closestForecast;
  }
  
  bool _willSnowInNextHour(Map<String, dynamic> hourData) {
    final weather = hourData['weather'][0]['main'].toString().toLowerCase();
    final description = hourData['weather'][0]['description'].toString().toLowerCase();
    
    return weather.contains('snow') || 
           description.contains('снег') ||
           (hourData['main']['temp'] <= 2 && weather.contains('rain'));
  }
  
  bool _willRainInNextHour(Map<String, dynamic> hourData) {
    final weather = hourData['weather'][0]['main'].toString().toLowerCase();
    final pop = hourData['pop'] ?? 0;
    
    return weather.contains('rain') || 
           weather.contains('drizzle') ||
           pop > 0.3;
  }
  
  /// Вспомогательный метод для определения времени суток
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour <= 4) return 'night';
    if (hour >= 5 && hour <= 10) return 'morning';
    if (hour >= 11 && hour <= 16) return 'day';
    return 'evening';
  }
  
  Map<String, dynamic> _createSnowTip() {
    final messages = [
      "Скоро пойдет снег. Или он уже идёт.",
      "Одевайтесь теплее.",
      "На дорогах может быть скользко, будьте осторожны!"
    ];
    
    return {
      'type': 'snow',
      'title': 'Ожидается снегопад',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createRainTip(Map<String, dynamic> hourData) {
    final pop = (hourData['pop'] ?? 0.5) * 100;
    
    final messages = [
      "Не забудьте зонт.",
      "Лучше надеть непромокаемую обувь.",
      "Будьте аккуратны на дороге."
    ];
    
    final intensity = pop > 70 ? "сильный" : (pop > 40 ? "умеренный" : "небольшой");
    
    return {
      'type': 'rain',
      'title': 'Возможен $intensity дождь',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Вероятность: ${pop.round()}%',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSunriseTip(DateTime sunrise) {
    final messages = [
      "Скоро светает.",
      "Можно встретить новый день с чашкой кофе.",
      "Отличное время чтобы проснуться."
    ];
    
    return {
      'type': 'sunrise',
      'title': 'Рассвет уже здесь',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'В ${_formatTime(sunrise)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createSunsetTip(DateTime sunset) {
    final messages = [
      "Скоро стемнеет.",
      "Самое время для прогулки.",
      "Вечер обещает быть красивым."
    ];
    
    return {
      'type': 'sunset',
      'title': 'Закат через час',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'В ${_formatTime(sunset)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  /// Маршрутизация советов по погоде с учётом времени суток и температуры
  Map<String, dynamic> _createWeatherTip(Map<String, dynamic> weatherData) {
    final weatherMain = weatherData['weather'][0]['main'].toLowerCase();
    final temp = weatherData['main']['temp'].round();
    final feelsLike = weatherData['main']['feels_like'].round();
    final humidity = weatherData['main']['humidity'].toDouble();
    final timeOfDay = _getTimeOfDay();
    
    // Ночные советы (23:00 - 4:00)
    if (timeOfDay == 'night') {
      return _createNightTip(temp, weatherMain);
    }
    
    // Утренние советы (5:00 - 10:00)
    if (timeOfDay == 'morning') {
      return _createMorningTip(temp, humidity, weatherMain);
    }
    
    // Дневные/вечерние советы по погоде
    switch(weatherMain) {
      case 'clear':
        return _createClearSkyTip(temp, feelsLike);
      case 'clouds':
        return _createCloudsTip(temp);
      case 'rain':
        return _createRainyTip();
      case 'snow':
        return _createSnowyTip(temp);
      case 'thunderstorm':
        return _createThunderstormTip();
      case 'drizzle':
        return _createDrizzleTip();
      case 'mist':
      case 'fog':
      case 'haze':
        return _createFoggyTip();
      default:
        return _createDefaultTip();
    }
  }
  
  /// Ночной совет (с учётом температуры)
  Map<String, dynamic> _createNightTip(int temp, String weatherMain) {
    final messages = [
      "Время спать, проветрите комнату.",
      "Спокойной ночи. Температура $temp°C.",
      "На улице $temp°C. Лучше оставаться в тепле."
    ];
    
    // Если очень холодно
    if (temp <= 0) {
      return {
        'type': 'night',
        'title': 'Холодная ночь',
        'message': 'На улице $temp°C. Проветрите комнату за 30 минут до сна.',
        'time': '$temp°C',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.nightlight_round,
      };
    }
    
    return {
      'type': 'night',
      'title': 'Время спать',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  /// Утренний совет (с учётом температуры и влажности)
  Map<String, dynamic> _createMorningTip(int temp, double humidity, String weatherMain) {
    // Если холодно
    if (temp <= 5) {
      return {
        'type': 'morning',
        'title': 'Свежее утро',
        'message': 'На улице $temp°C. Проветрите, но не надолго.',
        'time': '$temp°C',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    // Если комфортная температура
    final messages = [
      "Приоткройте окно, на улице свежо.",
      "Хорошее утро для проветривания.",
      "На улице $temp°C, можно подышать свежим воздухом."
    ];
    
    // Если высокая влажность
    if (humidity > 70) {
      return {
        'type': 'morning',
        'title': 'Влажное утро',
        'message': 'На улице $temp°C. Влажность ${humidity.round()}%, проветрите.',
        'time': '${humidity.round()}%',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    return {
      'type': 'morning',
      'title': 'Доброе утро',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createClearSkyTip(int temp, int feelsLike) {
    final messages = [
      "Хорошая погода для прогулки.",
      "Можно проветрить квартиру.",
      "Солнечный день."
    ];
    
    return {
      'type': 'clear',
      'title': 'Ясная погода',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Ощущается как $feelsLike°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createCloudsTip(int temp) {
    final messages = [
      "Облачно, но без осадков.",
      "На улице серо.",
      "Можно выйти подышать."
    ];
    
    return {
      'type': 'clouds',
      'title': 'Облачная погода',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Температура $temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.cloud,
    };
  }
  
  Map<String, dynamic> _createRainyTip() {
    final messages = [
      "Идет дождь.",
      "Окна лучше закрыть.",
      "На улице мокро."
    ];
    
    return {
      'type': 'rain',
      'title': 'Дождливая погода',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Осадки ожидаются',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSnowyTip(int temp) {
    final messages = [
      "Снежно.",
      "Одевайтесь теплее.",
      "Коммунальные службы уже работают."
    ];
    
    return {
      'type': 'snow',
      'title': 'Снежная погода',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Температура $temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createThunderstormTip() {
    final messages = [
      "Гроза. Лучше быть дома.",
      "Отключите технику от розеток.",
      "Не стойте под деревьями."
    ];
    
    return {
      'type': 'thunderstorm',
      'title': 'Гроза',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Будьте осторожны',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.flash_on,
    };
  }
  
  Map<String, dynamic> _createDrizzleTip() {
    final messages = [
      "Моросит.",
      "Зонт брать не обязательно.",
      "Влажность повышена."
    ];
    
    return {
      'type': 'drizzle',
      'title': 'Морось',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Небольшие осадки',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.grain,
    };
  }
  
  Map<String, dynamic> _createFoggyTip() {
    final messages = [
      "Туманно.",
      "Снизьте скорость на дороге.",
      "Видимость плохая."
    ];
    
    return {
      'type': 'fog',
      'title': 'Туман',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Плохая видимость',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.foggy,
    };
  }
  
  Map<String, dynamic> _createDefaultTip() {
    final messages = [
      "Погода не помеха хорошему настроению.",
      "Одевайтесь по погоде.",
      "Следите за прогнозом."
    ];
    
    return {
      'type': 'default',
      'title': 'Совет дня',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Хорошего дня',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.coffee,
    };
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}