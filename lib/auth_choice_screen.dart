import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(Icons.savings, size: 120, color: Color(0xFF00CC99)),
            const SizedBox(height: 30),
            const Text(
              'Welcome to RupiSafe!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1931),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Ready to manage your money and prevent crises.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),

            // --- SIGN UP BUTTON ---
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00CC99),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Create New Account',
                style: TextStyle(
                  color: Color(0xFF0A1931),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- LOGIN BUTTON ---
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0A1931), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'I Already Have an Account',
                style: TextStyle(
                  color: Color(0xFF0A1931),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // --- FORGOT PASSWORD LINK ---
            TextButton(
              onPressed: () {
                _showForgotPasswordDialog(context);
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Color(0xFF0A1931),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ ADDED ONLY THIS FUNCTION
  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "Enter your email",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Email cannot be empty")),
                  );
                  return;
                }

                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password reset link sent to email"),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? "Error occurred")),
                  );
                }
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    );
  }
}