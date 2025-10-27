// lib/screens/rider_performance_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // Import pour les graphiques
import 'dart:math'; // Import pour Random (confetti)
import 'package:canvas_confetti/canvas_confetti.dart' as confetti; // Import pour confetti

import '../models/performance_data.dart'; // <-- DOIT ÊTRE RÉSENT DANS lib/models/
import '../services/performance_service.dart';
import '../utils/app_theme.dart';

class RiderPerformanceScreen extends StatefulWidget {
  const RiderPerformanceScreen({super.key});

  @override
  State<RiderPerformanceScreen> createState() => _RiderPerformanceScreenState();
}

class _RiderPerformanceScreenState extends State<RiderPerformanceScreen> {
  String _selectedPeriod = 'current_month'; // Période par défaut
  Future<PerformanceData>? _performanceFuture;

  // Contrôleurs pour l'édition des objectifs
  final TextEditingController _dailyGoalController = TextEditingController();
  final TextEditingController _weeklyGoalController = TextEditingController();
  final TextEditingController _monthlyGoalController = TextEditingController();
  String _editGoalsFeedback = '';
  bool _isSavingGoals = false;
  // Correction pour la gestion des objectifs
  bool _isEditingGoals = false; 

  // Options pour le dropdown de période
  final Map<String, String> _periodOptions = {
    'today': 'Aujourd\'hui',
    'yesterday': 'Hier',
    'current_week': 'Cette semaine',
    'last_week': 'Semaine dernière',
    'current_month': 'Ce mois-ci',
    'last_month': 'Mois dernier',
  };

