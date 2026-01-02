import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClientLawyerDetailsPage extends StatefulWidget {
  final int lawyerUserId;
  final int clientUserId;

  const ClientLawyerDetailsPage({
    super.key,
    required this.lawyerUserId,
    required this.clientUserId,
  });

  @override
  State<ClientLawyerDetailsPage> createState() =>
      _ClientLawyerDetailsPageState();
}

class _ClientLawyerDetailsPageState extends State<ClientLawyerDetailsPage> {
  final String baseUrl = "http://localhost:3000";

  Map<String, dynamic>? profile;
  List cases = [];

  bool loadingProfile = false;
  bool loadingCases = false;

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchCases();
  }

  Future<void> fetchProfile() async {
    setState(() => loadingProfile = true);

    try {
      final url = Uri.parse(
        "$baseUrl/lawyer/profile?user_id=${widget.lawyerUserId}",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() => profile = jsonDecode(response.body));
      } else {
        final data = jsonDecode(response.body);
        showMessage(data["message"] ?? "Failed to load profile");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    } finally {
      setState(() => loadingProfile = false);
    }
  }

  Future<void> fetchCases() async {
    setState(() => loadingCases = true);

    try {
      final url = Uri.parse(
        "$baseUrl/lawyer/cases?user_id=${widget.lawyerUserId}",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() => cases = jsonDecode(response.body));
      } else {
        final data = jsonDecode(response.body);
        showMessage(data["message"] ?? "Failed to load cases");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    } finally {
      setState(() => loadingCases = false);
    }
  }

  String dateOnly(dynamic value) {
    if (value == null) return "";
    return value.toString().split("T").first;
  }

  Widget buildStars(dynamic value) {
    double avg = 0;
    if (value != null) avg = double.tryParse(value.toString()) ?? 0;
    final rounded = avg.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rounded ? Icons.star : Icons.star_border,
          size: 20,
          color: Colors.amber,
        );
      }),
    );
  }

  Future<void> submitRating(int rating) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/rate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lawyer_user_id": widget.lawyerUserId,
          "client_user_id": widget.clientUserId,
          "rating": rating,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        showMessage("Rated");
        fetchProfile();
      } else {
        showMessage(data["message"] ?? "Rating failed");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    }
  }

  void openRateDialog(String lawyerName) {
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
                    submitRating(selected);
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

  Widget infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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
    final name = profile?["name"]?.toString() ?? "Lawyer";
    final email = profile?["email"]?.toString() ?? "";
    final description = profile?["description"]?.toString() ?? "";
    final memberSince = dateOnly(profile?["member_since"]);
    final avgRating = profile?["avg_rating"];

    final barNumber = profile?["bar_number"]?.toString() ?? "";
    final spec1 = profile?["specialization_1"]?.toString() ?? "";
    final spec2 = profile?["specialization_2"]?.toString() ?? "";
    final specs = spec2.isEmpty ? spec1 : "$spec1 , $spec2";

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: loadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF2563EB),
                                child: Text(
                                  initialsFromName(name),
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
                                      name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    buildStars(avgRating),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => openRateDialog(name),
                                child: const Text("Rate"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          infoRow("Email", email),
                          infoRow("Bar number", barNumber),
                          infoRow("Member since", memberSince),
                          infoRow("Specialization", specs),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Description",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description.isEmpty
                          ? "No description yet."
                          : description,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cases",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (loadingCases)
                      const Center(child: CircularProgressIndicator()),
                    if (!loadingCases && cases.isEmpty)
                      const Text("No cases added yet."),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final c = cases[index] as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            elevation: 0,
                            color: const Color(0xFFF1F5F9),
                            child: ListTile(
                              title: Text(c["title"]?.toString() ?? ""),
                              subtitle: Text(c["details"]?.toString() ?? ""),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
