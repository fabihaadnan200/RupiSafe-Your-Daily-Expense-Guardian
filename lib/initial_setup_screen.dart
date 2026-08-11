import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _totalBudgetController = TextEditingController();
  final Map<String, TextEditingController> _catControllers = {};
  final double _survivalThreshold = 0.80;

  final Color primary = const Color(0xFF0A1931);
  final Color accent = const Color(0xFF00CC99);

  final List<String> _categories = [
    "Fitness",
    "Friend Activities",
    "Beverages",
    "Gifts",
    "Groceries",
    "Hobbies",
    "Housing & Utilities",
    "Healthcare",
    "Personal Hygiene",
    "Shopping",
    "Subscriptions",
    "Transport",
    "Travel",
    "Dining",
  ];

  @override
  void initState() {
    super.initState();
    for (var cat in _categories) {
      _catControllers[cat] = TextEditingController(text: "0");
    }
  }

  double get _remainingToAllocate {
    double total = double.tryParse(_totalBudgetController.text) ?? 0;
    double allocated = 0;
    _catControllers.forEach((key, controller) {
      allocated += double.tryParse(controller.text) ?? 0;
    });
    return total - allocated;
  }

  Future<void> _finalSave() async {
    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;

      Map<String, double> finalLimits = {};
      Map<String, double> initialSpent =
          {}; 

      _catControllers.forEach((key, controller) {
        finalLimits[key] = double.tryParse(controller.text) ?? 0;
        initialSpent[key] = 0.0;
      });

      
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'totalMonthlyBudget': double.parse(_totalBudgetController.text),
        'currentSpending': 0.0,
        'setupCompleted': true,
        'survivalThreshold': _survivalThreshold,
        'categoryLimits': finalLimits,
        'categorySpent': initialSpent, 
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Setup: Step ${_currentStep + 1} of 2",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primary,
        centerTitle: true,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet, size: 80, color: primary),
          ),
          const SizedBox(height: 30),
          Text(
            "Monthly Income",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Enter your total budget to start guarding your money!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          _prettyTextField(
            _totalBudgetController,
            "Enter Amount (PKR)",
            Icons.money,
          ),
          const SizedBox(height: 100),
          _nextButton(() {
            if (_totalBudgetController.text.isNotEmpty) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildRemainingHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              String cat = _categories[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  title: Text(
                    cat,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  trailing: SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _catControllers[cat],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      onChanged: (val) => setState(() {}),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0",
                        border: InputBorder.none,
                        suffixText: " PKR",
                        suffixStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _nextButton(_finalSave, text: "You're good to go!"),
        ),
      ],
    );
  }

  Widget _buildRemainingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const Text(
            "Remaining to Allocate",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            "PKR ${_remainingToAllocate.toStringAsFixed(0)}",
            style: TextStyle(
              color: _remainingToAllocate < 0 ? Colors.redAccent : accent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prettyTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primary),
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _nextButton(VoidCallback onPressed, {String text = "Continue"}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primary,
          elevation: 5,
          shadowColor: accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    _catControllers.forEach((key, controller) => controller.dispose());
    _pageController.dispose();
    super.dispose();
  }
}
