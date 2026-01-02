import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quickcounsel/components/my_textfield.dart';
import 'package:http/http.dart' as http;

enum UserRole { client, lawyer }

enum Gender { male, female }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final barNumberController = TextEditingController();

  UserRole selectedRole = UserRole.client;
  Gender? selectedGender;

  DateTime? dateOfBirth;
  DateTime? memberSince;

  bool spPersonalStatus = false;
  bool spLaborSocial = false;
  bool spFinancialTax = false;
  bool spRealEstateCivil = false;
  bool spCriminal = false;
  bool spCompanies = false;

  bool get isLawyer => selectedRole == UserRole.lawyer;

  int get selectedSpecsCount {
    int c = 0;
    if (spPersonalStatus) c++;
    if (spLaborSocial) c++;
    if (spFinancialTax) c++;
    if (spRealEstateCivil) c++;
    if (spCriminal) c++;
    if (spCompanies) c++;
    return c;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void toggleSpec(bool currentValue, void Function(bool) setValue) {
    if (currentValue == true) {
      setState(() => setValue(false));
      return;
    }

    if (selectedSpecsCount >= 2) {
      showMessage('You can select at most 2 specialisations');
      return;
    }

    setState(() => setValue(true));
  }

  String formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => dateOfBirth = picked);
    }
  }

  Future<void> pickMemberSince() async {
    final now = DateTime.now();
    final initial = memberSince ?? DateTime(now.year - 1, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => memberSince = picked);
    }
  }

  List<String> selectedSpecs() {
    final specs = <String>[];
    if (spPersonalStatus) specs.add('قانون الأحوال الشخصيّة');
    if (spLaborSocial) specs.add('قانون العمل و الضمان الإجتماعي');
    if (spFinancialTax) specs.add('القانون المالي و الضريبي');
    if (spRealEstateCivil) specs.add('القانون العقاري و التنظيم المدني');
    if (spCriminal) specs.add('القانون الجزائي');
    if (spCompanies) specs.add('قانون الشركات');
    return specs;
  }

  Future<void> signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage("Please fill name, email and password");
      return;
    }

    if (dateOfBirth == null) {
      showMessage("Please select date of birth");
      return;
    }

    if (selectedGender == null) {
      showMessage("Please select gender");
      return;
    }

    final role = selectedRole == UserRole.client ? "client" : "lawyer";
    final gender = selectedGender == Gender.male ? "male" : "female";

    final body = <String, dynamic>{
      "name": name,
      "email": email,
      "password": password,
      "date_of_birth": formatDate(dateOfBirth),
      "gender": gender,
      "role": role,
    };

    if (role == "lawyer") {
      final bar = barNumberController.text.trim();

      if (bar.isEmpty) {
        showMessage("Please enter bar number");
        return;
      }
      if (memberSince == null) {
        showMessage("Please select member since date");
        return;
      }

      final specs = selectedSpecs();
      if (specs.isEmpty) {
        showMessage("Please select at least 1 specialisation");
        return;
      }

      body["bar_number"] = bar;
      body["member_since"] = formatDate(memberSince);
      body["specialization_1"] = specs[0];
      body["specialization_2"] = specs.length > 1 ? specs[1] : null;
    }

    try {
      final response = await http.post(
        Uri.parse("http://localhost:3000/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        showMessage("Account created successfully");
        Navigator.pop(context);
      } else {
        showMessage(data["message"] ?? "Signup failed");
      }
    } catch (e) {
      showMessage("Cannot connect to server");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    barNumberController.dispose();
    super.dispose();
  }

  Widget sectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Create your account",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Tell us a bit about you to get started.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  sectionCard(
                    context,
                    "Basic information",
                    [
                      MyTextfield(
                        controller: nameController,
                        hintText: 'Full name',
                        obscureText: false,
                      ),
                      const SizedBox(height: 12),
                      MyTextfield(
                        controller: emailController,
                        hintText: 'Email address',
                        obscureText: false,
                      ),
                      const SizedBox(height: 12),
                      MyTextfield(
                        controller: passwordController,
                        hintText: 'Create a password',
                        obscureText: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  sectionCard(
                    context,
                    "Personal details",
                    [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Date of birth',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: pickDateOfBirth,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              minimumSize: const Size(120, 40),
                            ),
                            child: Text(
                              formatDate(dateOfBirth),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gender',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      RadioListTile<Gender>(
                        value: Gender.male,
                        groupValue: selectedGender,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Male'),
                        onChanged: (value) {
                          setState(() => selectedGender = value);
                        },
                      ),
                      RadioListTile<Gender>(
                        value: Gender.female,
                        groupValue: selectedGender,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Female'),
                        onChanged: (value) {
                          setState(() => selectedGender = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  sectionCard(
                    context,
                    "Choose your role",
                    [
                      RadioListTile<UserRole>(
                        value: UserRole.client,
                        groupValue: selectedRole,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Client'),
                        onChanged: (value) {
                          setState(() => selectedRole = value!);
                        },
                      ),
                      RadioListTile<UserRole>(
                        value: UserRole.lawyer,
                        groupValue: selectedRole,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Lawyer'),
                        onChanged: (value) {
                          setState(() => selectedRole = value!);
                        },
                      ),
                    ],
                  ),
                  if (isLawyer) ...[
                    const SizedBox(height: 16),
                    sectionCard(
                      context,
                      "Lawyer details",
                      [
                        MyTextfield(
                          controller: barNumberController,
                          hintText: 'Bar number',
                          obscureText: false,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Member since',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: pickMemberSince,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(120, 40),
                              ),
                              child: Text(
                                formatDate(memberSince),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Specialisation(s) (max 2)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          value: spPersonalStatus,
                          onChanged: (_) => toggleSpec(
                            spPersonalStatus,
                            (v) => spPersonalStatus = v,
                          ),
                          title: const Text('قانون الأحوال الشخصيّة'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: spLaborSocial,
                          onChanged: (_) => toggleSpec(
                            spLaborSocial,
                            (v) => spLaborSocial = v,
                          ),
                          title: const Text('قانون العمل و الضمان الإجتماعي'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: spFinancialTax,
                          onChanged: (_) => toggleSpec(
                            spFinancialTax,
                            (v) => spFinancialTax = v,
                          ),
                          title: const Text('القانون المالي و الضريبي'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: spRealEstateCivil,
                          onChanged: (_) => toggleSpec(
                            spRealEstateCivil,
                            (v) => spRealEstateCivil = v,
                          ),
                          title: const Text('القانون العقاري و التنظيم المدني'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: spCriminal,
                          onChanged: (_) =>
                              toggleSpec(spCriminal, (v) => spCriminal = v),
                          title: const Text('القانون الجزائي'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: spCompanies,
                          onChanged: (_) =>
                              toggleSpec(spCompanies, (v) => spCompanies = v),
                          title: const Text('قانون الشركات'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: signUp,
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
