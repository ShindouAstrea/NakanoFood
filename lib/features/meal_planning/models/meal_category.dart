class MealCategory {
  final String id;
  final String name;
  final String? defaultTime;
  final String color;
  final bool notificationEnabled;
  final int notificationMinutesBefore;
  final bool isCustom;
  final List<int> daysOfWeek;

  const MealCategory({
    required this.id,
    required this.name,
    this.defaultTime,
    this.color = '#2E7D32',
    this.notificationEnabled = false,
    this.notificationMinutesBefore = 15,
    this.isCustom = false,
    this.daysOfWeek = const [],
  });

  factory MealCategory.fromMap(Map<String, dynamic> map) {
    return MealCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      defaultTime: map['default_time'] as String?,
      color: map['color'] as String? ?? '#2E7D32',
      notificationEnabled: (map['notification_enabled'] as int? ?? 0) == 1,
      notificationMinutesBefore:
          map['notification_minutes_before'] as int? ?? 15,
      isCustom: (map['is_custom'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_time': defaultTime,
      'color': color,
      'notification_enabled': notificationEnabled ? 1 : 0,
      'notification_minutes_before': notificationMinutesBefore,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  MealCategory copyWith({
    String? id,
    String? name,
    String? defaultTime,
    String? color,
    bool? notificationEnabled,
    int? notificationMinutesBefore,
    bool? isCustom,
    List<int>? daysOfWeek,
  }) {
    return MealCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultTime: defaultTime ?? this.defaultTime,
      color: color ?? this.color,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      isCustom: isCustom ?? this.isCustom,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }
}
