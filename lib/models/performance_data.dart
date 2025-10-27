// lib/models/performance_data.dart

// import 'package:flutter/material.dart'; // Supprimé: L'importation n'est pas utilisée dans ce modèle

// Classe principale contenant toutes les données de performance
class PerformanceData {
  final QueryPeriod queryPeriod;
  final String? riderType; // 'pied' or 'moto' or null
  final RiderDetails details;
  final PerformanceStats stats;
  final RemunerationDetails remuneration;
  final AdminObjectives objectivesAdmin;
  final PersonalGoals personalGoals;
  final ChartData chartData;

  PerformanceData({
    required this.queryPeriod,
    this.riderType,
    required this.details,
    required this.stats,
    required this.remuneration,
    required this.objectivesAdmin,
    required this.personalGoals,
    required this.chartData,
  });

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    // Détermine le type de rémunération à parser
    RemunerationDetails remuneration;
    String? riderType = json['riderType'] as String?;
    if (riderType == 'pied') {
      remuneration = PiedRemuneration.fromJson(json['remuneration'] as Map<String, dynamic>);
    } else if (riderType == 'moto') {
      remuneration = MotoRemuneration.fromJson(json['remuneration'] as Map<String, dynamic>);
    } else {
      // Cas par défaut ou inconnu
      remuneration = UnknownRemuneration();
    }

    return PerformanceData(
      queryPeriod: QueryPeriod.fromJson(json['queryPeriod'] as Map<String, dynamic>),
      riderType: riderType,
      details: RiderDetails.fromJson(json['details'] as Map<String, dynamic>),
      stats: PerformanceStats.fromJson(json['stats'] as Map<String, dynamic>),
      remuneration: remuneration,
      objectivesAdmin: AdminObjectives.fromJson(json['objectivesAdmin'] as Map<String, dynamic>),
      personalGoals: PersonalGoals.fromJson(json['personalGoals'] as Map<String, dynamic>? ?? {}),
      chartData: ChartData.fromJson(json['chartData'] as Map<String, dynamic>),
    );
  }
}

// --- Sous-classes pour chaque partie du JSON ---

class QueryPeriod {
  final String code;
  final String startDate;
  final String endDate;

  QueryPeriod({required this.code, required this.startDate, required this.endDate});

  factory QueryPeriod.fromJson(Map<String, dynamic> json) {
    return QueryPeriod(
      code: json['code'] as String? ?? 'unknown',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
    );
  }
}

class RiderDetails {
  final String name;
  final String status;

  RiderDetails({required this.name, required this.status});

  factory RiderDetails.fromJson(Map<String, dynamic> json) {
    return RiderDetails(
      name: json['name'] as String? ?? 'Inconnu',
      status: json['status'] as String? ?? 'inactif',
    );
  }
}

class PerformanceStats {
  final int received;
  final int delivered;
  final double livrabiliteRate;
  final int workedDays;
  final double caDeliveryFees;
  final int deliveredCurrentWeek;
  final double totalExpenses;

  PerformanceStats({
    required this.received,
    required this.delivered,
    required this.livrabiliteRate,
    required this.workedDays,
    required this.caDeliveryFees,
    required this.deliveredCurrentWeek,
    required this.totalExpenses,
  });

  factory PerformanceStats.fromJson(Map<String, dynamic> json) {
    return PerformanceStats(
      received: (json['received'] as num? ?? 0).toInt(),
      delivered: (json['delivered'] as num? ?? 0).toInt(),
      livrabiliteRate: (json['livrabilite_rate'] as num? ?? 0).toDouble(),
      workedDays: (json['workedDays'] as num? ?? 0).toInt(),
      caDeliveryFees: (json['ca_delivery_fees'] as num? ?? 0).toDouble(),
      deliveredCurrentWeek: (json['deliveredCurrentWeek'] as num? ?? 0).toInt(),
      totalExpenses: (json['total_expenses'] as num? ?? 0).toDouble(),
    );
  }
}

