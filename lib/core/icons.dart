import 'package:flutter/material.dart';

/// أسماء الأيقونات المخزنة في القواعد ← أيقونات Material.
IconData iconFor(String name) => switch (name) {
  'prayer' => Icons.mosque_outlined,
  'sun' => Icons.wb_sunny_outlined,
  'moon' => Icons.nightlight_outlined,
  'book' => Icons.menu_book_outlined,
  'meal' => Icons.restaurant_outlined,
  'walk' => Icons.directions_walk,
  'sport' => Icons.fitness_center,
  'laptop' => Icons.laptop_mac,
  'language' => Icons.translate,
  'water' => Icons.water_drop_outlined,
  'kid' => Icons.school_outlined,
  'class' => Icons.music_note_outlined,
  'work' => Icons.work_outline,
  'check' => Icons.check_box_outlined,
  'event' => Icons.event_outlined,
  'period' => Icons.timelapse,
  'sleep' => Icons.bedtime_outlined,
  'stand' => Icons.accessibility_new,
  'breathe' => Icons.air,
  'bell' => Icons.notifications_none,
  _ => Icons.star_outline,
};

const pickableIcons = [
  'star',
  'book',
  'walk',
  'sport',
  'laptop',
  'language',
  'meal',
  'check',
  'water',
  'sun',
  'moon',
];
