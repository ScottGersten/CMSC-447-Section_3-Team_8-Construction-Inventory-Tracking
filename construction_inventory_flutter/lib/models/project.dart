import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { active, completed, onHold }

class Project {
  final String projectId;
  final String name;
  final String address; // jobsite physical address
  final ProjectStatus status;
  final DateTime startDate;
  final DateTime? endDate;

  Project({
    required this.projectId,
    required this.name,
    required this.address,
    required this.status,
    required this.startDate,
    this.endDate,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Project(
      projectId: doc.id,
      name: data['name'] as String,
      address: data['address'] as String,
      status: _statusFromString(data['status'] as String),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'status': _statusToString(status),
      'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
    };
  }

  static ProjectStatus _statusFromString(String s) {
    switch (s) {
      case 'Completed':
        return ProjectStatus.completed;
      case 'OnHold':
        return ProjectStatus.onHold;
      default:
        return ProjectStatus.active;
    }
  }

  static String _statusToString(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.onHold:
        return 'OnHold';
      default:
        return 'Active';
    }
  }
}

/// Links a user to a project with a specific role on that project.
class ProjectAssignment {
  final String assignmentId;
  final String projectId; // foreign key -> projects
  final String userId; // foreign key -> users
  final String role; // role on this specific project
  final DateTime assignedAt;

  ProjectAssignment({
    required this.assignmentId,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.assignedAt,
  });

  factory ProjectAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectAssignment(
      assignmentId: doc.id,
      projectId: data['projectId'] as String,
      userId: data['userId'] as String,
      role: data['role'] as String,
      assignedAt: (data['assignedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'userId': userId,
      'role': role,
      'assignedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Tracks budgeted vs. received vs. installed quantities per material per project.
class ProjectMaterial {
  final String projectMaterialId;
  final String projectId; // foreign key -> projects
  final String materialId; // foreign key -> materials
  final double quantityBudgeted;
  final double quantityReceived; // system-updated on delivery confirmation
  final double quantityInstalled; // system-updated on installation log

  ProjectMaterial({
    required this.projectMaterialId,
    required this.projectId,
    required this.materialId,
    required this.quantityBudgeted,
    this.quantityReceived = 0.0,
    this.quantityInstalled = 0.0,
  });

  factory ProjectMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectMaterial(
      projectMaterialId: doc.id,
      projectId: data['projectId'] as String,
      materialId: data['materialId'] as String,
      quantityBudgeted: (data['quantityBudgeted'] as num).toDouble(),
      quantityReceived: (data['quantityReceived'] as num? ?? 0).toDouble(),
      quantityInstalled: (data['quantityInstalled'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'materialId': materialId,
      'quantityBudgeted': quantityBudgeted,
      'quantityReceived': quantityReceived,
      'quantityInstalled': quantityInstalled,
    };
  }
}