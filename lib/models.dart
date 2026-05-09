// Add this to your models.dart file

import 'package:intl/intl.dart';

class UserProfile {
  final String id;
  final String userId;
  final String? fcmToken;
  final String? deviceType;
  final String? deviceModel;
  final String? appVersion;
  final String? osVersion;
  final String language;
  final String? timezone;
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool inAppNotifications;
  final String theme;
  final DateTime? lastActiveAt;
  final DateTime? lastLoginAt;
  final int loginCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    this.fcmToken,
    this.deviceType,
    this.deviceModel,
    this.appVersion,
    this.osVersion,
    required this.language,
    this.timezone,
    required this.notificationsEnabled,
    required this.emailNotifications,
    required this.pushNotifications,
    required this.inAppNotifications,
    required this.theme,
    this.lastActiveAt,
    this.lastLoginAt,
    required this.loginCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      userId: json['user_id'],
      fcmToken: json['fcm_token'],
      deviceType: json['device_type'],
      deviceModel: json['device_model'],
      appVersion: json['app_version'],
      osVersion: json['os_version'],
      language: json['language'] ?? 'en',
      timezone: json['timezone'],
      notificationsEnabled: json['notifications_enabled'] ?? true,
      emailNotifications: json['email_notifications'] ?? true,
      pushNotifications: json['push_notifications'] ?? true,
      inAppNotifications: json['in_app_notifications'] ?? true,
      theme: json['theme'] ?? 'light',
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'])
          : null,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      loginCount: json['login_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'fcm_token': fcmToken,
      'device_type': deviceType,
      'device_model': deviceModel,
      'app_version': appVersion,
      'os_version': osVersion,
      'language': language,
      'timezone': timezone,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'in_app_notifications': inAppNotifications,
      'theme': theme,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'login_count': loginCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fcmToken,
    String? deviceType,
    String? deviceModel,
    String? appVersion,
    String? osVersion,
    String? language,
    String? timezone,
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? inAppNotifications,
    String? theme,
    DateTime? lastActiveAt,
    DateTime? lastLoginAt,
    int? loginCount,
  }) {
    return UserProfile(
      id: id,
      userId: userId,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceType: deviceType ?? this.deviceType,
      deviceModel: deviceModel ?? this.deviceModel,
      appVersion: appVersion ?? this.appVersion,
      osVersion: osVersion ?? this.osVersion,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      inAppNotifications: inAppNotifications ?? this.inAppNotifications,
      theme: theme ?? this.theme,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginCount: loginCount ?? this.loginCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get hasNotificationsEnabled => notificationsEnabled;
  bool get canReceiveEmailNotifications =>
      notificationsEnabled && emailNotifications;
  bool get canReceivePushNotifications =>
      notificationsEnabled && pushNotifications && fcmToken != null;
  bool get canReceiveInAppNotifications =>
      notificationsEnabled && inAppNotifications;

  String get deviceDisplayName {
    if (deviceModel != null) {
      return deviceModel!;
    } else if (deviceType != null) {
      return deviceType!.toUpperCase();
    } else {
      return 'Unknown Device';
    }
  }

  bool get isRecentlyActive {
    if (lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt!).inMinutes < 30;
  }
}

enum UserType {
  systemAdmin('system_admin'),
  superAdmin('super_admin'),
  admin('admin'),
  branchAdmin('branch_admin'), // NEW
  superUser('super_user'),
  user('user');

  const UserType(this.value);
  final String value;

  static UserType fromString(String value) {
    return UserType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserType.user,
    );
  }
}

// Add this method to BranchAdminPlace class in models.dart
class BranchAdminPlace {
  final String id;
  final String adminId;
  final String placeId;
  final String? createdBy;
  final DateTime createdAt;

  BranchAdminPlace({
    required this.id,
    required this.adminId,
    required this.placeId,
    this.createdBy,
    required this.createdAt,
  });

