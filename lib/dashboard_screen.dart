import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isMenuOpen = false;

  String _key(String key) {
    return key
        .toLowerCase()
        .trim()
        .replaceAll(" ", "_")
        .replaceAll("/", "_")
        .replaceAll("&", "and");
  }

  String normalizeCategory(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll("&", "and")
        .replaceAll("/", "_")
        .replaceAll(" ", "_");
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF0A1931);
    final Color softMint = const Color(0xFFB2F2E1);
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    final List<String> allCategories = [
      "fitness",
      "friend_activities",
      "beverages",
      "gifts",
      "groceries",
      "hobbies",
      "housing_and_utilities",
      "healthcare",
      "personal_hygiene",
      "shopping",
      "subscriptions",
      "transport",
      "travel",
      "dining",
      "medical_dental",
      "food",
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          "RupiSafe",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        centerTitle: true,
        elevation: 0,
      ),

      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No data found."));
              }

              final txDocs = snapshot.data!.docs;

              Map<String, double> spentByCategory = {
                for (var c in allCategories) c: 0.0,
              };

              double totalSpent = 0;

              for (var doc in txDocs) {
                final data = doc.data() as Map<String, dynamic>;

                final amount = _safeDouble(data['amount']);

                final rawCategory =
                    (data['final_category'] ?? 'uncategorized').toString();

                final category = normalizeCategory(rawCategory);

                totalSpent += amount;

                spentByCategory.update(
                  category,
                  (value) => value + amount,
                  ifAbsent: () => amount,
                );
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const Center(child: Text("User data missing"));
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>;

                  double budget =
                      _safeDouble(userData['totalMonthlyBudget']);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(budget, totalSpent, primary),
                        const SizedBox(height: 30),
                        const Text(
                          "Category Monitor",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A1931),
                          ),
                        ),
                        const SizedBox(height: 15),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: spentByCategory.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2,
                          ),
                          itemBuilder: (context, index) {
                            String key =
                                spentByCategory.keys.elementAt(index);

                            double consumed =
                                spentByCategory[key] ?? 0.0;

                            double progress =
                                totalSpent == 0 ? 0 : consumed / totalSpent;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: softMint,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    key.replaceAll("_", " "),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0A1931),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      backgroundColor:
                                          Colors.white.withOpacity(0.5),
                                      color: const Color(0xFF0A1931),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "PKR ${consumed.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          if (_isMenuOpen)
            GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(color: Colors.black45),
            ),
        ],
      ),

      floatingActionButton:
          _buildExpandableFab(primary, const Color(0xFF00CC99)),
    );
  }

  // ✅ FIXED: moved OUTSIDE build (this was your real issue)
  Widget _buildFabOption(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color accent,
    Color primary,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          onPressed: onTap,
          backgroundColor: Colors.white,
          child: Icon(icon, color: accent),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(double budget, double spent, Color primary) {
    double remaining = budget - spent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "REMAINING BALANCE",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "PKR ${remaining.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: "BUDGET", value: "PKR ${budget.toInt()}"),
              _StatItem(label: "SPENT", value: "PKR ${spent.toInt()}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableFab(Color primary, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isMenuOpen) ...[
          _buildFabOption("What-If Simulator", Icons.psychology, () {
            setState(() => _isMenuOpen = false);
            Navigator.pushNamed(context, '/simulator');
          }, accent, primary),

          const SizedBox(height: 12),

          _buildFabOption("Add Expense", Icons.add_shopping_cart, () {
            setState(() => _isMenuOpen = false);
            Navigator.pushNamed(context, '/add_transaction');
          }, accent, primary),

          const SizedBox(height: 12),

          _buildFabOption("Survival Mode", Icons.shield, () {
            setState(() => _isMenuOpen = false);
            Navigator.pushNamed(context, '/survival');
          }, accent, primary),

          const SizedBox(height: 12),
        ],

        FloatingActionButton(
          onPressed: () =>
              setState(() => _isMenuOpen = !_isMenuOpen),
          backgroundColor: accent,
          child: Icon(
            _isMenuOpen ? Icons.close : Icons.menu,
            color: primary,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}