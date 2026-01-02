import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LawyerUserPage extends StatefulWidget {
  final int lawyerUserId;

  const LawyerUserPage({super.key, required this.lawyerUserId});

  @override
  State<LawyerUserPage> createState() => _LawyerUserPageState();
}

class _LawyerUserPageState extends State<LawyerUserPage> {
  final String baseUrl = "http://localhost:3000";

  final descriptionController = TextEditingController();
  final caseTitleController = TextEditingController();
  final caseDetailsController = TextEditingController();

  bool loadingProfile = false;
  bool loadingCases = false;

  Map<String, dynamic>? profile;
  List cases = [];

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
        final data = jsonDecode(response.body);
        setState(() {
          profile = data;
          descriptionController.text = (data["description"] ?? "").toString();
        });
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

  Future<void> saveDescription() async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/lawyer/description"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.lawyerUserId,
          "description": descriptionController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        showMessage("Description saved");
        fetchProfile();
      } else {
        showMessage(data["message"] ?? "Failed to save description");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
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

  Future<void> addCase() async {
    final title = caseTitleController.text.trim();
    final details = caseDetailsController.text.trim();

    if (title.isEmpty || details.isEmpty) {
      showMessage("Please fill case title and details");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/lawyer/cases"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lawyer_user_id": widget.lawyerUserId,
          "title": title,
          "details": details,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        showMessage("Case added");
        caseTitleController.clear();
        caseDetailsController.clear();
        fetchCases();
      } else {
        showMessage(data["message"] ?? "Failed to add case");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    }
  }

  String dateOnly(dynamic value) {
    if (value == null) return "";
    return value.toString().split("T").first;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    caseTitleController.dispose();
    caseDetailsController.dispose();
    super.dispose();
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
    final lawyerName = profile?["name"]?.toString() ?? "Lawyer";
    final email = profile?["email"]?.toString() ?? "";
    final spec1 = profile?["specialization_1"]?.toString() ?? "";
    final spec2 = profile?["specialization_2"]?.toString() ?? "";
    final specs = spec2.isEmpty ? spec1 : "$spec1 $spec2";

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: loadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF2563EB),
                            child: Text(
                              initialsFromName(lawyerName),
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
                                  "Hello, $lawyerName",
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(email),
                                const SizedBox(height: 6),
                                Text("Specializations: $specs"),
                              ],
                            ),
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
                      "Description",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Write a description about yourself...",
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: saveDescription,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: const Size(140, 40),
                      ),
                      child: const Text(
                        "Save Description",
                        style: TextStyle(fontSize: 13),
                      ),
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
                      "Past Cases",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: caseTitleController,
                      decoration: const InputDecoration(
                        hintText: "Case title",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: caseDetailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "Case details",
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: addCase,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: const Size(120, 40),
                      ),
                      child: const Text(
                        "Add Case",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (loadingCases)
                      const Center(child: CircularProgressIndicator()),
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
                              subtitle: Text(
                                "${c["details"]?.toString() ?? ""}\n${dateOnly(c["created_at"])}",
                              ),
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
