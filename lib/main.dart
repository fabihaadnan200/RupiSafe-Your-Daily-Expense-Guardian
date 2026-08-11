import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'auth_choice_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'initial_setup_screen.dart';
import 'dashboard_screen.dart';
import 'transaction_screen.dart';
import 'survival_mode_screen.dart';
import 'what_if_simulator_screen.dart';

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
      title: 'RupiSafe',
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/root': (context) => const RootHandler(),
        '/auth': (context) => const AuthChoiceScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/setup': (context) => InitialSetupScreen(),
        '/dashboard': (context) => DashboardScreen(),

        '/add_transaction': (context) => const AddTransactionScreen(),
        '/survival': (context) => const SurvivalModeScreen(),
        '/simulator': (context) => const WhatIfSimulatorScreen(),
      },
    );
  }
}

class RootHandler extends StatelessWidget {
  const RootHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasData && authSnapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data =
                  userSnapshot.data?.data() as Map<String, dynamic>?;

              final setupDone = data?['setupCompleted'] == true;

              if (!setupDone) {
                return InitialSetupScreen();
              }

              return DashboardScreen();
            },
          );
        }

        return const AuthChoiceScreen();
      },
    );
  }
}