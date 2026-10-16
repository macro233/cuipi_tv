import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/lan_server.dart';
import 'views/tv_dashboard.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  final lanServer = LanServerService();
  runApp(CuipiTvApp(lanServer: lanServer));

  lanServer.startServer();
}

class CuipiTvApp extends StatelessWidget {
  final LanServerService lanServer;

  const CuipiTvApp({Key? key, required this.lanServer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '脆皮tv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1860FF),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TvDashboardView(lanServer: lanServer),
    );
  }
}
