import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Voice Command Shortcuts Service
/// Manages custom voice commands and quick actions
class VoiceShortcutsService {
  static const String _storageKey = 'voice_shortcuts';
  
  // Predefined shortcuts
  static final List<VoiceShortcut> defaultShortcuts = [
    VoiceShortcut(
      id: 'home',
      trigger: ['отведи домой', 'домой', 'go home', 'take me home'],
      action: ShortcutAction.navigateHome,
      icon: Icons.home,
      color: const Color(0xFF00D4FF),
      description: 'Navigate to home',
    ),
    VoiceShortcut(
      id: 'work',
      trigger: ['на работу', 'к работе', 'go to work', 'to work'],
      action: ShortcutAction.navigateWork,
      icon: Icons.work,
      color: const Color(0xFF00E676),
      description: 'Navigate to work',
    ),
    VoiceShortcut(
      id: 'scan',
      trigger: ['что вижу', 'что передо мной', 'опиши', 'what do i see', 'describe'],
      action: ShortcutAction.scanEnvironment,
      icon: Icons.remove_red_eye,
      color: const Color(0xFFFF2E63),
      description: 'Scan environment',
    ),
    VoiceShortcut(
      id: 'read_text',
      trigger: ['прочитай текст', 'читай', 'read text', 'read this'],
      action: ShortcutAction.readText,
      icon: Icons.text_fields,
      color: const Color(0xFFFFB800),
      description: 'Read text from image',
    ),
    VoiceShortcut(
      id: 'emergency',
      trigger: ['помощь', 'срочно', 'emergency', 'help'],
      action: ShortcutAction.emergency,
      icon: Icons.emergency,
      color: const Color(0xFFFF0000),
      description: 'Emergency assistance',
    ),
    VoiceShortcut(
      id: 'weather',
      trigger: ['погода', 'какая погода', 'weather', 'what\'s the weather'],
      action: ShortcutAction.getWeather,
      icon: Icons.wb_sunny,
      color: const Color(0xFFFFA726),
      description: 'Get weather info',
    ),
    VoiceShortcut(
      id: 'nearby',
      trigger: ['что рядом', 'поблизости', 'nearby', 'what\'s around'],
      action: ShortcutAction.findNearby,
      icon: Icons.place,
      color: const Color(0xFF9C27B0),
      description: 'Find nearby places',
    ),
    VoiceShortcut(
      id: 'call',
      trigger: ['позвони', 'звонок', 'call', 'phone'],
      action: ShortcutAction.makeCall,
      icon: Icons.phone,
      color: const Color(0xFF4CAF50),
      description: 'Make a phone call',
    ),
  ];

  /// Match voice input to a shortcut
  static VoiceShortcut? matchCommand(String input) {
    final lowerInput = input.toLowerCase().trim();
    
    for (final shortcut in defaultShortcuts) {
      for (final trigger in shortcut.trigger) {
        if (lowerInput.contains(trigger.toLowerCase())) {
          return shortcut;
        }
      }
    }
    
    return null;
  }

  /// Save custom shortcuts
  static Future<void> saveCustomShortcuts(List<VoiceShortcut> shortcuts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = shortcuts.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Load custom shortcuts
  static Future<List<VoiceShortcut>> loadCustomShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => VoiceShortcut.fromJson(json)).toList();
  }
}

enum ShortcutAction {
  navigateHome,
  navigateWork,
  scanEnvironment,
  readText,
  emergency,
  getWeather,
  findNearby,
  makeCall,
  custom,
}

class VoiceShortcut {
  final String id;
  final List<String> trigger;
  final ShortcutAction action;
  final IconData icon;
  final Color color;
  final String description;
  final Map<String, dynamic>? customData;

  VoiceShortcut({
    required this.id,
    required this.trigger,
    required this.action,
    required this.icon,
    required this.color,
    required this.description,
    this.customData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger,
    'action': action.toString(),
    'icon': icon.codePoint,
    'color': color.value,
    'description': description,
    'customData': customData,
  };

  factory VoiceShortcut.fromJson(Map<String, dynamic> json) => VoiceShortcut(
    id: json['id'],
    trigger: List<String>.from(json['trigger']),
    action: ShortcutAction.values.firstWhere(
      (e) => e.toString() == json['action'],
      orElse: () => ShortcutAction.custom,
    ),
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    color: Color(json['color']),
    description: json['description'],
    customData: json['customData'],
  );
}

/// Voice Shortcuts UI Widget
class VoiceShortcutsWidget extends StatelessWidget {
  final Function(VoiceShortcut) onShortcutTap;
  
  const VoiceShortcutsWidget({
    super.key,
    required this.onShortcutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: VoiceShortcutsService.defaultShortcuts.length,
        itemBuilder: (context, index) {
          final shortcut = VoiceShortcutsService.defaultShortcuts[index];
          return _ShortcutCard(
            shortcut: shortcut,
            onTap: () => onShortcutTap(shortcut),
          );
        },
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final VoiceShortcut shortcut;
  final VoidCallback onTap;
  
  const _ShortcutCard({
    required this.shortcut,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  shortcut.color,
                  shortcut.color.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shortcut.color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  shortcut.icon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  shortcut.description.split(' ').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick Actions Floating Menu
class QuickActionsMenu extends StatefulWidget {
  final Function(ShortcutAction) onActionSelected;
  
  const QuickActionsMenu({
    super.key,
    required this.onActionSelected,
  });

  @override
  State<QuickActionsMenu> createState() => _QuickActionsMenuState();
}

class _QuickActionsMenuState extends State<QuickActionsMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = VoiceShortcutsService.defaultShortcuts.take(5).toList();
    
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Action buttons
        ...List.generate(shortcuts.length, (index) {
          final shortcut = shortcuts[index];
          final angle = (index * 30 - 60) * (3.14159 / 180);
          final distance = 80.0;
          
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = Offset(
                -distance * _controller.value * (1 - index * 0.1) * (1 + index * 0.2),
                -distance * _controller.value * (index + 1) * 0.8,
              );
              
              return Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: _controller.value,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'quick_action_$index',
                    backgroundColor: shortcut.color,
                    onPressed: () {
                      widget.onActionSelected(shortcut.action);
                      _toggle();
                    },
                    child: Icon(shortcut.icon, size: 20),
                  ),
                ),
              );
            },
          );
        }),
        
        // Main button
        FloatingActionButton(
          heroTag: 'quick_actions_main',
          onPressed: _toggle,
          backgroundColor: const Color(0xFF00D4FF),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 3.14159 / 4,
                child: Icon(
                  _isExpanded ? Icons.close : Icons.add,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
