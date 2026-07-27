import 'package:flutter/widgets.dart';

import 'src/app_controller.dart';
import 'src/endless_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller = AppController.production();
  runApp(EndlessApp(controller: controller));
  controller.initialize();
}
