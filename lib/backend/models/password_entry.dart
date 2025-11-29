class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String website;
  final String notes;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Offline sync fields
  final String? serverId;
  final String? syncStatus; // 'pending', 'synced', 'error'
  final DateTime? lastSyncedAt;

  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.website,
    required this.notes,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.syncStatus,
    this.lastSyncedAt,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      website: (json['website'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
      serverId: json['serverId']?.toString(),
      syncStatus: json['syncStatus'],
      lastSyncedAt: json['lastSyncedAt'] != null 
          ? DateTime.parse(json['lastSyncedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'notes': notes,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'serverId': serverId,
      'syncStatus': syncStatus,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  /// Create a copy of this password entry with modified fields
  PasswordEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? website,
    String? notes,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? serverId,
    String? syncStatus,
    DateTime? lastSyncedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}