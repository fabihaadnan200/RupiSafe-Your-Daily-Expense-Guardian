import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

const Color rupsafePrimary = Color(0xFF0A1931);
const Color rupsafeAccent = Color(0xFF00CC99);
const Color rupsafeAlert = Color(0xFFD62828);

class SurvivalModeScreen extends StatefulWidget {
  const SurvivalModeScreen({super.key});

  @override
  State<SurvivalModeScreen> createState() => _SurvivalModeScreenState();
}

class _SurvivalModeScreenState extends State<SurvivalModeScreen> {
  bool isLoading = true;
  int dailyLimit = 0;
  double usedPercentage = 0.0;

  bool isSurvivalOn = false; 
  bool isAltLoading = false;
  final TextEditingController _itemController = TextEditingController();
  List<dynamic> alternatives = [];

  @override
  void initState() {
    super.initState();
    fetchSurvivalStatus();
  }

 Future<void> fetchSurvivalStatus() async {
  try {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final data = await ApiService.getSurvivalStatus(userId);

    print("SURVIVAL DATA: $data");

    setState(() {
      isSurvivalOn = data['survival_mode'] == true;
      dailyLimit = (data['daily_allowance'] ?? 0).toInt();
      usedPercentage = (data['spent_percent'] ?? 0).toDouble();
      isLoading = false;
    });
  } catch (e) {
    print("SURVIVAL ERROR: $e");

    setState(() {
      isLoading = false;
    });
  }
}
 


  Future<void> fetchAlternatives() async {
    if (!isSurvivalOn) return;
    if (_itemController.text.trim().isEmpty) return;

    setState(() {
      isAltLoading = true;
      alternatives = [];
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final alts = await ApiService.getAlternatives(
        userId: userId,
        itemText: _itemController.text.trim(),
      );
      setState(() {
        alternatives = alts;
      });
    } catch (e) {
      print("Error fetching alternatives: $e");
    } finally {
      setState(() {
        isAltLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: rupsafePrimary,
      appBar: AppBar(
        title: const Text(
          "SURVIVAL MODE",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: rupsafeAlert,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          border: Border.all(color: rupsafeAccent, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "DAILY LIMIT",
                              style: TextStyle(
                                color: rupsafeAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "PKR $dailyLimit",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: rupsafeAlert.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (isSurvivalOn
                                  ? "SURVIVAL MODE ACTIVE: "
                                  : "NORMAL MODE: ") +
                              "${usedPercentage.toStringAsFixed(0)}% budget used.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      
                      if (isSurvivalOn) ...[
                        const Text(
                          "Find Cheaper Alternatives",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _itemController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "What are you planning to buy?",
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed:
                              isAltLoading ? null : () => fetchAlternatives(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rupsafeAccent,
                          ),
                          child: isAltLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        rupsafePrimary),
                                  ),
                                )
                              : const Text(
                                  "Suggest Alternatives",
                                  style: TextStyle(
                                      color: rupsafePrimary,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 15),

                        if (alternatives.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Suggested Alternatives:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...alternatives.map((alt) {
                                  // Adjust this according to the structure
                                  // your backend returns, e.g. name/price/link.
                                  final name = alt['name'] ?? alt.toString();
                                  final price = alt['price']?.toString() ?? '';
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      "- $name  $price",
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }
}