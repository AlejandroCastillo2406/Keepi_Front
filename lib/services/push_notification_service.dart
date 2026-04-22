import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';
import 'appointment_service.dart';
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
      await _handlePushAction(
        navigatorKey: navigatorKey,
        data: message.data,
        fallbackTitle: message.notification?.title,
        fallbackQuestion: message.notification?.body,
      );
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handlePushAction(
          navigatorKey: navigatorKey,
          data: initial.data,
          fallbackTitle: initial.notification?.title,
          fallbackQuestion: initial.notification?.body,
        );
      });
    }
  }

  static Future<void> _handlePushAction({
    required GlobalKey<NavigatorState> navigatorKey,
    required Map<String, dynamic> data,
    String? fallbackTitle,
    String? fallbackQuestion,
  }) async {
    final appointmentId = data['appointment_id']?.toString();
    if (appointmentId != null && appointmentId.isNotEmpty) {
      await _handleAppointmentFromPush(
        navigatorKey: navigatorKey,
        appointmentId: appointmentId,
        action: data['action']?.toString(),
        fallbackTitle: fallbackTitle,
        fallbackQuestion: fallbackQuestion,
      );
      return;
    }
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

  static Future<void> _handleAppointmentFromPush({
    required GlobalKey<NavigatorState> navigatorKey,
    required String appointmentId,
    String? action,
    String? fallbackTitle,
    String? fallbackQuestion,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final api = Provider.of<ApiClient>(context, listen: false);
    final svc = AppointmentService(api);

    final isDoctorReview = action == 'doctor_review';
    final title = fallbackTitle ?? (isDoctorReview ? 'Solicitud de cambio de cita' : 'Nueva cita');
    final question = fallbackQuestion ??
        (isDoctorReview
            ? 'Tu paciente pide cambio de cita. ¿Aceptas esta propuesta?'
            : 'El doctor agendó una cita. ¿Deseas confirmar?');

    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isDoctorReview ? 'Contrapropuesta' : 'Cambiar hora'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (answer == null) return;
    if (answer) {
      if (isDoctorReview) {
        await svc.doctorAccept(appointmentId);
      } else {
        await svc.patientConfirm(appointmentId);
      }
      return;
    }

    if (isDoctorReview) {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time == null) return;
      final proposed = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      await svc.doctorCounterPropose(
        appointmentId: appointmentId,
        proposedStartAt: proposed,
      );
    } else {
      await svc.patientRequestChange(
        appointmentId: appointmentId,
      );
    }
  }
}

