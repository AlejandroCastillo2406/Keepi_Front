import '../../../core/keepi_timezone.dart';
import '../../../services/appointment_service.dart';

const doctorHomeMonthsEsUpper = <String>[
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];
const doctorHomeWeekdaysEsUpper = <String>[
  'LUN',
  'MAR',
  'MIÉ',
  'JUE',
  'VIE',
  'SÁB',
  'DOM'
];

String doctorHomeGreetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String doctorHomeTodayStamp() {
  final now = DateTime.now();
  return '${doctorHomeWeekdaysEsUpper[now.weekday - 1]} · ${now.day.toString().padLeft(2, '0')} ${doctorHomeMonthsEsUpper[now.month - 1]} ${now.year}';
}

String doctorHomeTwoDigits(int v) => v.toString().padLeft(2, '0');

bool doctorHomeSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? doctorHomeAppointmentSlotEnd(AppointmentDto a, int slotMinutes) {
  if (a.endDate != null) return a.endDate;
  final start = a.appointmentDate;
  if (start == null) return null;
  return start.add(Duration(minutes: slotMinutes));
}

bool doctorHomeCanConfirmAttendance(AppointmentDto a, int slotMinutes) {
  if (a.status != 'scheduled') return false;
  if (a.attendanceStatus != null && a.attendanceStatus!.isNotEmpty) {
    return false;
  }
  final end = doctorHomeAppointmentSlotEnd(a, slotMinutes);
  if (end == null) return false;
  return DateTime.now().toUtc().isAfter(end);
}

bool doctorHomeIsConfirmedAppointment(AppointmentDto a) => a.status == 'scheduled';

const doctorHomeNoScheduledAppointmentsMessage = 'No hay citas agendadas.';
