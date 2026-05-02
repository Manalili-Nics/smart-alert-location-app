import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Alert',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF00B4D8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 80,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _latitude = '---';
  String _longitude = '---';
  String _accuracy = '---';
  bool _isLoading = false;
  String _status = 'Ready';

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.location, Permission.notification].request();
  }

  Future<bool> _checkLocationServices() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _addNotification(
        'SYSTEM ALERT',
        'Location services are disabled',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  void _addNotification(String title, String body, Color color) {
    setState(() {
      _notifications.insert(0, {
        'title': title,
        'body': body,
        'time': DateTime.now().toString().substring(11, 16),
        'date': DateTime.now().toString().substring(0, 10),
        'color': color,
      });
      if (_notifications.length > 10) {
        _notifications.removeLast();
      }
    });
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _status = 'Acquiring location...';
    });

    try {
      if (!await _checkLocationServices()) {
        setState(() {
          _isLoading = false;
          _status = 'Location services off';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _status = 'Permission denied';
            _isLoading = false;
          });
          _addNotification(
            'PERMISSION ERROR',
            'Location permission denied',
            Colors.red,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _status = 'Permission permanently denied';
          _isLoading = false;
        });
        _addNotification(
          'PERMISSION ERROR',
          'Location permission permanently denied',
          Colors.red,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude.toStringAsFixed(6);
        _longitude = position.longitude.toStringAsFixed(6);
        _accuracy = '±${position.accuracy.toStringAsFixed(1)}m';
        _isLoading = false;
        _status = 'Location acquired';
      });

      _addNotification(
        'LOCATION UPDATE',
        'Latitude: $_latitude\nLongitude: $_longitude\nAccuracy: $_accuracy',
        Colors.blue,
      );

      await NotificationService.showNotification(
        title: 'Location Retrieved',
        body: 'Lat: $_latitude, Lon: $_longitude',
        payload: 'location',
      );

      _showSnackbar('Location acquired!', Colors.green);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error';
      });
      _addNotification('ERROR', 'Failed to get location', Colors.red);
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _sendAlert() async {
    _addNotification(
      'HEADQUARTERS ALERT',
      'EMERGENCY! Field agent needs assistance!\nLocation: $_latitude, $_longitude',
      Colors.red,
    );

    await NotificationService.showNotification(
      title: 'HEADQUARTERS ALERT',
      body: 'Emergency! Field agent needs assistance!',
      payload: 'alert',
    );

    _showSnackbar('Alert sent to Headquarters!', Colors.orange);
    setState(() {
      _status = 'Alert transmitted';
    });
  }

  void _clearNotifications() {
    setState(() {
      _notifications.clear();
    });
    _showSnackbar('Notifications cleared', Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SMART ALERT & LOCATION',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          width: 10,
          height: 10,
          child: const Icon(Icons.circle, size: 10, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1117),
              const Color(0xFF161B22),
              const Color(0xFF0D1117),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF30363D),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _status.contains('Ready')
                            ? Icons.check_circle
                            : _status.contains('acquired')
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _status.contains('Ready')
                            ? Colors.grey
                            : _status.contains('acquired')
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (_notifications.isNotEmpty)
                        TextButton(
                          onPressed: _clearNotifications,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text(
                            'CLEAR',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Location Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF30363D),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Color(0xFF00B4D8),
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'CURRENT LOCATION',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LATITUDE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _latitude,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LONGITUDE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _longitude,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.track_changes,
                            size: 16,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accuracy: $_accuracy',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons - Larger
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _getLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.gps_fixed,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'GET MY LOCATION',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: 22,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'SEND ALERT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // NOTIFICATIONS SECTION - Fills remaining space
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF30363D),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 20,
                                color: Color(0xFF00B4D8),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'RECENT NOTIFICATIONS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _notifications.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inbox,
                                        size: 48,
                                        color: Color(0xFF30363D),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No notifications yet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Tap GET LOCATION or SEND ALERT',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _notifications.length,
                                  itemBuilder: (context, index) {
                                    final notif = _notifications[index];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D1117),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF30363D),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: notif['color'],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  notif['title'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                notif['time'],
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            notif['body'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notif['date'],
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Notification Service
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alert_channel',
          'Smart Alert Channel',
          channelDescription: 'Location updates and emergency alerts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(0, title, body, details, payload: payload);
  }
}