  @override
  void initState() {
    super.initState();
    // Lance le fetch initial après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPerformance();
    });
  }

  @override
  void dispose() {
    _dailyGoalController.dispose();
    _weeklyGoalController.dispose();
    _monthlyGoalController.dispose();
    super.dispose();
  }

  void _fetchPerformance() {
    final performanceService = Provider.of<PerformanceService?>(context, listen: false);
    if (performanceService == null) {
      setState(() { _performanceFuture = Future.error("Service Performance non disponible."); });
      return;
    }
    setState(() {
      _performanceFuture = performanceService.fetchPerformanceData(_selectedPeriod);
      // Réinitialise l'état d'édition si on change de période
      _isEditingGoals = false;
      _editGoalsFeedback = '';
    });
  }

  // --- Fonctions utilitaires ---
  final _currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
  String formatAmount(double? amount) => _currencyFormatter.format(amount ?? 0);
  String formatPercent(double? rate) => '${((rate ?? 0) * 100).toStringAsFixed(1)}%';

  // --- Gestion édition objectifs ---
  void _toggleEditGoals(PersonalGoals currentGoals) {
    setState(() {
      _isEditingGoals = !_isEditingGoals;
      _editGoalsFeedback = ''; // Efface le feedback en changeant de mode
      if (_isEditingGoals) {
        // Pré-remplir les champs avec les valeurs actuelles
        _dailyGoalController.text = currentGoals.daily?.toString() ?? '';
        _weeklyGoalController.text = currentGoals.weekly?.toString() ?? '';
        _monthlyGoalController.text = currentGoals.monthly?.toString() ?? '';
      }
    });
  }

  Future<void> _savePersonalGoals() async {
    setState(() { _isSavingGoals = true; _editGoalsFeedback = 'Enregistrement...'; });
    final performanceService = Provider.of<PerformanceService?>(context, listen: false);
    if (performanceService == null) {
       setState(() { _isSavingGoals = false; _editGoalsFeedback = 'Erreur: Service indisponible.'; });
       return;
    }

    // Créer l'objet PersonalGoals à partir des contrôleurs
    final goalsToSave = PersonalGoals(
      daily: int.tryParse(_dailyGoalController.text),
      weekly: int.tryParse(_weeklyGoalController.text),
      monthly: int.tryParse(_monthlyGoalController.text),
    );

    try {
      await performanceService.updatePersonalGoals(goalsToSave);
      setState(() {
        _editGoalsFeedback = 'Objectifs sauvegardés !';
        _isEditingGoals = false; // Revenir en mode affichage
        // Rafraîchir les données pour afficher les objectifs mis à jour
         _performanceFuture = null; // Force le FutureBuilder à reconstruire avec le spinner
      });
      _fetchPerformance(); // Relance le fetch
       _showSnackbar('Objectifs personnels mis à jour.', success: true);

    } catch (e) {
      setState(() {
        _editGoalsFeedback = 'Erreur: ${e.toString().replaceFirst('Exception: ', '')}';
      });
       _showSnackbar('Erreur lors de la sauvegarde des objectifs.', success: false);
    } finally {
       if (mounted) { // Vérifier si le widget est toujours monté
          setState(() { _isSavingGoals = false; });
          // Effacer le feedback après un délai
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _editGoalsFeedback.startsWith('Erreur')) {
              setState(() { _editGoalsFeedback = ''; });
            }
          });
       }
    }
  }

  // --- Affichage Snackbar ---
  void _showSnackbar(String message, {bool success = true}) {
      if (!mounted) return; // Vérifie si le widget est toujours là
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

   // --- Logique Confetti ---
  void _triggerConfetti() {
    confetti.run(context,
      particleCount: 150, // Nombre de confettis
      gravity: 0.3,
      emissionFrequency: 0.05,
      numberOfParticles: 20,
      blastDirectionality: confetti.BlastDirectionality.explosive,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Performances'),
      ),
      body: FutureBuilder<PerformanceData>(
        future: _performanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _performanceFuture != null) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Text(
                   'Erreur: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                   style: const TextStyle(color: Colors.red),
                   textAlign: TextAlign.center,
                 ),
               ),
             );
          } else if (!snapshot.hasData && _performanceFuture == null) {
             return const Center(child: Text('Sélectionnez une période pour charger les données.'));
          } else if (!snapshot.hasData) {
              return const Center(child: Text('Aucune donnée de performance disponible.'));
          }

          final data = snapshot.data!;

          // --- Déclenchement Confetti ---
          final goals = data.personalGoals;
          final stats = data.stats;
          // Vérifier si l'objectif quotidien est atteint POUR LA PÉRIODE "aujourd'hui"
          if (_selectedPeriod == 'today' && goals.daily != null && goals.daily! > 0 && stats.delivered >= goals.daily!) {
             // Utilise WidgetsBinding pour lancer après le build
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 _triggerConfetti();
             });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 16),
                _buildEncouragementCard(data.stats),
                const SizedBox(height: 16),
                _buildKeyIndicators(data.stats),
                const SizedBox(height: 20),
                _buildRemunerationCard(data),
                const SizedBox(height: 20),
                if (data.riderType == 'moto') ...[
                  _buildAdminObjectivesCard(data.objectivesAdmin, data.remuneration as MotoRemuneration),
                  const SizedBox(height: 20),
                ],
                _buildPersonalGoalsCard(data.personalGoals, data.stats),
                const SizedBox(height: 20),
                _buildChartCard(data.chartData),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets pour chaque section ---

  Widget _buildPeriodSelector() {
    return DropdownButtonFormField<String>(
      // Utilisation de .initialValue pour éviter le warning de 'value' déprécié
      decoration: InputDecoration(
        labelText: 'Afficher pour',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      initialValue: _selectedPeriod, // CORRECTION : Remplacement de 'value' par 'initialValue'
      items: _periodOptions.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null && newValue != _selectedPeriod) {
          setState(() {
            _selectedPeriod = newValue;
            _performanceFuture = null; // Indicate loading
          });
          _fetchPerformance();
        }
      },
    );
   }

   Widget _buildEncouragementCard(PerformanceStats stats) {
     String message = "Continuez vos efforts !";
    double rate = stats.livrabiliteRate * 100;
    int delivered = stats.delivered;

    if (rate >= 95 && delivered > 10) { // CORRECTION: Ajout des accolades pour le linting
      message = "🏆 Excellent travail ! Taux de livraison remarquable !"; 
    }
    else if (rate >= 80 && delivered > 5) { // CORRECTION: Ajout des accolades pour le linting
      message = "👍 Très bonnes performances !";
    }
    else if (delivered > 0) { // CORRECTION: Ajout des accolades pour le linting
      message = "💪 Vos efforts portent leurs fruits !";
    }

    return Card(
      // CORRECTION: Remplacement de .withOpacity() par .withAlpha()
      color: AppTheme.primaryColor.withAlpha((255 * 0.1).round()),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
        ),
      ),
    );
   }

   Widget _buildKeyIndicators(PerformanceStats stats) {
     double ratePercent = stats.livrabiliteRate * 100;
    Color rateColor;
    if (ratePercent < 70) rateColor = AppTheme.danger;
    else if (ratePercent < 90) rateColor = Colors.orange.shade700;
    else rateColor = Colors.green.shade700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIndicatorItem(Icons.call_received, 'Reçues', stats.received.toString()),
                _buildIndicatorItem(Icons.check_circle_outline, 'Livrées', stats.delivered.toString(), Colors.green.shade700),
                 _buildIndicatorItem(Icons.calendar_today_outlined, 'Jours Actifs', stats.workedDays.toString(), Colors.blue.shade700),
              ],
            ),
             const SizedBox(height: 16),
             const Divider(),
             const SizedBox(height: 16),
            Row(
              children: [
                 Icon(Icons.pie_chart_outline_rounded, color: rateColor),
                 const SizedBox(width: 8),
                 const Text('Taux Livrabilité:', style: TextStyle(fontWeight: FontWeight.w500)),
                 const Spacer(),
                 Text(formatPercent(stats.livrabiliteRate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: rateColor)),
              ],
            ),
             const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.livrabiliteRate,
              backgroundColor: Colors.grey.shade300,
              color: rateColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
   }

   Widget _buildIndicatorItem(IconData icon, String label, String value, [Color? valueColor]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? AppTheme.secondaryColor)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
   }

   Widget _buildRemunerationCard(PerformanceData data) {
    String periodText = _periodOptions[_selectedPeriod] ?? 'Période';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ma Rémunération ($periodText)', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            if (data.remuneration is PiedRemuneration)
              _buildPiedRemunerationDetails(data.remuneration as PiedRemuneration)
            else if (data.remuneration is MotoRemuneration)
              _buildMotoRemunerationDetails(data.remuneration as MotoRemuneration)
            else
              const Text('Type de rémunération non défini.', style: TextStyle(color: Colors.grey)),

             const Divider(height: 20),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rémunération Totale Estimée:', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(
                      formatAmount(data.remuneration.totalPay),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                ],
             )
          ],
        ),
      ),
    );
   }

   Widget _buildPiedRemunerationDetails(PiedRemuneration details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRowSimple('CA (Frais liv.)', formatAmount(details.ca)),
        _buildDetailRowSimple('Dépenses', formatAmount(details.expenses), subText: formatPercent(details.expenseRatio)),
        _buildDetailRowSimple('Solde Net', formatAmount(details.netBalance)),
        _buildDetailRowSimple(
          'Taux Appliqué',
          formatPercent(details.rate),
          badgeText: details.bonusApplied ? '+5% Bonus' : null,
          badgeColor: details.bonusApplied ? Colors.green : null,
        ),
      ],
    );
   }

   Widget _buildMotoRemunerationDetails(MotoRemuneration details) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRowSimple('Salaire de Base', formatAmount(details.baseSalary)),
        _buildDetailRowSimple('Prime Performance', formatAmount(details.performanceBonus)),
      ],
    );
   }

   Widget _buildAdminObjectivesCard(AdminObjectives objectives, MotoRemuneration remuneration) {
     String periodText = _periodOptions[_selectedPeriod] ?? 'Période';
     double percentage = objectives.percentage * 100;
     Color progressColor = Colors.grey.shade400;
     if (objectives.target != null && objectives.target! > 0) {
        if (objectives.achieved >= objectives.bonusThreshold) { // Eligible
            if(percentage >= 100) { progressColor = Colors.green; } // CORRECTION: Ajout des accolades pour le linting
            else if (percentage >= 85) { progressColor = Colors.blue; } // CORRECTION: Ajout des accolades pour le linting
            else { progressColor = Colors.cyan; } // CORRECTION: Ajout des accolades pour le linting
        } else { // Non eligible
            progressColor = Colors.orange;
        }
     }


    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),