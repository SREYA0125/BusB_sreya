import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/screens/intro_screen.dart';
import 'package:flutter_app/screens/bus_search_screen.dart';
import 'package:flutter_app/screens/driver_bus_dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          surface: Colors.black,
          primary: Colors.blueAccent,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }
        final prefs = snapshot.data;
        final role = prefs?.getString('user_role');
        final user = FirebaseAuth.instance.currentUser;

        if (user != null && role != null) {
          if (role == 'driver') {
            return const DriverBusDashboardScreen();
          } else {
            return const BusSearchScreen();
          }
        }
        return const IntroScreen();
      },
    );
  }
}
