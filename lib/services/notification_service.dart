import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'gridnote_saved_channel',
    'Gridnote – Guardados',
    description: 'Avisos cuando se guardan/exportan planillas',
    importance: Importance.high,
  );

  Future<void> init() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: initAndroid);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) async {
        final path = resp.payload;
        if (path == null || path.isEmpty) return;
        await OpenFilex.open(path);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> showSavedSheet({
    required String title,
    required String body,
    required String filePath,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: const BigTextStyleInformation(''),
      ),
    );

    await _plugin.show(
      10001, // id fijo está bien para reemplazar la última
      title,
      body,
      details,
      payload: filePath, // al tocar abre este archivo
    );
  }
}
