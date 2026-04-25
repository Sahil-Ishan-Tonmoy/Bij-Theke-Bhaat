import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _isLoading = true;
  String _cityName = 'Locating Region...';
  
  Map<String, dynamic>? _currentWeather;
  Map<String, dynamic>? _dailyForecast;
  
  @override
  void initState() {
    super.initState();
    _cityName = AppSettings.instance.translate('locating');
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    final s = AppSettings.instance;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setErrorState(s.isBengali ? 'জিপিএস বন্ধ। লোকেশন চালু করুন।' : 'GPS Disabled. Please turn on Location.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setErrorState(s.isBengali ? 'লোকেশন পারমিশন পাওয়া যায়নি।' : 'Location Permission Denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _setErrorState(s.isBengali ? 'লোকেশন পারমিশন স্থায়ীভাবে বন্ধ।' : 'Location Permissions Permanently Denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      try {
        final geoRes = await http.get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en'));
        if (geoRes.statusCode == 200) {
           final geoData = json.decode(geoRes.body);
           _cityName = geoData['city'] ?? geoData['locality'] ?? geoData['principalSubdivision'] ?? (s.isBengali ? 'অজানা অঞ্চল' : 'Unknown District');
        } else {
           _cityName = s.isBengali ? 'অজানা অবস্থান' : 'Unknown Field Location';
        }
      } catch (_) {
        _cityName = s.isBengali ? 'জিপিএস মোড' : 'GPS Coordinate Mode';
      }

      final weatherRes = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto'
      ));

      if (weatherRes.statusCode == 200) {
        final data = json.decode(weatherRes.body);
        final current = data['current'] as Map<String, dynamic>?;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && current != null) {
          final code = current['weather_code'];
          final temp = current['temperature_2m'];
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'lastWeatherCode': code is int ? code : (code as num?)?.toInt(),
            'lastTemperature': (temp as num?)?.toDouble(),
            'lastWeatherCity': _cityName,
            'lastWeatherFetched': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (mounted) {
          setState(() {
            _currentWeather = current;
            _dailyForecast = data['daily'];
            _isLoading = false;
          });
        }
      } else {
        _setErrorState(s.isBengali ? 'সার্ভারের সাথে সংযোগ ব্যর্থ।' : 'Failed to ping Weather Satellite.');
      }
    } catch (e) {
      _setErrorState('Network Exception: $e');
    }
  }

  void _setErrorState(String message) {
    if (mounted) {
      setState(() {
        _cityName = message;
        _isLoading = false;
      });
    }
  }

  String _getWeatherVisual(int? code) {
    if (code == null) return '☁️';
    if (code == 0) return '☀️'; 
    if (code >= 1 && code <= 3) return '⛅'; 
    if (code >= 51 && code <= 67) return '🌧️'; 
    if (code >= 71 && code <= 82) return '☔'; 
    if (code >= 95) return '⛈️'; 
    return '☁️'; 
  }

  String _getWeatherDesc(int? code) {
    final s = AppSettings.instance;
    if (code == null) return s.isBengali ? 'অজানা' : 'Unknown';
    if (code == 0) return s.translate('clear_sky');
    if (code >= 1 && code <= 3) return s.translate('partly_cloudy');
    if (code >= 51 && code <= 67) return s.translate('light_rain');
    if (code >= 71 && code <= 82) return s.translate('heavy_shower');
    if (code >= 95) return s.translate('thunderstorm_warning');
    return s.translate('overcast');
  }

  Widget _buildGlassBox({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  List<Widget> _build7DayForecastRows() {
    if (_dailyForecast == null) return [];
    final s = AppSettings.instance;
    
    List<Widget> rows = [];
    final timeRaw = _dailyForecast!['time'] as List;
    final maxTemp = _dailyForecast!['temperature_2m_max'] as List;
    final minTemp = _dailyForecast!['temperature_2m_min'] as List;
    final wCodes = _dailyForecast!['weather_code'] as List;
    final prep = _dailyForecast!['precipitation_sum'] as List;

    for (int i = 0; i < timeRaw.length; i++) {
       DateTime date = DateTime.parse(timeRaw[i]);
       String dayName = (i == 0) ? s.translate('today') : (i == 1) ? s.translate('tomorrow') : DateFormat('EEEE').format(date);
       
       rows.add(
         Padding(
           padding: const EdgeInsets.symmetric(vertical: 8.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Expanded(
                 flex: 3,
                 child: TranslateText(dayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryText)),
               ),
               Expanded(
                 flex: 2,
                 child: Row(
                   children: [
                     Text(_getWeatherVisual(wCodes[i]), style: const TextStyle(fontSize: 22)),
                     const SizedBox(width: 8),
                     Text('${s.translatePrice(prep[i].toString())}mm', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                   ],
                 ),
               ),
               Expanded(
                 flex: 2,
                 child: Text('${s.translatePrice(maxTemp[i].round().toString())}° / ${s.translatePrice(minTemp[i].round().toString())}°', 
                  textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryText)),
               ),
             ],
           ),
         )
       );
       
       if (i != timeRaw.length - 1) {
         rows.add(Divider(color: AppColors.primaryText.withOpacity(0.1)));
       }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('weather_hub'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    _buildGlassBox(
                      child: Column(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 28),
                          const SizedBox(height: 8),
                          TranslateText(
                            _cityName,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                          ),
                          const SizedBox(height: 24),
                          if (_currentWeather != null) ...[
                            Text(
                              _getWeatherVisual(_currentWeather!['weather_code']),
                              style: const TextStyle(fontSize: 70),
                            ),
                            Text(
                              '${s.translatePrice(_currentWeather!['temperature_2m'].toString())}°C',
                              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.primaryText),
                            ),
                            Text(
                              _getWeatherDesc(_currentWeather!['weather_code']),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.water_drop_outlined, color: Colors.blueAccent),
                                    const SizedBox(height: 4),
                                    Text('${s.translatePrice(_currentWeather!['relative_humidity_2m'].toString())}% ${s.translate('humidity')}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Icon(Icons.air_rounded, color: Colors.blueGrey),
                                    const SizedBox(height: 4),
                                    Text('${s.translatePrice(_currentWeather!['wind_speed_10m'].toString())} km/h ${s.translate('wind')}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                  ],
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Text(s.translate('forecast'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                    const SizedBox(height: 16),
                    
                    _buildGlassBox(
                      child: Column(
                        children: _build7DayForecastRows(),
                      )
                    ),
                    
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }
}
