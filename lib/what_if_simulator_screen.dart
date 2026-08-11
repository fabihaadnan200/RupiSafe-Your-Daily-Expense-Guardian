import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WhatIfSimulatorScreen extends StatefulWidget {
  const WhatIfSimulatorScreen({super.key});

  @override
  State<WhatIfSimulatorScreen> createState() => _WhatIfSimulatorScreenState();
}

class _WhatIfSimulatorScreenState extends State<WhatIfSimulatorScreen> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  double _inputPrice = 0.0;
  bool _showResults = false;

  final Color primary = const Color(0xFF0A1931);
  final Color accent = const Color(0xFF00CC99);
  final Color alert = const Color(0xFFD62828);

  // FIXED: Changed from a getter to a proper method to avoid Ln 25 error
  int calculateDaysLeft() {
    DateTime now = DateTime.now();
    DateTime lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.difference(now).inDays + 1;
  }

  void _analyzeImpact() {
    setState(() {
      _inputPrice = double.tryParse(_priceController.text) ?? 0;
      _showResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'AI Budget Simulator',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Connect to internet to fetch budget"),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          double totalBudget = (data['totalMonthlyBudget'] ?? 0).toDouble();
          double currentSpent = (data['currentSpending'] ?? 0).toDouble();
          double remainingBudget = totalBudget - currentSpent;

          // FIXED: Invoking the method correctly
          int daysRemaining = calculateDaysLeft();

          double currentDaily = remainingBudget / daysRemaining;
          double predictedDaily =
              (remainingBudget - _inputPrice) / daysRemaining;
          bool isCrisis =
              predictedDaily < (currentDaily * 0.6) || predictedDaily < 500;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Imagine a Purchase",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A1931),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputCard(),
                const SizedBox(height: 24),
                _buildPredictButton(),
                const SizedBox(height: 32),
                if (_showResults) ...[
                  const Text(
                    "Impact Analysis",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A1931),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResultsCard(currentDaily, predictedDaily, isCrisis),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            _itemController,
            "Item Name",
            "e.g. New Shoes",
            Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _priceController,
            "Price (PKR)",
            "5000",
            Icons.payments_outlined,
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _analyzeImpact,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          "Predict Future Impact",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primary),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildResultsCard(double current, double predicted, bool isCrisis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isCrisis
              ? [alert, const Color(0xFF9E1B1B)]
              : [accent, const Color(0xFF009E77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildImpactCircle(
                "Current Path",
                current,
                Colors.white.withValues(alpha: 0.5),
              ),
              const Icon(Icons.bolt, color: Colors.white, size: 28),
              _buildImpactCircle("After Purchase", predicted, Colors.white),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white30),
          const SizedBox(height: 16),
          Text(
            isCrisis ? "🔴 HIGH RISK" : "🟢 FINANCIALLY SAFE",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          // FIXED: Replaced 'whiteD9' with white.withValues
          Text(
            isCrisis
                ? "Warning: Your daily limit drops to PKR ${predicted.toInt()}."
                : "This purchase is within your safe daily limit.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCircle(String label, double val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 85,
          width: 85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              "PKR ${val < 0 ? 0 : val.toInt()}",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
