import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  static const String apiKey = 'b5f3fc6e8095ecb49056466acb6c59da';
  
  // ========== УНИВЕРСАЛЬНЫЕ ПАРСЕРЫ ЧИСЕЛ ==========
  
  /// Принимает ЛЮБОЕ число: int, double, String и возвращает double
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  /// Принимает ЛЮБОЕ число и возвращает num (может быть int или double)
  static num _parseToNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  // ========== ОСНОВНЫЕ МЕТОДЫ ==========
  
  // Получение текущей позиции
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Включите геолокацию');
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Разрешите доступ к геолокации');
      }
    }
    
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // Поиск города по названию
  static Future<List<Map<String, dynamic>>> searchCity(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse('https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=10&appid=$apiKey&lang=ru'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        return [];
      }
      
      List data = json.decode(response.body);
      return data.map((city) => {
        'name': city['name'],
        'lat': _parseToDouble(city['lat']),
        'lon': _parseToDouble(city['lon']),
        'country': city['country'],
        'state': city['state'] ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Получение данных о погоде
  static Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки погоды');
    }
    
    Map<String, dynamic> rawData = json.decode(response.body);
    
    // НОРМАЛИЗУЕМ ВСЕ ЧИСЛА (сохраняем типы правильно)
    return _normalizeWeatherData(rawData);
  }
  
  // Получение прогноза
  static Future<Map<String, dynamic>> fetchForecast(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки прогноза');
    }
    
    Map<String, dynamic> rawData = json.decode(response.body);
    
    // НОРМАЛИЗУЕМ ДАННЫЕ ПРОГНОЗА
    if (rawData['list'] != null) {
      rawData['list'] = (rawData['list'] as List).map((item) {
        return _normalizeForecastItem(item);
      }).toList();
    }
    
    return rawData;
  }
  
  // Получение качества воздуха
  static Future<Map<String, dynamic>> fetchAirQuality(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки качества воздуха');
    }
    
    return json.decode(response.body);
  }
  
  // Получение всех данных сразу
  static Future<Map<String, dynamic>> fetchAllWeatherData(double lat, double lon) async {
    try {
      final results = await Future.wait([
        fetchWeather(lat, lon),
        fetchForecast(lat, lon),
        fetchAirQuality(lat, lon),
      ]);
      
      return {
        'weather': results[0],
        'forecast': results[1],
        'airQuality': results[2],
      };
    } catch (e) {
      rethrow;
    }
  }
  
  // Получение погоды и качества воздуха для активностей
  static Future<Map<String, dynamic>> fetchWeatherAndAirQuality(double lat, double lon) async {
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey'),
        ).timeout(const Duration(seconds: 10)),
      ]);
      
      if (results[0].statusCode != 200) {
        throw Exception('Ошибка загрузки погоды');
      }
      
      Map<String, dynamic> rawWeather = json.decode(results[0].body);
      
      return {
        'weather': _normalizeWeatherData(rawWeather),
        'airQuality': json.decode(results[1].body),
      };
    } catch (e) {
      rethrow;
    }
  }
  
  // ========== МЕТОДЫ НОРМАЛИЗАЦИИ ДАННЫХ ==========
  
  /// Преобразует числа с сохранением правильных типов
  static Map<String, dynamic> _normalizeWeatherData(Map<String, dynamic> data) {
    try {
      // Нормализуем main
      if (data['main'] != null) {
        // Температуры - всегда double
        data['main']['temp'] = _parseToDouble(data['main']['temp']);
        data['main']['feels_like'] = _parseToDouble(data['main']['feels_like']);
        data['main']['temp_min'] = _parseToDouble(data['main']['temp_min']);
        data['main']['temp_max'] = _parseToDouble(data['main']['temp_max']);
        
        // Давление и влажность - оставляем как num (int если целое, иначе double)
        data['main']['pressure'] = _parseToNum(data['main']['pressure']);
        data['main']['humidity'] = _parseToNum(data['main']['humidity']);
        
        // Уровень моря и земли - num
        if (data['main']['sea_level'] != null) {
          data['main']['sea_level'] = _parseToNum(data['main']['sea_level']);
        }
        if (data['main']['grnd_level'] != null) {
          data['main']['grnd_level'] = _parseToNum(data['main']['grnd_level']);
        }
      }
      
      // Нормализуем wind
      if (data['wind'] != null) {
        data['wind']['speed'] = _parseToDouble(data['wind']['speed']);
        data['wind']['deg'] = _parseToNum(data['wind']['deg']);
        data['wind']['gust'] = data['wind']['gust'] != null 
            ? _parseToDouble(data['wind']['gust']) 
            : null;
      }
      
      // Нормализуем координаты
      if (data['coord'] != null) {
        data['coord']['lat'] = _parseToDouble(data['coord']['lat']);
        data['coord']['lon'] = _parseToDouble(data['coord']['lon']);
      }
      
      // Нормализуем видимость
      if (data['visibility'] != null) {
        data['visibility'] = _parseToNum(data['visibility']);
      }
      
      // Нормализуем облачность
      if (data['clouds'] != null && data['clouds']['all'] != null) {
        data['clouds']['all'] = _parseToNum(data['clouds']['all']);
      }
      
      // Нормализуем время
      if (data['dt'] != null) {
        data['dt'] = _parseToNum(data['dt']);
      }
      if (data['timezone'] != null) {
        data['timezone'] = _parseToNum(data['timezone']);
      }
      if (data['id'] != null) {
        data['id'] = _parseToNum(data['id']);
      }
      if (data['cod'] != null) {
        // cod может быть строкой или числом
        data['cod'] = data['cod'] is String 
            ? int.tryParse(data['cod']) ?? 200 
            : _parseToNum(data['cod']);
      }
      
      return data;
    } catch (e) {
      return data;
    }
  }
  
  /// Нормализует один элемент прогноза
  static Map<String, dynamic> _normalizeForecastItem(Map<String, dynamic> item) {
    try {
      // Нормализуем main
      if (item['main'] != null) {
        // Температуры - double
        item['main']['temp'] = _parseToDouble(item['main']['temp']);
        item['main']['feels_like'] = _parseToDouble(item['main']['feels_like']);
        item['main']['temp_min'] = _parseToDouble(item['main']['temp_min']);
        item['main']['temp_max'] = _parseToDouble(item['main']['temp_max']);
        
        // Давление и влажность - num
        item['main']['pressure'] = _parseToNum(item['main']['pressure']);
        item['main']['humidity'] = _parseToNum(item['main']['humidity']);
        
        if (item['main']['sea_level'] != null) {
          item['main']['sea_level'] = _parseToNum(item['main']['sea_level']);
        }
        if (item['main']['grnd_level'] != null) {
          item['main']['grnd_level'] = _parseToNum(item['main']['grnd_level']);
        }
      }
      
      // Нормализуем wind
      if (item['wind'] != null) {
        item['wind']['speed'] = _parseToDouble(item['wind']['speed']);
        item['wind']['deg'] = _parseToNum(item['wind']['deg']);
        if (item['wind']['gust'] != null) {
          item['wind']['gust'] = _parseToDouble(item['wind']['gust']);
        }
      }
      
      // Нормализуем облачность
      if (item['clouds'] != null && item['clouds']['all'] != null) {
        item['clouds']['all'] = _parseToNum(item['clouds']['all']);
      }
      
      // Нормализуем видимость
      if (item['visibility'] != null) {
        item['visibility'] = _parseToNum(item['visibility']);
      }
      
      // Нормализуем вероятность осадков
      if (item['pop'] != null) {
        item['pop'] = _parseToDouble(item['pop']);
      }
      
      // Нормализуем время
      if (item['dt'] != null) {
        item['dt'] = _parseToNum(item['dt']);
      }
      
      return item;
    } catch (e) {
      return item;
    }
  }
}

