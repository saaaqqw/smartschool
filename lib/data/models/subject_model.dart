import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SubjectModel {
  final String id;
  final String title;
  final String colorHex;
  final String iconName;
  final List<UnitModel> units;

  SubjectModel({
    required this.id,
    required this.title,
    required this.colorHex,
    required this.iconName,
    required this.units,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SubjectModel(
      id: doc.id,
      title: data['title'] ?? '',
      colorHex: data['colorHex'] ?? '',
      iconName: data['iconName'] ?? '',
      units: (data['units'] as List? ?? [])
          .map((u) => UnitModel.fromMap(u))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'colorHex': colorHex,
      'iconName': iconName,
      'units': units.map((u) => u.toMap()).toList(),
    };
  }
}

class UnitModel {
  final String title;
  final String iconName;
  final double progress;

  UnitModel({
    required this.title,
    required this.iconName,
    required this.progress,
  });

  factory UnitModel.fromMap(Map<String, dynamic> data) {
    return UnitModel(
      title: data['title'] ?? '',
      iconName: data['iconName'] ?? '',
      progress: (data['progress'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'iconName': iconName,
      'progress': progress,
    };
  }
}
