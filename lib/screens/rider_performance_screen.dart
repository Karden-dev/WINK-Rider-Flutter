// lib/screens/rider_performance_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // Import pour les graphiques
import 'dart:math'; // Import pour min
import 'package:confetti/confetti.dart'; // Import du bon package

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

  // CORRECTION: Contrôleur pour le package 'confetti'
  late ConfettiController _confettiController;

  // Contrôleurs pour l'édition des objectifs
  final TextEditingController _dailyGoalController = TextEditingController();
  final TextEditingController _weeklyGoalController = TextEditingController();
  final TextEditingController _monthlyGoalController = TextEditingController();
  String _editGoalsFeedback = '';
  bool _isSavingGoals = false;
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
    // CORRECTION: Initialisation du contrôleur de confetti
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));

    // Lance le fetch initial après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPerformance();
    });
  }

  @override
  void dispose() {
    // CORRECTION: Dispose du contrôleur
    _confettiController.dispose();
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
      await performanceService.updatePersonalGoals(goalsToSave); //
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
          backgroundColor: success ? Colors.green : AppTheme.danger,
        ),
      );
    }

   // --- Logique Confetti ---
  void _triggerConfetti() {
    // CORRECTION: Utilisation de la méthode play() du contrôleur
    _confettiController.play();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Performances'),
      ),
      // CORRECTION: Ajout d'un Stack pour superposer le widget Confetti
      body: Stack(
        children: [
          FutureBuilder<PerformanceData>(
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
                       style: const TextStyle(color: AppTheme.danger),
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
              final goals = data.personalGoals; //
              final stats = data.stats; //
              // Vérifier si l'objectif quotidien est atteint POUR LA PÉRIODE "aujourd'hui"
              if (_selectedPeriod == 'today' && goals.daily != null && goals.daily! > 0 && stats.delivered >= goals.daily!) {
                 // Utilise WidgetsBinding pour lancer après le build
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                     // Utilise une condition pour ne pas redéclencher à chaque rebuild du FutureBuilder si l'objectif est atteint.
                     // (Logique de stockage local ou de vérification de l'état des Confettis)
                     if (!_confettiController.isActive) {
                       _triggerConfetti();
                     }
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
                      //
                      _buildAdminObjectivesCard(data.objectivesAdmin, data.remuneration as MotoRemuneration), //
                      const SizedBox(height: 20),
                    ],
                    _buildPersonalGoalsCard(data.personalGoals, data.stats), //
                    const SizedBox(height: 20),
                    _buildChartCard(data.chartData), //
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
          // CORRECTION: Ajout du widget Confetti au Stack
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets pour chaque section ---

  Widget _buildPeriodSelector() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Afficher pour',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      initialValue: _selectedPeriod,
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

   Widget _buildEncouragementCard(PerformanceStats stats) { //
     String message = "Continuez vos efforts !";
    double rate = stats.livrabiliteRate * 100; //
    int delivered = stats.delivered; //

    if (rate >= 95 && delivered > 10) {
      message = "🏆 Excellent travail ! Taux de livraison remarquable !"; 
    }
    else if (rate >= 80 && delivered > 5) {
      message = "👍 Très bonnes performances !";
    }
    else if (delivered > 0) {
      message = "💪 Vos efforts portent leurs fruits !";
    }

    return Card(
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

   Widget _buildKeyIndicators(PerformanceStats stats) { //
     double ratePercent = stats.livrabiliteRate * 100; //
    Color rateColor;
    if (ratePercent < 70) {
      rateColor = AppTheme.danger; //
    } else if (ratePercent < 90) rateColor = Colors.orange.shade700;
    else rateColor = Colors.green.shade700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIndicatorItem(Icons.call_received, 'Reçues', stats.received.toString()), //
                _buildIndicatorItem(Icons.check_circle_outline, 'Livrées', stats.delivered.toString(), Colors.green.shade700), //
                 _buildIndicatorItem(Icons.calendar_today_outlined, 'Jours Actifs', stats.workedDays.toString(), Colors.blue.shade700), //
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
                 Text(formatPercent(stats.livrabiliteRate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: rateColor)), //
              ],
            ),
             const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.livrabiliteRate, //
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

   Widget _buildRemunerationCard(PerformanceData data) { //
    String periodText = _periodOptions[_selectedPeriod] ?? 'Période';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ma Rémunération ($periodText)', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            if (data.remuneration is PiedRemuneration) //
              _buildPiedRemunerationDetails(data.remuneration as PiedRemuneration) //
            else if (data.remuneration is MotoRemuneration) //
              _buildMotoRemunerationDetails(data.remuneration as MotoRemuneration) //
            else
              const Text('Type de rémunération non défini.', style: TextStyle(color: Colors.grey)),

             const Divider(height: 20),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rémunération Totale Estimée:', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(
                      formatAmount(data.remuneration.totalPay), //
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                ],
             )
          ],
        ),
      ),
    );
   }
   
   // --- Widgets de complétion (basés sur les corrections précédentes) ---
   
   Widget _buildDetailRowSimple(String label, String value, {String? subText, String? badgeText, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('$label:', style: const TextStyle(color: Colors.grey)),
              if (subText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text('($subText)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              if (badgeText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
   }


   Widget _buildPiedRemunerationDetails(PiedRemuneration details) { //
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRowSimple('CA (Frais liv.)', formatAmount(details.ca)), //
        _buildDetailRowSimple('Dépenses', formatAmount(details.expenses), subText: formatPercent(details.expenseRatio)), //
        _buildDetailRowSimple('Solde Net', formatAmount(details.netBalance)), //
        _buildDetailRowSimple(
          'Taux Appliqué',
          formatPercent(details.rate), //
          badgeText: details.bonusApplied ? '+5% Bonus' : null, //
          badgeColor: details.bonusApplied ? Colors.green : null, //
        ),
      ],
    );
   }

   Widget _buildMotoRemunerationDetails(MotoRemuneration details) { //
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRowSimple('Salaire de Base', formatAmount(details.baseSalary)), //
        _buildDetailRowSimple('Prime Performance', formatAmount(details.performanceBonus)), //
      ],
    );
   }

   Widget _buildAdminObjectivesCard(AdminObjectives objectives, MotoRemuneration remuneration) { //
     String periodText = _periodOptions[_selectedPeriod] ?? 'Période';
     double percentage = objectives.percentage * 100; //
     Color progressColor = Colors.grey.shade400;
     
     if (objectives.target != null && objectives.target! > 0) { //
        if (objectives.achieved >= objectives.bonusThreshold) { // Eligible
            if(percentage >= 100) { progressColor = Colors.green; }
            else if (percentage >= 85) { progressColor = Colors.blue; }
            else { progressColor = Colors.cyan; }
        } else { // Non eligible
            progressColor = Colors.orange;
        }
     }


    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Objectifs Admin ($periodText)', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            
            _buildDetailRowSimple(
              'Objectif ($periodText)',
              objectives.target?.toString() ?? 'Non Défini', //
            ),
            _buildDetailRowSimple(
              'Courses Réalisées',
              objectives.achieved.toString(), //
            ),
            const SizedBox(height: 10),

            // Barre de Progression
            Row(
              children: [
                 Icon(Icons.military_tech_outlined, color: progressColor),
                 const SizedBox(width: 8),
                 const Text('Progression:', style: TextStyle(fontWeight: FontWeight.w500)),
                 const Spacer(),
                 Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: progressColor)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: min(objectives.percentage, 1.0), // Clampe la valeur à 1.0
              backgroundColor: Colors.grey.shade300,
              color: progressColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            
            const Divider(height: 20),
             // Bonus potentiel
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Prime de performance estimée:', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(
                      formatAmount(remuneration.performanceBonus), //
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                    ),
                ],
             )

          ],
        ),
      ),
    );
   }

   Widget _buildPersonalGoalsCard(PersonalGoals goals, PerformanceStats stats) { //
    int dailyGoal = goals.daily ?? 0; //
    double dailyProgress = dailyGoal > 0 ? min(stats.delivered / dailyGoal, 1.0) : 0.0; //
    Color dailyProgressColor = dailyProgress >= 1.0 ? Colors.green : (dailyProgress > 0.5 ? Colors.blue : AppTheme.primaryColor); //

    return Card(
      color: _isEditingGoals ? AppTheme.background : null, //
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mes Objectifs Personnels',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: Icon(
                    _isEditingGoals ? Icons.close : Icons.edit,
                    color: _isEditingGoals ? AppTheme.danger : AppTheme.secondaryColor, //
                  ),
                  onPressed: () => _toggleEditGoals(goals), //
                ),
              ],
            ),
            const Divider(height: 16),
            
            if (_isEditingGoals)
              ...[
                _buildGoalEditField('Objectif Quotidien', _dailyGoalController, Icons.calendar_view_day),
                _buildGoalEditField('Objectif Hebdomadaire', _weeklyGoalController, Icons.calendar_view_week),
                _buildGoalEditField('Objectif Mensuel', _monthlyGoalController, Icons.calendar_view_month),
                const SizedBox(height: 10),
                if (_editGoalsFeedback.isNotEmpty)
                   Text(_editGoalsFeedback, style: TextStyle(color: _editGoalsFeedback.startsWith('Erreur') ? AppTheme.danger : Colors.green)), //
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingGoals ? null : _savePersonalGoals,
                    icon: _isSavingGoals ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(_isSavingGoals ? 'Sauvegarde en cours...' : 'Sauvegarder'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, foregroundColor: Colors.white), //
                  ),
                ),
              ]
            else
              ...[
                _buildGoalDisplayRow('Objectif Quotidien', goals.daily, stats.delivered, dailyProgressColor, dailyProgress), //
                _buildGoalDisplayRow('Objectif Hebdomadaire', goals.weekly, stats.deliveredCurrentWeek, null, null), //
                _buildDetailRowSimple('Objectif Mensuel', goals.monthly?.toString() ?? 'Non défini'), //
              ]
          ],
        ),
      ),
    );
   }

   Widget _buildGoalEditField(String label, TextEditingController controller, IconData icon) {
     return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
   }

   Widget _buildGoalDisplayRow(String label, int? goal, int achieved, Color? progressColor, double? progressValue) {
      String goalText = goal?.toString() ?? 'Non défini';
      String achievedText = '$achieved';
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label:', style: const TextStyle(color: Colors.grey)),
              Text(goalText, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Réalisé:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(achievedText, style: TextStyle(fontWeight: FontWeight.bold, color: progressColor ?? AppTheme.secondaryColor)), //
            ],
          ),
          if (progressValue != null)
             Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 8.0),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.shade300,
                color: progressColor,
                minHeight: 5,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const Divider(height: 10),
        ],
      );
   }

   Widget _buildChartCard(ChartData chartData) { //
    if (chartData.labels.isEmpty || chartData.data.isEmpty) { //
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('Aucune donnée de graphique disponible pour cette période.', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réalisations par Période', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 200, // Hauteur fixe pour le graphique
              child: BarChart(
                BarChartData(
                  barGroups: chartData.data.asMap().entries.map((entry) { //
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(), //
                          color: AppTheme.primaryColor, //
                          width: 15,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: [],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < chartData.labels.length) { //
                             // Affichage des labels tous les deux éléments si la liste est longue (> 7)
                             if(chartData.labels.length > 7 && value.toInt() % 2 != 0) return const SizedBox.shrink(); //
                             return SideTitleWidget(
                               angle: -0.8, 
                               space: 4,
                               axisSide: meta.axisSide,
                               child: Text(chartData.labels[value.toInt()], style: const TextStyle(fontSize: 10)), //
                             );
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1, 
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30, 
                        interval: (chartData.data.reduce(max) / 5).ceil().toDouble(), //
                        getTitlesWidget: (value, meta) {
                           return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        }
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                  ),
                  maxY: (chartData.data.reduce(max) * 1.1).ceilToDouble(), //
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${chartData.labels[group.x.toInt()]}:\n', //
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: rod.toY.toInt().toString(),
                              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14), //
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
   }
}