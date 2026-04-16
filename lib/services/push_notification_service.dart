import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';
import 'prescription_service.dart';

class PushNotificationService {
  PushNotificationService(this._api);
  final ApiClient _api;

  static bool _firebaseReady = false;
  static bool _tapHandlersConfigured = false;

  static Future<void> initializeFirebaseSafely() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<void> registerTokenIfPossible() async {
    if (!_firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _api.dio.post(
      ApiEndpoints.pushRegister,
      data: {'token': token, 'platform': 'mobile'},
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  static Future<void> configureTapHandlers(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (!_firebaseReady || _tapHandlersConfigured) return;
    _tapHandlersConfigured = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _handleReminderFromPush(
        navigatorKey: navigatorKey,
        data: message.data,
        fallbackTitle: message.notification?.title,
        fallbackQuestion: message.notification?.body,
      );
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleReminderFromPush(
          navigatorKey: navigatorKey,
          data: initial.data,
          fallbackTitle: initial.notification?.title,
          fallbackQuestion: initial.notification?.body,
        );
      });
    }
  }

  static Future<void> _handleReminderFromPush({
    required GlobalKey<NavigatorState> navigatorKey,
    required Map<String, dynamic> data,
    String? fallbackTitle,
    String? fallbackQuestion,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final prescriptionId = data['prescription_id']?.toString();
    if (prescriptionId == null || prescriptionId.isEmpty) return;
    final title = data['title']?.toString() ?? fallbackTitle ?? 'Nueva receta';
    final question = data['question']?.toString() ??
        fallbackQuestion ??
        'Quieres que te recordemos cada que te toque la pastilla?';
    final api = Provider.of<ApiClient>(context, listen: false);

    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (answer == null) return;
    final svc = PrescriptionService(api);
    await svc.setReminderOptIn(prescriptionId, answer);
  }
}

