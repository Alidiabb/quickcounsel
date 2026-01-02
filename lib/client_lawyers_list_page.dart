import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'client_lawyer_details_page.dart';

class ClientLawyersListPage extends StatefulWidget {
  final int clientUserId;

  const ClientLawyersListPage({super.key, required this.clientUserId});

  @override
  State<ClientLawyersListPage> createState() => _ClientLawyersListPageState();
}

class _ClientLawyersListPageState extends State<ClientLawyersListPage> {
  final String baseUrl = "http://localhost:3000";

  final List<String> specializations = const [
    'قانون الأحوال الشخصيّة',
    'قانون العمل و الضمان الإجتماعي',
    'القانون المالي و الضريبي',
    'القانون العقاري و التنظيم المدني',
    'القانون الجزائي',
    'قانون الشركات',
  ];

  String? selectedSpec;
  List lawyers = [];
  bool loading = false;

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> fetchLawyers() async {
    if (selectedSpec == null) return;

    setState(() {
      loading = true;
      lawyers = [];
    });

    try {
      final url = Uri.parse("$baseUrl/lawyers?specialization=$selectedSpec");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() => lawyers = jsonDecode(response.body));
      } else {
        final data = jsonDecode(response.body);
        showMessage(data["message"] ?? "Failed to load lawyers");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    } finally {
      setState(() => loading = false);
    }
  }

  Widget starsFromAvg(dynamic value) {
    double avg = 0;
    if (value != null) avg = double.tryParse(value.toString()) ?? 0;
    final rounded = avg.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rounded ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber,
        );
      }),
    );
  }

  String specsText(Map lawyer) {
    final s1 = lawyer["specialization_1"] ?? "";
    final s2 = lawyer["specialization_2"] ?? "";
    if (s2 == null || s2.toString().isEmpty) return s1.toString();
    return "${s1.toString()} , ${s2.toString()}";
  }

  Future<void> submitRating(int lawyerUserId, int rating) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/rate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lawyer_user_id": lawyerUserId,
          "client_user_id": widget.clientUserId,
          "rating": rating,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        showMessage("Rated");
        fetchLawyers();
      } else {
        showMessage(data["message"] ?? "Rating failed");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    }
  }

  void openRateDialog(int lawyerId, String lawyerName) {
    showDialog(
      context: context,
      builder: (context) {
        int selected = 5;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text("Rate $lawyerName"),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    onPressed: () => setLocal(() => selected = star),
                    icon: Icon(
                      star <= selected ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    submitRating(lawyerId, selected);
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String initialsFromName(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'L';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'L';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Find a Lawyer")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose a specialization",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  value: selectedSpec,
                  decoration: const InputDecoration(
                    labelText: "Select specialization",
                  ),
                  items: specializations
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedSpec = value);
                    fetchLawyers();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (loading) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: lawyers.length,
                itemBuilder: (context, index) {
                  final lawyer = lawyers[index] as Map<String, dynamic>;
                  final id = int.parse(lawyer["id"].toString());
                  final name = lawyer["name"] ?? "Unknown";
                  final email = lawyer["email"] ?? "";
                  final avgRating = lawyer["avg_rating"];

                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientLawyerDetailsPage(
                              lawyerUserId: id,
                              clientUserId: widget.clientUserId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                initialsFromName(name.toString()),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  starsFromAvg(avgRating),
                                  const SizedBox(height: 6),
                                  Text(specsText(lawyer)),
                                  const SizedBox(height: 6),
                                  Text(email.toString()),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