// ========== РАСШИРЕНИЕ ДЛЯ УДОБНОЙ РАБОТЫ С ДАННЫМИ ==========

/// Расширение для безопасного извлечения чисел из Map
extension SafeNumberParse on Map<String, dynamic> {
  /// Получить double (всегда возвращает double)
  double getDouble(String key) {
    final value = this[key];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  /// Получить int (всегда возвращает int)
  int getInt(String key) {
    final value = this[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  /// Получить num (может быть int или double)
  num getNum(String key) {
    final value = this[key];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  /// Получить температуру в виде строки с градусом
  String getTempString(String key) {
    return '${getDouble(key).round()}°';
  }
  
  /// Получить процент в виде строки
  String getPercentString(String key) {
    return '${getNum(key)}%';
  }
}

// ========== МОДЕЛЬ ДАННЫХ ПОГОДЫ (ДЛЯ БЕЗОПАСНОГО ДОСТУПА) ==========

/// Безопасная модель данных погоды
class WeatherData {
  final Map<String, dynamic> raw;
  
  WeatherData(this.raw);
  
  // Вспомогательные методы для приведения типов
  Map<String, dynamic>? _getMap(String key) {
    final value = raw[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
  
  // Температура
  double get temp {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get feelsLike {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['feels_like'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get tempMin {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp_min'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get tempMax {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp_max'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  // Влажность и давление (num - могут быть int или double)
  num get humidity {
    final main = _getMap('main');
    if (main == null) return 0;
    final value = main['humidity'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  num get pressure {
    final main = _getMap('main');
    if (main == null) return 0;
    final value = main['pressure'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  // Ветер
  double get windSpeed {
    final wind = _getMap('wind');
    if (wind == null) return 0.0;
    final value = wind['speed'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  num get windDeg {
    final wind = _getMap('wind');
    if (wind == null) return 0;
    final value = wind['deg'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  // Облачность
  num get clouds {
    final clouds = _getMap('clouds');
    if (clouds == null) return 0;
    final value = clouds['all'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  // Видимость
  num get visibility {
    final value = raw['visibility'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  // Описание погоды
  String get description {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['description'] ?? '';
    }
    return '';
  }
  
  String get icon {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['icon'] ?? '';
    }
    return '';
  }
  
  String get main {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['main'] ?? '';
    }
    return '';
  }
  
  // Город
  String get cityName => raw['name'] ?? '';
  
  // Отформатированные строки для UI
  String get tempString => '${temp.round()}°';
  String get feelsLikeString => 'Ощущается как ${feelsLike.round()}°';
  String get humidityString => '$humidity%';
  String get pressureString => '$pressure мм рт. ст.';
  String get windSpeedString => '${windSpeed.toStringAsFixed(1)} м/с';
  String get cloudsString => '$clouds%';
  String get visibilityString => '${(visibility.toDouble() / 1000).toStringAsFixed(1)} км';
}