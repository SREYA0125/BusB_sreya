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
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          primary: Colors.blueAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withOpacity(0.15); // Lighten on hover
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withOpacity(0.3); // Lighten more on click
                }
                return null;
              },
            ),
            elevation: WidgetStateProperty.resolveWith<double>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return 8.0; // Lift up on hover
                }
                if (states.contains(WidgetState.pressed)) {
                  return 4.0;
                }
                return 0.0;
              },
            ),
            shadowColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.blueAccent.withOpacity(0.8); // Glow effect
                }
                return null;
              },
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withOpacity(0.1);
                }
                return null;
              },
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withOpacity(0.1);
                }
                return null;
              },
            ),
          ),
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
