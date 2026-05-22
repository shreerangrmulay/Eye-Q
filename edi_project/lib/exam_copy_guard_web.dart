// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

void enableExamCopyGuard() {
  js_util.callMethod(html.window, 'proctorExamGuardEnable', const []);
}

void disableExamCopyGuard() {
  js_util.callMethod(html.window, 'proctorExamGuardDisable', const []);
}
