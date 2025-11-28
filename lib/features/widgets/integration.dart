import 'package:flutter/material.dart';

class Integration {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  bool connected;
  final String category;
  final List<String> scopes;
  final String imagePath;

  Integration({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.connected,
    required this.category,
    required this.scopes,
    required this.imagePath,
  });
}