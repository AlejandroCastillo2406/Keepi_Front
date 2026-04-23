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
        '¿Quieres que te recordemos cada que te toque la pastilla?';
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

    // Determinamos si la push es para el doctor o para el paciente
    final isDoctorReview = action == 'doctor_review';

    if (isDoctorReview) {
      // --- FLUJO DEL DOCTOR (Asignar fecha) ---
      final title = fallbackTitle ?? 'Solicitud de Cita';
      final question = fallbackQuestion ?? 'Un paciente ha solicitado una cita. ¿Deseas asignarle una fecha ahora?';

      final assign = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(question),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Después'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Asignar Fecha'),
            ),
          ],
        ),
      );

      if (assign == true) {
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
        
        try {
          await svc.doctorProposeTime(
            appointmentId: appointmentId,
            proposedStartAt: proposed,
            durationMinutes: 30, // Duración por defecto
          );
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('Fecha propuesta enviada al paciente')),
          );
        } catch(e) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    } else {
      // --- FLUJO DEL PACIENTE (Aceptar / Rechazar) ---
      final title = fallbackTitle ?? 'Propuesta de Cita';
      final question = fallbackQuestion ?? 'El doctor ha asignado una fecha para tu cita. ¿Deseas aceptarla?';

      final patientAction = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(question),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('reject'),
              child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('accept'),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (patientAction != null) {
        try {
          await svc.patientRespondProposal(
            appointmentId: appointmentId,
            action: patientAction,
          );
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text(patientAction == 'accept' ? 'Cita confirmada' : 'Cita rechazada')),
          );
        } catch(e) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    }
  }
}