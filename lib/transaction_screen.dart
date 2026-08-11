import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final Color primary = const Color(0xFF0A1931);
  final Color accent = const Color(0xFF00CC99);

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _aiSuggestedCategory = "Waiting for prediction...";
  String _selectedCategory = "";

  String _paymentMethod = "Cash";
  String _location = "Home";

  final List<String> _categories = [
    "Groceries",
    "Beverages",
    "Dining",
    "Fitness",
    "Transport",
    "Travel",
    "Entertainment",
    "Education",
    "Hobbies",
    "Gifts",
    "Utilities",
    "Healthcare",
    "Shopping"
  ];

  Timer? _debounce;
  int _requestId = 0;
  void _fetchAiPrediction(String _) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final text = _descriptionController.text.trim();
      final amount = double.tryParse(_amountController.text.trim());

      if (text.isEmpty || amount == null) return;

      _requestId++;
      final int currentId = _requestId;

      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;

        final res = await ApiService.predictExpense(
          userId: uid,
          text: text,
          amount: amount,
          paymentMethod: _paymentMethod,
          location: _location,
        );

        if (currentId != _requestId) return;

        final category = (res["category"] ?? "Unknown").toString();

        setState(() {
          _aiSuggestedCategory = category;

         
          if (_categories.contains(category)) {
            _selectedCategory = category;
          }
        });
      } catch (e) {
        setState(() {
          _aiSuggestedCategory = "Prediction failed";
        });
      }
    });
  }


  Future<void> _saveToFirebase({
    required String userId,
    required String text,
    required double amount,
    required String aiCategory,
    required String finalCategory,
  }) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("transactions")
        .add({
      "text": text,
      "amount": amount,
      "ai_category": aiCategory,
      "final_category": finalCategory,
      "payment_method": _paymentMethod,
      "location": _location,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

 
  Future<void> _saveTransaction() async {
  if (_amountController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please enter an amount.")),
    );
    return;
  }

  final description = _descriptionController.text.trim().isEmpty
      ? "No Description"
      : _descriptionController.text.trim();

  final double? amount = double.tryParse(_amountController.text.trim());

  if (amount == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid amount.")),
    );
    return;
  }

  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final prediction = await ApiService.predictExpense(
      userId: uid,
      text: description,
      amount: amount,
      paymentMethod: _paymentMethod,
      location: _location,
    );

    final aiRaw =
        (prediction['category'] ?? _aiSuggestedCategory).toString();

    final aiCategory =
        aiRaw[0].toUpperCase() + aiRaw.substring(1).toLowerCase();

    final finalCategory =
        _selectedCategory.isNotEmpty ? _selectedCategory : aiCategory;

    
    await _saveToFirebase(
      userId: uid,
      text: description,
      amount: amount,
      aiCategory: aiCategory,
      finalCategory: finalCategory,
    );

    
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "currentSpending": FieldValue.increment(amount),
      "categorySpent.$finalCategory": FieldValue.increment(amount),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved $finalCategory successfully"),
        ),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What did you spend on?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1931),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _descriptionController,
              onChanged: _fetchAiPrediction,
              decoration: InputDecoration(
                hintText: 'e.g., Lunch with friends',
                prefixIcon:
                    Icon(Icons.description_outlined, color: primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "How much?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1931),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _fetchAiPrediction,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
              decoration: InputDecoration(
                prefixText: 'PKR ',
                prefixStyle: TextStyle(fontSize: 20, color: primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 30),

            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: accent),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AI Predicted Category",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _aiSuggestedCategory,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Correct Category (Manual Override)",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory.isEmpty
                      ? null
                      : _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCategory = newValue ?? "";
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Transaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}