import 'package:flutter/material.dart';

class OverviewHeader extends StatefulWidget {
  /// Called whenever the user picks a new time period (Today, Weekly, Monthly).
  final ValueChanged<String> onDropdownChanged;

  const OverviewHeader({
    super.key,
    required this.onDropdownChanged,
  });

  @override
  _OverviewHeaderState createState() => _OverviewHeaderState();
}

class _OverviewHeaderState extends State<OverviewHeader> {
  String _selectedPeriod = 'Monthly'; // default selection

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row: Dropdown + calendar icon (replaces "Overview" + search icon)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(
                Icons.calendar_today,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: <String>['Today', 'Weekly', 'Monthly'].map(
                  (String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPeriod = newValue;
                    });
                    widget.onDropdownChanged(newValue);
                  }
                },
                underline: const SizedBox(), // Remove default underline
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Row: Two boxes for Income & Spending
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Income Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F9EE), // light green background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Income',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '+\$6,072.00',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Spending Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEEDEE), // light pink/red background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Spending',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '-\$2,831.90',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
