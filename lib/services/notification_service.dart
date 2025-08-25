import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _fln.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) async {
        final p = resp.payload;
        if (p == null || p.isEmpty) return;
        // Intentar abrir archivo
        await OpenFilex.open(p);
      },
    );
    _inited = true;
  }

  Future<void> showSavedSheetBanner({
    required BuildContext context,
    required String sheetId,
    String? sheetName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/sheets/$sheetId.json');

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          'Cambios guardados ${sheetName == null ? '' : 'en "$sheetName"'}\n${file.path}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          TextButton(
            onPressed: () async {
              messenger.hideCurrentMaterialBanner();
              await OpenFilex.open(file.path); // muchos gestores abren el archivo
            },
            child: const Text('ABRIR'),
          ),
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> notifyExportedFile(File file, {String? title}) async {
    await _fln.show(
      2001,
      title ?? 'Exportación lista',
      file.path,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'gridnote_ops', 'Operaciones',
          channelDescription: 'Notificaciones de guardado/exports',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: const BigTextStyleInformation(''),
          category: AndroidNotificationCategory.status,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: file.path, // al tocar se abre
    );
  }
}