  factory BranchAdminPlace.fromJson(Map<String, dynamic> json) {
    return BranchAdminPlace(
      id: json['id'],
      adminId: json['admin_id'],
      placeId: json['place_id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'place_id': placeId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum TicketStatus {
  pending('pending'),
  inprogress('inprogress'),
  prefinished('prefinished'),
  closed('closed'),
  deleted('deleted'),
  wrongInfo('wrong_info');

  const TicketStatus(this.value);
  final String value;
}

enum PriorityType {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const PriorityType(this.value);
  final String value;
}

class UserModel {
  final String id;
  final String? authId;
  final String email;
  final String fullName;
  final String? phone;
  final UserType userType;
  final String? departmentId;
  final String? placeId;
  final List<String>? natureOfWork;
  final bool isActive;
  final bool isDeleted;
  final String language;
  final String? profileImageUrl; // Add this field
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    this.authId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.userType,
    this.departmentId,
    this.placeId,
    this.natureOfWork,
    required this.isActive,
    this.isDeleted = false,
    required this.language,
    this.profileImageUrl, // Add this parameter
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      authId: json['auth_id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      userType: UserType.values.firstWhere((e) => e.value == json['user_type']),
      departmentId: json['department_id'],
      placeId: json['place_id'],
      natureOfWork: json['nature_of_work']?.cast<String>(),
      isActive: json['is_active'],
      isDeleted: json['is_deleted'] ?? false,
      language: json['language'] ?? 'en',
      profileImageUrl: json['profile_image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'user_type': userType.value,
      'department_id': departmentId,
      'place_id': placeId,
      'nature_of_work': natureOfWork,
      'is_active': isActive,
      'is_deleted': isDeleted,
      'language': language,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? profileImageUrl,
    String? fullName,
    String? phone,
    String? language,
    bool? isDeleted,
  }) {
    return UserModel(
      id: id,
      authId: authId,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      userType: userType,
      departmentId: departmentId,
      placeId: placeId,
      natureOfWork: natureOfWork,
      isActive: isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      language: language ?? this.language,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class DepartmentModel {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameAr;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DepartmentModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameAr,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    if (languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    return name;
  }

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      description: json['description'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class PlaceModel {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameAr;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaceModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameAr,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    if (languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    return name;
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      description: json['description'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class TicketModel {
  final String id;
  final String ticketNumber;
  final String title;
  final String description;
  final String targetDepartmentId;
  final String? natureOfProblem;
  final String? natureOfWorkId;
  final String? otherNatureOfWork;
  final String? placeId;
  final String? otherPlace;
  final String? location;
  final String? problemTitleId;
  final String? customProblemTitle;
  final String? otherProblemTitle;
  final PriorityType priority;
  final String? highPriorityExplain;
  final String? modelNumberId;
  final String? customModelNumber;
  final String? otherModelNumber;
  final TicketStatus status;
  final String createdBy;
  final String? creatorPhone;
  final String? assignedTo;
  final String? parentTicketId;
  final bool underSupervision; // NEW FIELD
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.description,
    required this.targetDepartmentId,
    this.natureOfProblem,
    this.natureOfWorkId,
    this.otherNatureOfWork,
    this.placeId,
    this.otherPlace,
    this.location,
    this.problemTitleId,
    this.customProblemTitle,
    this.otherProblemTitle,
    required this.priority,
    this.highPriorityExplain,
    this.modelNumberId,
    this.customModelNumber,
    this.otherModelNumber,
    required this.status,
    required this.createdBy,
    this.creatorPhone,
    this.assignedTo,
    this.parentTicketId,
    this.underSupervision = false, // NEW FIELD WITH DEFAULT
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'],
      ticketNumber: json['ticket_number'],
      title: json['title'],
      description: json['description'],
      targetDepartmentId: json['target_department_id'],
      natureOfProblem: json['nature_of_problem'],
      natureOfWorkId: json['nature_of_work_id'],
      otherNatureOfWork: json['other_nature_of_work'],
      placeId: json['place_id'],
      otherPlace: json['other_place'],
      location: json['location'],
      problemTitleId: json['problem_title_id'],
      customProblemTitle: json['custom_problem_title'],
      otherProblemTitle: json['other_problem_title'],
      priority:
          PriorityType.values.firstWhere((e) => e.value == json['priority']),
      highPriorityExplain: json['high_priority_explain'],
      modelNumberId: json['model_number_id'],
      customModelNumber: json['custom_model_number'],
      otherModelNumber: json['other_model_number'],
      status: TicketStatus.values.firstWhere((e) => e.value == json['status']),
      createdBy: json['created_by'],
      creatorPhone: json['creator_phone'],
      assignedTo: json['assigned_to'],
      parentTicketId: json['parent_ticket_id'],
      underSupervision: json['under_supervision'] ?? false, // NEW FIELD
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
// Add to models.dart

class TicketTrackingPoint {
  final String id;
  final String ticketId;
  final String createdBy;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String description;
  final String pointType; // 'visit' or 'note'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorName;

  TicketTrackingPoint({
    required this.id,
    required this.ticketId,
    required this.createdBy,
    this.checkInTime,
    this.checkOutTime,
    required this.description,
    required this.pointType,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
  });

  factory TicketTrackingPoint.fromJson(Map<String, dynamic> json) {
    return TicketTrackingPoint(
      id: json['id'],
      ticketId: json['ticket_id'],
      createdBy: json['created_by'],
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'])
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'])
          : null,
      description: json['description'],
      pointType: json['point_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      creatorName: json['creator_name'],
    );
  }

  Duration? get duration {
    if (checkInTime != null && checkOutTime != null) {
      return checkOutTime!.difference(checkInTime!);
    }
    return null;
  }

  String get formattedDuration {
    final dur = duration;
    if (dur == null) return 'N/A';

    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class ChatMessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String message;
  final List<String>? mentionedUsers;
  final DateTime createdAt;
  final String? senderName;
  final String? senderProfileImage;
  final bool isPending;

  ChatMessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.message,
    this.mentionedUsers,
    required this.createdAt,
    this.senderName,
    this.senderProfileImage,
    this.isPending = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      chatRoomId: json['chat_room_id'],
      senderId: json['sender_id'],
      message: json['message'],
      mentionedUsers: json['mentioned_users']?.cast<String>(),
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender_name'],
      senderProfileImage: json['sender_profile_image'], // Add this line
    );
  }
}

class AutoAssignmentSettings {
  final String id;
  final String departmentId;
  final bool isEnabled;
  final String? assignedAdminId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutoAssignmentSettings({
    required this.id,
    required this.departmentId,
    required this.isEnabled,
    this.assignedAdminId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutoAssignmentSettings.fromJson(Map<String, dynamic> json) {
    return AutoAssignmentSettings(
      id: json['id'],
      departmentId: json['department_id'],
      isEnabled: json['is_enabled'] ?? false,
      assignedAdminId: json['assigned_admin_id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class NotificationPreferences {
  final String id;
  final String userId;
  final bool pushNotificationsEnabled;
  final bool pushChatMessagesEnabled;
  final bool emailNotificationsEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferences({
    required this.id,
    required this.userId,
    required this.pushNotificationsEnabled,
    required this.pushChatMessagesEnabled,
    required this.emailNotificationsEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['id'],
      userId: json['user_id'],
      pushNotificationsEnabled: json['push_notifications_enabled'] ?? true,
      pushChatMessagesEnabled: json['push_chat_messages_enabled'] ?? true,
      emailNotificationsEnabled: json['email_notifications_enabled'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'push_notifications_enabled': pushNotificationsEnabled,
      'push_chat_messages_enabled': pushChatMessagesEnabled,
      'email_notifications_enabled': emailNotificationsEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Add to models.dart

class NatureOfWorkModel {
  final String id;
  final String departmentId;
  final String name;
  final String? nameEn;
  final String? nameAr;
  final String? description;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  NatureOfWorkModel({
    required this.id,
    required this.departmentId,
    required this.name,
    this.nameEn,
    this.nameAr,
    this.description,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    if (languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    return name;
  }

  factory NatureOfWorkModel.fromJson(Map<String, dynamic> json) {
    return NatureOfWorkModel(
      id: json['id'],
      departmentId: json['department_id'],
      name: json['name'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AdminWithNatureOfWork {
  final String adminId;
  final String fullName;
  final String email;
  final bool matchingNatureOfWork;
  final List<String> natureOfWorkNames;

  AdminWithNatureOfWork({
    required this.adminId,
    required this.fullName,
    required this.email,
    required this.matchingNatureOfWork,
    required this.natureOfWorkNames,
  });

  factory AdminWithNatureOfWork.fromJson(Map<String, dynamic> json) {
    return AdminWithNatureOfWork(
      adminId: json['admin_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      matchingNatureOfWork: json['matching_nature_of_work'] as bool? ?? false,
      natureOfWorkNames: (json['nature_of_work_names'] as List<dynamic>?)
              ?.where((e) => e != null)
              .map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

enum ComplaintStatus {
  pending,
  inprogress,
  prefinished,
  checked;

  String get value => name;

  static ComplaintStatus fromString(String value) {
    return ComplaintStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ComplaintStatus.pending,
    );
  }
}

enum ComplaintType {
  technical,
  coordination_delivery;

  String get value => name;
  String get displayName {
    switch (this) {
      case ComplaintType.technical:
        return 'Technical';
      case ComplaintType.coordination_delivery:
        return 'Coordination / Delivery';
    }
  }

  static ComplaintType fromString(String value) {
    return ComplaintType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ComplaintType.technical,
    );
  }
}

class ComplaintItemModel {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameAr;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  ComplaintItemModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameAr,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    if (languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    return name;
  }

  factory ComplaintItemModel.fromJson(Map<String, dynamic> json) {
    return ComplaintItemModel(
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_en': nameEn,
      'name_ar': nameAr,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ComplaintTicketModel {
  final String id;
  final String complaintNumber;
  final DateTime date;
  final String complaintReceiver;
  final String complainantName;
  final String location;
  final String mobileNumber;
  final String? phoneNumber;
  final String? itemId;
  final String? itemName;
  final String? batchNumber;
  final double? quantity;
  final DateTime? produceDate;
  final DateTime? expiredDate;
  final String description;
  final ComplaintType complaintType;
  final ComplaintStatus status;
  final String createdBy;
  final String? assignedTo;
  final String? departmentId; // Changed to nullable
  final DateTime createdAt;
  final DateTime updatedAt;

  ComplaintTicketModel({
    required this.id,
    required this.complaintNumber,
    required this.date,
    required this.complaintReceiver,
    required this.complainantName,
    required this.location,
    required this.mobileNumber,
    this.phoneNumber,
    this.itemId,
    this.itemName,
    this.batchNumber,
    this.quantity,
    this.produceDate,
    this.expiredDate,
    required this.description,
    required this.complaintType,
    required this.status,
    required this.createdBy,
    this.assignedTo,
    this.departmentId, // Now nullable
    required this.createdAt,
    required this.updatedAt,
  });

  factory ComplaintTicketModel.fromJson(Map<String, dynamic> json) {
    return ComplaintTicketModel(
      id: json['id']?.toString() ?? '',
      complaintNumber: json['complaint_number']?.toString() ?? 'N/A',
      date: json['date'] != null
          ? DateTime.parse(json['date']).toLocal()
          : DateTime.now(),
      complaintReceiver: json['complaint_receiver']?.toString() ?? 'Unknown',
      complainantName: json['complainant_name']?.toString() ?? 'Unknown',
      location: json['location']?.toString() ?? 'Unknown Location',
      mobileNumber: json['mobile_number']?.toString() ?? 'N/A',
      phoneNumber: json['phone_number']?.toString(),
      itemId: json['item_id']?.toString(),
      itemName: json['item_name']?.toString() ?? 'Unknown Item',
      batchNumber: json['batch_number']?.toString(),
      quantity: json['quantity']?.toDouble(),
      produceDate: json['produce_date'] != null
          ? DateTime.parse(json['produce_date']).toLocal()
          : null,
      expiredDate: json['expired_date'] != null
          ? DateTime.parse(json['expired_date']).toLocal()
          : null,
      description: json['description']?.toString() ?? '',
      complaintType: ComplaintType.values.firstWhere(
        (e) => e.value == (json['complaint_type'] ?? 'technical'),
        orElse: () => ComplaintType.technical,
      ),
      status: ComplaintStatus.values.firstWhere(
        (e) => e.value == (json['status'] ?? 'pending'),
        orElse: () => ComplaintStatus.pending,
      ),
      createdBy: json['created_by']?.toString() ?? '',
      assignedTo: json['assigned_to']?.toString(),
      // Handle null/empty department_id properly
      departmentId: (json['department_id'] == null ||
              json['department_id'].toString().isEmpty)
          ? null
          : json['department_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Add a helper method to check if department is assigned
  bool get hasDepartment => departmentId != null && departmentId!.isNotEmpty;

  // Add formatted date for display
  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(date);

  String get formattedCreatedAt =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);

  String get formattedUpdatedAt =>
      DateFormat('dd/MM/yyyy HH:mm').format(updatedAt);
}

class ComplaintCheckModel {
  final String id;
  final String complaintId;
  final bool complaintCheck;
  final String checkerId;
  final String checkerName;
  final String report;
  final DateTime checkDate;
  final String? therapeuticProcedure;
  final String? signedDocumentPath;
  final DateTime createdAt;

  ComplaintCheckModel({
    required this.id,
    required this.complaintId,
    required this.complaintCheck,
    required this.checkerId,
    required this.checkerName,
    required this.report,
    required this.checkDate,
    this.therapeuticProcedure,
    this.signedDocumentPath,
    required this.createdAt,
  });

  factory ComplaintCheckModel.fromJson(Map<String, dynamic> json) {
    return ComplaintCheckModel(
      id: json['id'],
      complaintId: json['complaint_id'],
      complaintCheck: json['complaint_check'],
      checkerId: json['checker_id'],
      checkerName: json['checker_name'],
      report: json['report'],
      checkDate: DateTime.parse(json['check_date']),
      therapeuticProcedure: json['therapeutic_procedure'],
      signedDocumentPath: json['signed_document_path'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get formattedCheckDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(checkDate);
}
