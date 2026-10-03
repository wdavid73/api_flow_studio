import 'package:flutter/material.dart';

/// The accent a project can carry, so `commodo` and `fin_track_pro` are told
/// apart at a glance. Picked to stay readable on the dark surfaces.
const List<Color> projectColors = [
  Color(0xFFA78BFA), // violet
  Color(0xFF86E7B0), // green
  Color(0xFF9EC1FF), // blue
  Color(0xFFFFD27A), // amber
  Color(0xFFFF9E7A), // orange
  Color(0xFFF59EC8), // pink
  Color(0xFF7AE7E0), // teal
  Color(0xFFC4C4D4), // gray
];

/// The color for [index], wrapping around the palette (also for negatives).
Color projectColor(int index) => projectColors[index % projectColors.length];
