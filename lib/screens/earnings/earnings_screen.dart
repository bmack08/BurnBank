// lib/screens/earnings/earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:burnbank/services/steps_service.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stepsService = Provider.of<StepsService>(context);

    // Mock earnings history
    final earningsHistory = [
      {
        'date': DateTime.now(),
        'amount': stepsService.earnings,
        'status': 'Pending'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 1)),
        'amount': 1.85,
        'status': 'Completed'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'amount': 1.62,
        'status': 'Completed'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 3)),
        'amount': 1.93,
        'status': 'Completed'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 4)),
        'amount': 2.00,
        'status': 'Completed'
      },
    ];

    // Calculate total earnings
    final totalEarnings = earningsHistory.fold(
        0.0, (sum, item) => sum + (item['amount'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total earnings card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Total Earnings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${totalEarnings.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement cashout screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Cashout feature coming soon')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Cash Out'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Earnings history section
            const Text(
              'Earnings History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Earnings list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: earningsHistory.length,
              itemBuilder: (context, index) {
                final entry = earningsHistory[index];
                final date = entry['date'] as DateTime;
                final amount = entry['amount'] as double;
                final status = entry['status'] as String;

                final dateFormat = DateFormat('MMM d, yyyy');

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('\$${amount.toStringAsFixed(2)}'),
                    subtitle: Text(dateFormat.format(date)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Completed'
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Premium upsell card
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Go Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Earn up to \$4 per day (double the limit!)'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement premium subscription
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Premium subscription coming soon')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: const Text('Upgrade for \$4.99/month'),
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
