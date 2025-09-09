// lib/core/loading.dart
import 'package:flutter_easyloading/flutter_easyloading.dart';

void configureLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.circle
    ..maskType = EasyLoadingMaskType.black
    ..userInteractions = false
    ..dismissOnTap = false
    ..toastPosition = EasyLoadingToastPosition.bottom;
}
