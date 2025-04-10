// lib/screens/home/home_screen.dart - COMPLETE FILE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:burnbank/services/auth_service.dart';
import 'package:burnbank/services/steps_service.dart';
import 'package:burnbank/screens/home/map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the steps service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stepsService = Provider.of<StepsService>(context, listen: false);
      stepsService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepsService = Provider.of<StepsService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('BurnBank'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => stepsService.refreshSteps(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/LOGO.png',
                  width: 100,
                  height: 100,
                ),
                
                const SizedBox(height: 24),
                
                // Map tracking card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.map,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Track Your Walk',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Record your route, track distance and earn more by walking!',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MapScreen()),
                            );
                          },
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Start Walking'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Step counter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Today\'s Steps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          stepsService.todaySteps.toString(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: stepsService.todaySteps / stepsService.dailyGoal,
                              minHeight: 10,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                stepsService.goalReached ? Colors.green : Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Goal: ${stepsService.dailyGoal} steps'),
                                if (stepsService.goalReached)
                                  const Text(
                                    'Goal Reached!',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Streak card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Streak',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${stepsService.currentStreak} days',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Keep walking daily to increase your streak and earn more!',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => stepsService.incrementStreak(),
                          child: const Text('Increment Streak (Test)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Earnings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Today\'s Earnings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '\$${stepsService.earnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Multiplier: ${stepsService.multiplier.toStringAsFixed(1)}x'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Test buttons for development
                ElevatedButton(
                  onPressed: () => stepsService.refreshSteps(),
                  child: const Text('Add 500 Steps (Test)'),
                ),
                
                const SizedBox(height: 8),
                
                ElevatedButton(
                  onPressed: () => stepsService.applyBoostMultiplier(1.5),
                  child: const Text('Apply 1.5x Boost (Test)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}