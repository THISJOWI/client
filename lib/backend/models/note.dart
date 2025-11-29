class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Offline sync fields
  final String? localId;
  final int? serverId;
  final String? syncStatus; // 'pending', 'synced', 'error'
  final DateTime? lastSyncedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.localId,
    this.serverId,
    this.syncStatus,
    this.lastSyncedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      localId: json['localId'],
      serverId: json['serverId'],
      syncStatus: json['syncStatus'],
      lastSyncedAt: json['lastSyncedAt'] != null 
          ? DateTime.parse(json['lastSyncedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'localId': localId,
      'serverId': serverId,
      'syncStatus': syncStatus,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  /// Create a copy of this note with modified fields
  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? localId,
    int? serverId,
    String? syncStatus,
    DateTime? lastSyncedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}