// Classe abstraite pour la rémunération
abstract class RemunerationDetails {
  final double totalPay;
  RemunerationDetails({required this.totalPay});
}

// Rémunération pour livreur à pied
class PiedRemuneration extends RemunerationDetails {
  final double ca;
  final double expenses;
  final double netBalance;
  final double expenseRatio;
  final double rate;
  final bool bonusApplied;

  PiedRemuneration({
    required this.ca,
    required this.expenses,
    required this.netBalance,
    required this.expenseRatio,
    required this.rate,
    required this.bonusApplied,
    required super.totalPay, // Utilisation de super parameter
  });

  factory PiedRemuneration.fromJson(Map<String, dynamic> json) {
    return PiedRemuneration(
      ca: (json['ca'] as num? ?? 0).toDouble(),
      expenses: (json['expenses'] as num? ?? 0).toDouble(),
      netBalance: (json['netBalance'] as num? ?? 0).toDouble(),
      expenseRatio: (json['expenseRatio'] as num? ?? 0).toDouble(),
      rate: (json['rate'] as num? ?? 0).toDouble(),
      bonusApplied: json['bonusApplied'] as bool? ?? false,
      totalPay: (json['totalPay'] as num? ?? 0).toDouble(),
    );
  }
}

// Rémunération pour livreur moto
class MotoRemuneration extends RemunerationDetails {
  final double baseSalary;
  final double performanceBonus;

  MotoRemuneration({
    required this.baseSalary,
    required this.performanceBonus,
    required super.totalPay, // Utilisation de super parameter
  });

  factory MotoRemuneration.fromJson(Map<String, dynamic> json) {
    return MotoRemuneration(
      baseSalary: (json['baseSalary'] as num? ?? 0).toDouble(),
      performanceBonus: (json['performanceBonus'] as num? ?? 0).toDouble(),
      totalPay: (json['totalPay'] as num? ?? 0).toDouble(),
    );
  }
}

// Rémunération inconnue ou par défaut
class UnknownRemuneration extends RemunerationDetails {
  UnknownRemuneration() : super(totalPay: 0);
}


class AdminObjectives {
  final int? target;
  final int achieved;
  final double percentage;
  final double bonusPerDelivery;
  final double bonusThreshold;

  AdminObjectives({
    this.target,
    required this.achieved,
    required this.percentage,
    required this.bonusPerDelivery,
    required this.bonusThreshold,
  });

  factory AdminObjectives.fromJson(Map<String, dynamic> json) {
    return AdminObjectives(
      target: (json['target'] as num?)?.toInt(),
      achieved: (json['achieved'] as num? ?? 0).toInt(),
      percentage: (json['percentage'] as num? ?? 0).toDouble(),
      bonusPerDelivery: (json['bonusPerDelivery'] as num? ?? 0).toDouble(),
      bonusThreshold: (json['bonusThreshold'] as num? ?? 0).toDouble(),
    );
  }
}

class PersonalGoals {
  final int? daily;
  final int? weekly;
  final int? monthly;

  PersonalGoals({this.daily, this.weekly, this.monthly});

  factory PersonalGoals.fromJson(Map<String, dynamic> json) {
    return PersonalGoals(
      daily: (json['daily'] as num?)?.toInt(),
      weekly: (json['weekly'] as num?)?.toInt(),
      monthly: (json['monthly'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily': daily,
      'weekly': weekly,
      'monthly': monthly,
    };
  }
}

class ChartData {
  final List<String> labels;
  final List<int> data;

  ChartData({required this.labels, required this.data});

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      labels: List<String>.from((json['labels'] as List<dynamic>? ?? []).map((e) => e.toString())),
      data: List<int>.from((json['data'] as List<dynamic>? ?? []).map((e) => (e as num? ?? 0).toInt())),
    );
  }
}