import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Helper method to safely get localization with fallback
  static AppLocalizations safeOf(BuildContext context) {
    final l10n = of(context);
    if (l10n != null) {
      return l10n;
    }

    // Return a default instance if not found (shouldn't happen in normal usage)
    return AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': _enValues,
    'ar': _arValues,
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters for easy access
  String get update => translate('update');
  String get appName => translate('app_name');
  String get welcomeBack => translate('welcome_back');
  String get dashboard => translate('dashboard');
  String get tickets => translate('tickets');
  String get chat => translate('chat');
  String get notifications => translate('notifications');
  String get complaints => translate('complaints');
  String get management => translate('management');
  String get profile => translate('profile');
  String get signIn => translate('sign_in');
  String get signOut => translate('sign_out');
  String get register => translate('register');
  String get email => translate('email');
  String get password => translate('password');
  String get confirmPassword => translate('confirm_password');
  String get fullName => translate('full_name');
  String get phone => translate('phone');
  String get language => translate('language');
  String get selectYourPlace => translate('select_your_place');
  String get createAccount => translate('create_account');
  String get alreadyHaveAccount => translate('already_have_account');
  String get dontHaveAccount => translate('dont_have_account');
  String get signInHere => translate('sign_in_here');
  String get registerHere => translate('register_here');
  String get loading => translate('loading');
  String get loadingDashboard => translate('loading_dashboard');
  String get pending => translate('pending');
  String get inProgress => translate('in_progress');
  String get prefinished => translate('prefinished');
  String get completed => translate('completed');
  String get closed => translate('closed');
  String get ticketOverview => translate('ticket_overview');
  String get ticketDistribution => translate('ticket_distribution');
  String get recentTickets => translate('recent_tickets');
  String get viewAll => translate('view_all');
  String get noRecentTickets => translate('no_recent_tickets');
  String get noTicketsInProgress => translate('no_tickets_in_progress');
  String get noTicketData => translate('no_ticket_data');
  String get mobile => translate('mobile');
  String get web => translate('web');
  String get webDashboard => translate('web_dashboard');
  String get inProgressTickets => translate('in_progress_tickets');
  String get viewAllTickets => translate('view_all_tickets');
  String get noNotifications => translate('no_notifications');
  String get youllSeeUpdatesHere => translate('youll_see_updates_here');
  String get markAllRead => translate('mark_all_read');
  String get markAllAsRead => translate('mark_all_as_read');
  String get newMessageIn => translate('new_message_in');
  String get newMessageFrom => translate('new_message_from');
  String get ticketCreated => translate('ticket_created');
  String get ticketAssigned => translate('ticket_assigned');
  String get ticketStatusChanged => translate('ticket_status_changed');
  String get ticketApproved => translate('ticket_approved');
  String get ticketRejected => translate('ticket_rejected');
  String get newMessage => translate('new_message');
  String get chatMention => translate('chat_mention');
  String get subticketCreated => translate('subticket_created');
  String get updateProfile => translate('update_profile');
  String get accountInformation => translate('account_information');
  String get editInformation => translate('edit_information');
  String get userType => translate('user_type');
  String get status => translate('status');
  String get active => translate('active');
  String get inactive => translate('inactive');
  String get memberSince => translate('member_since');
  String get tapCameraToChange => translate('tap_camera_to_change');
  String get profileUpdatedSuccessfully =>
      translate('profile_updated_successfully');
  String get failedToUpdateProfile => translate('failed_to_update_profile');
  String get profileImageUpdatedSuccessfully =>
      translate('profile_image_updated_successfully');
  String get failedToUploadImage => translate('failed_to_upload_image');
  String get logout => translate('logout');
  String get emailAddress => translate('email_address');
  String get pleaseEnterYourEmail => translate('please_enter_your_email');
  String get pleaseEnterValidEmail => translate('please_enter_valid_email');
  String get pleaseEnterYourPassword => translate('please_enter_your_password');
  String get welcomeBackPleaseSignIn =>
      translate('welcome_back_please_sign_in');
  String get loginFailed => translate('login_failed');
  String get pleaseCheckCredentials => translate('please_check_credentials');
  String get registrationSuccessful => translate('registration_successful');
  String get accountCreatedSuccessfully =>
      translate('account_created_successfully');
  String get accountInactiveMessage => translate('account_inactive_message');
  String get registrationFailed => translate('registration_failed');
  String get pleaseEnterFullName => translate('please_enter_full_name');
  String get passwordMinLength => translate('password_min_length');
  String get passwordsDoNotMatch => translate('passwords_do_not_match');
  String get pleaseSelectPlace => translate('please_select_place');
  String get pleaseConfirmPassword => translate('please_confirm_password');
  String get optional => translate('optional');
  String get required => translate('required');
  String get registrationInformation => translate('registration_information');
  String get accountWillBeInactive => translate('account_will_be_inactive');
  String get adminActivationRequired => translate('admin_activation_required');
  String get emailNotificationOnActivation =>
      translate('email_notification_on_activation');
  String get normalUserAccountOnly => translate('normal_user_account_only');
  String get fillInYourInformation => translate('fill_in_your_information');
  String get loadingPlaces => translate('loading_places');
  String get noPlacesAvailable => translate('no_places_available');
  String get retry => translate('retry');
  String get ok => translate('ok');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get search => translate('search');
  String get filter => translate('filter');
  String get sort => translate('sort');
  String get noAccessToComplaints => translate('no_access_to_complaints');
  String get departmentNoPermission => translate('department_no_permission');
  String get contactSystemAdmin => translate('contact_system_admin');
  String get errorLoadingUser => translate('error_loading_user');
  String get noInternetConnection => translate('no_internet_connection');
  String get connected => translate('connected');
  String get disconnected => translate('disconnected');
  // Add these getters:
  String get searchTicketsPlacesCreators =>
      translate('search_tickets_places_creators');
  String get clearAllFilters => translate('clear_all_filters');
  String get clearAll => translate('clear_all');
  String get place => translate('place');
  String get showPlace => translate('showPlace');
    String get showMyTicket => translate('showMyTicket');
  String get allPlaces => translate('all_places');
  String get allUsers => translate('all_users');
  String get removed => translate('removed');
  String get creator => translate('creator');
  String get allCreators => translate('all_creators');
  String get dateRange => translate('date_range');
  String get allDates => translate('all_dates');
  String get sortByDate => translate('sort_by_date');
  String get sortByPriority => translate('sort_by_priority');
  String get byDate => translate('by_date');
  String get byPriority => translate('by_priority');
  String get date => translate('date');
  String get filtersAndSort => translate('filters_and_sort');
  String get createNewTicket => translate('create_new_ticket');
  String get itSolutionTicket => translate('it_solution_ticket');
  String get placesMaintenanceTicket => translate('places_maintenance_ticket');
  String get qualityComplaint => translate('quality_complaint');
  String get individualsMaintenanceTicket =>
      translate('individuals_maintenance_ticket');
  String get requestsTicket => translate('requests_ticket');
  String get create => translate('create');
  String get refresh => translate('refresh');
  String get connectionIssuesDetected =>
      translate('connection_issues_detected');
  String get connectionIssuesDetectedPullToRefresh =>
      translate('connection_issues_detected_pull_to_refresh');
  String get noTicketsFound => translate('no_tickets_found');
  String get tryAdjustingFilters => translate('try_adjusting_filters');
  String get unknown => translate('unknown');
  String get closeChat => translate('close_chat');
  String get wrongInfo => translate('wrong_info');
  String get deleted => translate('deleted');

  // Add these getters:
  String get checkedInAt => translate('checked_in_at');
  String get elapsed => translate('elapsed');
  String get subtickets => translate('subtickets');
  String get showingMyTickets => translate('showing_my_tickets');
  String get showingAllPlaceTickets => translate('showing_all_place_tickets');
  String get myTickets => translate('my_tickets');
  String get security => translate('security');
  String get changePassword => translate('change_password');
  String get currentPassword => translate('current_password');
  String get newPassword => translate('new_password');
  String get confirmNewPassword => translate('confirm_new_password');
  String get passwordUpdatedSuccessfully => translate('password_updated_successfully');
  String get incorrectCurrentPassword => translate('incorrect_current_password');
  String get passwordTooShort => translate('password_too_short');
  String get resetPassword => translate('reset_password');
  String get resetPasswordWithOTP => translate('reset_password_with_otp');
  String get sendOTP => translate('send_otp');
  String get enterOTP => translate('enter_otp');
  String get otpSentToEmail => translate('otp_sent_to_email');
  String get verifyAndSetPassword => translate('verify_and_set_password');
  String get invalidOTP => translate('invalid_otp');
  String get otpExpiredOrInvalid => translate('otp_expired_or_invalid');
  String get enterYourEmail => translate('enter_your_email');
  String get step1SendOTP => translate('step1_send_otp');
  String get step2EnterOTP => translate('step2_enter_otp');
  String get forgotPassword => translate('forgot_password');
  String get openChat => translate('open_chat');
  String get approveAndClose => translate('approve_and_close');
  String get requestChanges => translate('request_changes');
  String get basicInformation => translate('basic_information');
  String get technicalDetails => translate('technical_details');
  String get description => translate('description');
  String get workTracking => translate('work_tracking');
  String get workReport => translate('work_report');
  String get approvalDetails => translate('approval_details');
  String get workRejected => translate('work_rejected');
  String get informationIssues => translate('information_issues');
  String get attachments => translate('attachments');
  String get recentActivity => translate('recent_activity');
  String get title => translate('title');
  String get created => translate('created');
  String get updated => translate('updated');
  String get assignedTo => translate('assigned_to');
  String get otherPlace => translate('other_place');
  String get location => translate('location');
  String get department => translate('department');
  String get natureOfProblem => translate('nature_of_problem');
  String get problemType => translate('problem_type');
  String get customProblem => translate('custom_problem');
  String get partDevice => translate('part_device');
  String get customModel => translate('custom_model');
  String get priorityExplanation => translate('priority_explanation');
  String get images => translate('images');
  String get files => translate('files');
  String get failedToLoad => translate('failed_to_load');
  String get completedBy => translate('completed_by');
  String get reportAttachments => translate('report_attachments');
  String get unknownAdmin => translate('unknown_admin');
  String get approvedBy => translate('approved_by');
  String get approvalNotes => translate('approval_notes');
  String get workRejectedBy => translate('work_rejected_by');
  String get rejectionReason => translate('rejection_reason');
  String get issuesReportedBy => translate('issues_reported_by');
  String get issuesToAddress => translate('issues_to_address');
  String get ticketUnderSupervisionDesc =>
      translate('ticket_under_supervision_desc');
  String get supervisionInfoCreator => translate('supervision_info_creator');
  String get supervisionInfoAdmin => translate('supervision_info_admin');
  String get checkIn => translate('check_in');
  String get checkOut => translate('check_out');
  String get addNote => translate('add_note');
  String get markFinished => translate('mark_finished');
  String get markUnderSupervision => translate('mark_under_supervision');
  String get rejectFromSupervision => translate('reject_from_supervision');
  String get reviewAndApprove => translate('review_and_approve');
  String get goBack => translate('go_back');
  String get assign => translate('assign');
  String get startWork => translate('start_work');
  String get createSubticket => translate('create_subticket');
  String get createCorrectedTicket => translate('create_corrected_ticket');
  String get low => translate('low');
  String get medium => translate('medium');
  String get high => translate('high');
  String get urgent => translate('urgent');
  String get underSupervision => translate('under_supervision');
  String get priority => translate('priority');
  String get viewProfile => translate('view_profile');
  // Add these getters in AppLocalizations class:
  String get visitDuration => translate('visit_duration');
  String get checkInTime => translate('check_in_time');
  String get duration => translate('duration');
  String get visitReport => translate('visit_report');
  String get workPerformed => translate('work_performed');
  String get pleaseDescribeWork => translate('please_describe_work');
  String get checkedOutSuccessfully => translate('checked_out_successfully');
  String get errorCheckingOut => translate('error_checking_out');
  String get addTrackingPoint => translate('add_tracking_point');
  String get trackingType => translate('tracking_type');
  String get siteVisit => translate('site_visit');
  String get trackCheckInOutTime => translate('track_check_in_out_time');
  String get note => translate('note');
  String get simpleUpdate => translate('simple_update');
  String get timeTracking => translate('time_tracking');
  String get notCheckedIn => translate('not_checked_in');
  String get notCheckedOut => translate('not_checked_out');
  String get visitComplete => translate('visit_complete');
  String get whatWorkPerformed => translate('what_work_performed');
  String get addUpdateNote => translate('add_update_note');
  String get trackingPointWillRecord => translate('tracking_point_will_record');
  String get trackingPointSimpleNote => translate('tracking_point_simple_note');
  String get trackingPointAddedSuccessfully =>
      translate('tracking_point_added_successfully');
  String get errorAddingTrackingPoint =>
      translate('error_adding_tracking_point');
  String get pleaseEnterDescription => translate('please_enter_description');
  String get pleaseCheckInOrChangeToNote =>
      translate('please_check_in_or_change_to_note');
  String get checkedOutAt => translate('checked_out_at');
  String get noTrackingPointsYet => translate('no_tracking_points_yet');
  String get siteVisitUpper => translate('site_visit_upper');
  String get noteUpper => translate('note_upper');
  String get addTrackingNote => translate('add_tracking_note');
  String get noteDescription => translate('note_description');
  String get addUpdateOrNote => translate('add_update_or_note');
  String get noteAddedWithoutTimeTracking =>
      translate('note_added_without_time_tracking');
  String get noteAddedSuccessfully => translate('note_added_successfully');
  String get errorAddingNote => translate('error_adding_note');
  // Add these getters in AppLocalizations class:
  String get revertTicketStatus => translate('revert_ticket_status');
  String get thisWillRevertTicket => translate('this_will_revert_ticket');
  String get from => translate('from');
  String get backTo => translate('back_to');
  String get changesThatWillBeReverted =>
      translate('changes_that_will_be_reverted');
  String get adminAssignmentWillBeRemoved =>
      translate('admin_assignment_will_be_removed');
  String get ticketWillReturnUnassigned =>
      translate('ticket_will_return_unassigned');
  String get workReportWillBeDeleted =>
      translate('work_report_will_be_deleted');
  String get allReportAttachmentsRemoved =>
      translate('all_report_attachments_removed');
  String get ticketWillReturnActiveWork =>
      translate('ticket_will_return_active_work');
  String get approvalRecordDeleted => translate('approval_record_deleted');
  String get allAttachmentsRemoved => translate('all_attachments_removed');
  String get ticketWillReturnAwaitingApproval =>
      translate('ticket_will_return_awaiting_approval');
  String get workReportWillRemain => translate('work_report_will_remain');
  String get ticketWillBeRevertedPrevious =>
      translate('ticket_will_be_reverted_previous');
  String get thisActionCannotBeUndone =>
      translate('this_action_cannot_be_undone');
  String get areYouSure => translate('are_you_sure');
  String get revertStatus => translate('revert_status');
  String get deleteTicket => translate('delete_ticket');
  String get areYouSureDeleteTicket => translate('are_you_sure_delete_ticket');
  String get ticketWillBeMarkedDeleted =>
      translate('ticket_will_be_marked_deleted');
  String get canBeRecoveredByAdmin => translate('can_be_recovered_by_admin');
  String get ticketDeletedSuccessfully =>
      translate('ticket_deleted_successfully');
  String get errorDeletingTicket => translate('error_deleting_ticket');
  String get rejectionReasonRequired => translate('rejection_reason_required');
  String get pleaseProvideRejectionReason =>
      translate('please_provide_rejection_reason');
  String get ticketRejectedReturnedInProgress =>
      translate('ticket_rejected_returned_in_progress');
  String get rejectionReasonLabel => translate('rejection_reason_label');
  String get whyWorkBeingRejected => translate('why_work_being_rejected');
  String get reject => translate('reject');
  String get thisWillReturnTicketInProgress =>
      translate('this_will_return_ticket_in_progress');
  String get pleaseProvideReason => translate('please_provide_reason');
  String get ticketRevertedTo => translate('ticket_reverted_to');
  String get previousStateRestored => translate('previous_state_restored');
  String get errorReverting => translate('error_reverting');
  String get ticketStatusChangedToInProgress =>
      translate('ticket_status_changed_to_in_progress');
  String get error => translate('error');
  // Add these getters in AppLocalizations class:
  String get reviewCompletedWork => translate('review_completed_work');
  String get ticket => translate('ticket');
  String get autoApprovalCountdown => translate('auto_approval_countdown');
  String get timeExpired => translate('time_expired');
  String get timeRemaining => translate('time_remaining');
  String get totalTime => translate('total_time');
  String get yourDecision => translate('your_decision');
  String get approve => translate('approve');
  String get approvalNotesLabel => translate('approval_notes_label');
  String get workMeetsExpectations => translate('work_meets_expectations');
  String get changesNeeded => translate('changes_needed');
  String get explainChanges => translate('explain_changes');
  String get whatNeedsImprovement => translate('what_needs_improvement');
  String get approval => translate('approval');
  String get ticketWillBeClosed => translate('ticket_will_be_closed');
  String get noFurtherWork => translate('no_further_work');
  String get returnsToInProgress => translate('returns_to_in_progress');
  String get adminSeesFeedback => translate('admin_sees_feedback');
  String get pleaseAddApprovalNotes => translate('please_add_approval_notes');
  String get ticketApprovedAndClosed => translate('ticket_approved_and_closed');
  String get ticketReturnedForMoreWork =>
      translate('ticket_returned_for_more_work');
  String get errorSubmittingApproval => translate('error_submitting_approval');
  String get calculating => translate('calculating');
  String get expiredAutoClosingNow => translate('expired_auto_closing_now');
  String get days => translate('days');
  String get day => translate('day');
  String get hours => translate('hours');
  String get hour => translate('hour');
  String get minutes => translate('minutes');
  String get minute => translate('minute');
  String get seconds => translate('seconds');
  String get timeExpiredAutoApprovalNow =>
      translate('time_expired_auto_approval_now');
  String get urgentAutoApprovalIn => translate('urgent_auto_approval_in');
  String get warningAutoApprovalIn => translate('warning_auto_approval_in');
  String get assignTicket => translate('assign_ticket');
  String get matchingAdminsShownFirst =>
      translate('matching_admins_shown_first');
  String get noAvailableAdminsFound => translate('no_available_admins_found');
  String get match => translate('match');
  String get pleaseSelectAdmin => translate('please_select_admin');
  String get ticketAssignedSuccessfully =>
      translate('ticket_assigned_successfully');
  String get errorAssigningTicket => translate('error_assigning_ticket');
  String get markTicketFinished => translate('mark_ticket_finished');
  String get autoApprovalAfterMonitoring =>
      translate('auto_approval_after_monitoring');
  String get creatorWillReviewWork => translate('creator_will_review_work');
  String get reportTitle => translate('report_title');
  String get briefSummary => translate('brief_summary');
  String get add => translate('add');
  String get markSupervised => translate('mark_supervised');
  String get submit => translate('submit');
  String get ticketMarkedUnderSupervision =>
      translate('ticket_marked_under_supervision');
  String get workReportSubmittedSuccess =>
      translate('work_report_submitted_success');
  String get failedToSubmitReport => translate('failed_to_submit_report');
  String get imageDetails => translate('image_details');
  String get name => translate('name');
  String get size => translate('size');
  String get type => translate('type');
  String get uploaded => translate('uploaded');
  String get close => translate('close');
  String get shareNotImplemented => translate('share_not_implemented');
  String get failedToLoadImage => translate('failed_to_load_image');
  String get unknownFile => translate('unknown_file');
  String get loadingImage => translate('loading_image');
  String get previous => translate('previous');
  String get next => translate('next');

  // Add these getters in AppLocalizations class:
  String get markAsWrongInformation => translate('mark_as_wrong_information');
  String get provideFeedbackIncorrect =>
      translate('provide_feedback_incorrect');
  String get feedback => translate('feedback');
  String get explainWhatNeedsCorrected =>
      translate('explain_what_needs_corrected');
  String get markAsWrongInfo => translate('mark_as_wrong_info');
  String get ticketMarkedWrongInformation =>
      translate('ticket_marked_wrong_information');
  String get errorMarkingWrongInfo => translate('error_marking_wrong_info');
  String get pleaseProvideFeedback => translate('please_provide_feedback');
  String get parentTicket => translate('parent_ticket');
  String get subticketTitle => translate('subticket_title');
  String get briefDescriptionSubtask => translate('brief_description_subtask');
  String get detailedDescriptionTodo => translate('detailed_description_todo');
  String get targetDepartment => translate('target_department');
  String get selectDepartmentSubtask => translate('select_department_subtask');
  String get natureOfWork => translate('nature_of_work');
  String get selectNatureOfWork => translate('select_nature_of_work');
  String get noNatureOfWorkAvailable =>
      translate('no_nature_of_work_available');
  String get highPriorityExplanation => translate('high_priority_explanation');
  String get explainWhyUrgent => translate('explain_why_urgent');
  String get noFilesSelected => translate('no_files_selected');
  String get filesSelected => translate('files_selected');
  String get file => translate('file');
  String get subticketInformation => translate('subticket_information');
  String get subticketWillBeLinked => translate('subticket_will_be_linked');
  String get canBeAssignedDifferentDept =>
      translate('can_be_assigned_different_dept');
  String get helpsBreakDownTasks => translate('helps_break_down_tasks');
  String get parentCanTrackSubtickets =>
      translate('parent_can_track_subtickets');
  String get uploading => translate('uploading');
  String get creating => translate('creating');
  String get errorPickingFiles => translate('error_picking_files');
  String get errorPickingImages => translate('error_picking_images');
  String get pleaseFillAllRequired => translate('please_fill_all_required');
  String get pleaseExplainHighPriority =>
      translate('please_explain_high_priority');
  String get pleaseEnterPhoneNumber => translate('please_enter_phone_number');
  String get subticketCreatedSuccessfully =>
      translate('subticket_created_successfully');
  String get withAttachment => translate('with_attachment');
  String get withAttachments => translate('with_attachments');
  String get failedToCreateSubticket => translate('failed_to_create_subticket');

// IT Solution Ticket
  String get itSolutionTicketTitle => translate('it_solution_ticket_title');
  String get itBriefDescription => translate('it_brief_description');
  String get itDetailedDescription => translate('it_detailed_description');
  String get itTicketInfo => translate('it_ticket_info');
  String get itTicketSentToDept => translate('it_ticket_sent_to_dept');
  String get provideDetailedInfo => translate('provide_detailed_info');
  String get attachScreenshots => translate('attach_screenshots');
  String get youWillBeNotified => translate('you_will_be_notified');
  String get createTicket => translate('create_ticket');

// Places Maintenance Ticket
  String get placesMaintenanceTicketTitle =>
      translate('places_maintenance_ticket_title');
  String get placesBriefDescription => translate('places_brief_description');
  String get placesDetailedDescription =>
      translate('places_detailed_description');
  String get selectPlace => translate('select_place');
  String get placeInfo => translate('place_info');
  String get placeLockedForUser => translate('place_locked_for_user');
  String get specificLocation => translate('specific_location');
  String get specificLocationHint => translate('specific_location_hint');
  String get problemTitle => translate('problem_title');
  String get selectProblemType => translate('select_problem_type');
  String get enterCustomProblem => translate('enter_custom_problem');
  String get customProblemTitle => translate('custom_problem_title');
  String get describeProblem => translate('describe_problem');
  String get modelNumber => translate('model_number');
  String get selectDevicePart => translate('select_device_part');
  String get enterCustomModel => translate('enter_custom_model');
  String get customModelNumber => translate('custom_model_number');
  String get enterModelNumber => translate('enter_model_number');
  String get placesTicketInfo => translate('places_ticket_info');
  String get fillRequiredFields => translate('fill_required_fields');
  String get provideAccurateLocation => translate('provide_accurate_location');
  String get addPhotosIfPossible => translate('add_photos_if_possible');
  String get notifiedWhenWorkBegins => translate('notified_when_work_begins');

// Individuals Maintenance Ticket
  String get individualsMaintenanceTicketTitle =>
      translate('individuals_maintenance_ticket_title');
  String get individualsBriefDescription =>
      translate('individuals_brief_description');
  String get individualsDetailedDescription =>
      translate('individuals_detailed_description');
  String get placeIndividualInfo => translate('place_individual_info');
  String get specificLocationOptional =>
      translate('specific_location_optional');
  String get whereIndividualLocated => translate('where_individual_located');
  String get individualsTicketInfo => translate('individuals_ticket_info');
  String get forIssuesRelatedIndividuals =>
      translate('for_issues_related_individuals');
  String get addPhotosDocuments => translate('add_photos_documents');
  String get trackTicketStatus => translate('track_ticket_status');

// Requests Ticket
  String get requestsTicketTitle => translate('requests_ticket_title');
  String get requestTitle => translate('request_title');
  String get whatAreYouRequesting => translate('what_are_you_requesting');
  String get requestDescription => translate('request_description');
  String get detailedRequestDescription =>
      translate('detailed_request_description');
  String get selectDepartmentHandleRequest =>
      translate('select_department_handle_request');
  String get whereItemsDelivered => translate('where_items_delivered');
  String get requestsTicketInfo => translate('requests_ticket_info');
  String get useForRequestingItems => translate('use_for_requesting_items');
  String get commonlyUsedInterDept => translate('commonly_used_inter_dept');
  String get canBeUsedSubtickets => translate('can_be_used_subtickets');
  String get trackRequestStatus => translate('track_request_status');
  String get createRequest => translate('create_request');

// Common
  String get titleRequired => translate('title_required');
  String get descriptionRequired => translate('description_required');
  String get targetDepartmentRequired =>
      translate('target_department_required');
  String get natureOfWorkRequired => translate('nature_of_work_required');
  String get priorityRequired => translate('priority_required');
  String get highPriorityExplanationRequired =>
      translate('high_priority_explanation_required');
  String get explainHighUrgentPriority =>
      translate('explain_high_urgent_priority');
  String get modelNumberOptional => translate('model_number_optional');
  String get phoneNumber => translate('phone_number');
  String get attachmentsSection => translate('attachments_section');
  String get noNatureWorkForDept => translate('no_nature_work_for_dept');
  String get pleaseSelectProblemOrCustom =>
      translate('please_select_problem_or_custom');
  String get pleaseEnterCustomProblem =>
      translate('please_enter_custom_problem');
  String get itTicketCreatedSuccessfully =>
      translate('it_ticket_created_successfully');
  String get placesTicketCreatedSuccessfully =>
      translate('places_ticket_created_successfully');
  String get individualsTicketCreatedSuccessfully =>
      translate('individuals_ticket_created_successfully');
  String get requestsTicketCreatedSuccessfully =>
      translate('requests_ticket_created_successfully');
  String get withAttachmentCount => translate('with_attachment_count');
  String get withAttachmentsCount => translate('with_attachments_count');
  String get failedCreateTicket => translate('failed_create_ticket');
  // Add these getters to the AppLocalizations class:

  String get creatingCorrectedTicketFrom =>
      translate('creating_corrected_ticket_from');
  String get pleaseReviewAndUpdate => translate('please_review_and_update');
  String get phoneNumberRequired => translate('phone_number_required');
  String get contactPhoneNumber => translate('contact_phone_number');
  String get pleaseSelectNatureOfWork =>
      translate('please_select_nature_of_work');
  String get pleaseSpecifyOtherNatureOfWork =>
      translate('please_specify_other_nature_of_work');
  String get pleaseSpecifyOtherPlace => translate('please_specify_other_place');
  String get specifyNatureOfWork => translate('specify_nature_of_work');
  String get describeNatureOfWork => translate('describe_nature_of_work');
  String get noNatureWorkAvailableClickBelow =>
      translate('no_nature_work_available_click_below');
  String get specifyOther => translate('specify_other');
  String get specifyPlace => translate('specify_place');
  String get enterPlaceName => translate('enter_place_name');
  String get specifyProblemTitle => translate('specify_problem_title');
  String get specifyModelNumber => translate('specify_model_number');
  String get ticketInformation => translate('ticket_information');
  String get makeSureAllRequiredFieldsFilled =>
      translate('make_sure_all_required_fields_filled');
  String get provideAccuratePhoneNumber =>
      translate('provide_accurate_phone_number');
  String get addDetailedDescription => translate('add_detailed_description');
  String get attachRelevantImages => translate('attach_relevant_images');
  String get useOtherOptionIfNotInList =>
      translate('use_other_option_if_not_in_list');
  String get ticketCreatedSuccessfullyWith =>
      translate('ticket_created_successfully_with');
  String get ticketCreatedSuccessfully =>
      translate('ticket_created_successfully');

  String get otherSpecify => translate('other_specify');
  String get noResultsFound => translate('no_results_found');
  String get select => translate('select');
  String get itDepartmentNotFound => translate('it_department_not_found');

  String get qualityComplaints => translate('quality_complaints');
  String get allComplaints => translate('all_complaints');
  String get complainant => translate('complainant');
  String get complainantName => translate('complainant_name');
  String get receiver => translate('receiver');
  String get complaintReceiver => translate('complaint_receiver');
  String get item => translate('item');
  String get batchNumber => translate('batch_number');
  String get quantity => translate('quantity');
  String get produceDate => translate('produce_date');
  String get expiredDate => translate('expired_date');
  String get complaintType => translate('complaint_type');
  String get complaintDescription => translate('complaint_description');
  String get technical => translate('technical');
  String get coordinationDelivery => translate('coordination_delivery');
  String get complaintCheck => translate('complaint_check');
  String get complaintValid => translate('complaint_valid');
  String get complaintInvalid => translate('complaint_invalid');
  String get checkReport => translate('check_report');
  String get therapeuticProcedure => translate('therapeutic_procedure');
  String get checker => translate('checker');
  String get checkDate => translate('check_date');
  String get signedDocument => translate('signed_document');
  String get uploadSigned => translate('upload_signed');
  String get downloadPdf => translate('download_pdf');
  String get checkComplaint => translate('check_complaint');
  String get assignComplaint => translate('assign_complaint');
  String get noComplaintsFound => translate('no_complaints_found');
  String get complaintNumber => translate('complaint_number');
  String get selectAdmin => translate('select_admin');
  String get adminsAvailable => translate('admins_available');
  String get noAdminsAvailable => translate('no_admins_available');
  String get complaintAssignedSuccessfully =>
      translate('complaint_assigned_successfully');
  String get errorAssigningComplaint => translate('error_assigning_complaint');
  String get pleaseSelectAnAdmin => translate('please_select_an_admin');
  String get selectAdminFromDepartment =>
      translate('select_admin_from_department');
  String get reportRequired => translate('report_required');
  String get enterDetailedCheckReport =>
      translate('enter_detailed_check_report');
  String get therapeuticProcedureOptional =>
      translate('therapeutic_procedure_optional');
  String get enterTherapeuticProcedure =>
      translate('enter_therapeutic_procedure');
  String get addImagesOptional => translate('add_images_optional');
  String get afterSubmission => translate('after_submission');
  String get statusWillChangePrefinished =>
      translate('status_will_change_prefinished');
  String get pdfReportAutoDownload => translate('pdf_report_auto_download');
  String get canPrintSignUpload => translate('can_print_sign_upload');
  String get submitCheck => translate('submit_check');
  String get pleaseEnterReport => translate('please_enter_report');
  String get checkSubmittedSuccessfully =>
      translate('check_submitted_successfully');
  String get errorSubmittingCheck => translate('error_submitting_check');
  String get yes => translate('yes');
  String get no => translate('no');
  String get checkImages => translate('check_images');
  String get initialAttachments => translate('initial_attachments');
  String get imagesCount => translate('images_count');
  String get documentsCount => translate('documents_count');
  String get noInitialAttachments => translate('no_initial_attachments');
  String get initial => translate('initial');
  String get check => translate('check');
  String get signed => translate('signed');
  String get zoomIn => translate('zoom_in');
  String get zoomOut => translate('zoom_out');
  String get resetZoom => translate('reset_zoom');
  String get download => translate('download');
  String get downloadingImage => translate('downloading_image');
  String get imageDownloadedSuccessfully =>
      translate('image_downloaded_successfully');
  String get failedToDownloadImage => translate('failed_to_download_image');
  String get downloadNotSupported => translate('download_not_supported');
  String get generatingPdf => translate('generating_pdf');
  String get pdfGeneratedSuccessfully =>
      translate('pdf_generated_successfully');
  String get errorGeneratingPdf => translate('error_generating_pdf');
  String get noCheckReportAvailable => translate('no_check_report_available');
  String get loadingCheckData => translate('loading_check_data');
  String get noCheckRecordFound => translate('no_check_record_found');
  String get errorLoadingCheckData => translate('error_loading_check_data');
  String get replaceSignedDocument => translate('replace_signed_document');
  String get signedDocumentExists => translate('signed_document_exists');
  String get replace => translate('replace');
  String get couldNotReadFile => translate('could_not_read_file');
  String get fileSizeExceedsLimit => translate('file_size_exceeds_limit');
  String get uploadingPdf => translate('uploading_pdf');
  String get uploadingImage => translate('uploading_image');
  String get signedPdfUploaded => translate('signed_pdf_uploaded');
  String get signedImageUploaded => translate('signed_image_uploaded');
  String get failedUploadSigned => translate('failed_upload_signed');
  String get errorUploading => translate('error_uploading');
  String get selectFilePdfOrImage => translate('select_file_pdf_or_image');
// Add these getters to AppLocalizations class (around line 50+):

// Complaint-related getters
  String get createComplaint => translate('create_complaint');
  String get createQualityComplaint => translate('create_quality_complaint');
  String get complaintForm => translate('complaint_form');
  String get receiverName => translate('receiver_name');
  String get complainantInformation => translate('complainant_information');
  String get complainantsName => translate('complainants_name');
  String get mobileNumber => translate('mobile_number');
  String get phoneNumberOptional => translate('phone_number_optional');
  String get productInformation => translate('product_information');
  String get selectItem => translate('select_item');
  String get pleaseSelectItem => translate('please_select_item');
  String get batchNumberOptional => translate('batch_number_optional');
  String get quantityOptional => translate('quantity_optional');
  String get selectProduceDate => translate('select_produce_date');
  String get selectExpiredDate => translate('select_expired_date');
  String get complaintDetails => translate('complaint_details');
  String get describeIssueDetail => translate('describe_issue_detail');
  String get selectComplaintType => translate('select_complaint_type');
  String get addImages => translate('add_images');
  String get submitComplaint => translate('submit_complaint');
  String get complaintCreatedSuccessfully =>
      translate('complaint_created_successfully');
  String get errorCreatingComplaint => translate('error_creating_complaint');
  String get pleaseEnterComplainantName =>
      translate('please_enter_complainant_name');
  String get pleaseEnterLocation => translate('please_enter_location');
  String get pleaseEnterMobile => translate('please_enter_mobile');
  String get loadingItems => translate('loading_items');
  String get noItemsAvailable => translate('no_items_available');
  String get productDetails => translate('product_details');
  String get noItem => translate('no_item');
  String get assignToAdmin => translate('assign_to_admin');
  String get checkAndValidate => translate('check_and_validate');
  String get viewReport => translate('view_report');
  String get complaintCheckedBy => translate('complaint_checked_by');
  String get isValid => translate('is_valid');
  String get checkDetails => translate('check_details');
  String get noCheckData => translate('no_check_data');
  String get therapeuticProcedureDetails =>
      translate('therapeutic_procedure_details');
  String get notApplicable => translate('not_applicable');
  String get complaintInformation => translate('complaint_information');
  String get checkComplaintDialog => translate('check_complaint_dialog');
  String get assignComplaintDialog => translate('assign_complaint_dialog');
  String get documents => translate('documents');

  String get afterSubmissionInfo => translate('after_submission_info');
  String get loadingAdmins => translate('loading_admins');
  String get errorLoadingAdmins => translate('error_loading_admins');
  String get available => translate('available');
  String get report => translate('report');
  String get enterTherapeuticProcedureIfApplicable =>
      translate('enter_therapeutic_procedure_if_applicable');

  // Chat-related getters
  String get chatRooms => translate('chat_rooms');
  String get recentConversations => translate('recent_conversations');
  String get unread => translate('unread');
  String get noActiveChatRooms => translate('no_active_chat_rooms');
  String get chatRoomsAppearWhenTicketsInProgress =>
      translate('chat_rooms_appear_when_tickets_in_progress');
  String get selectConversationToStartChatting =>
      translate('select_conversation_to_start_chatting');
  String get chooseFromActiveTicketsOnLeft =>
      translate('choose_from_active_tickets_on_left');
  String get noMessagesYet => translate('no_messages_yet');
  String get startConversation => translate('start_conversation');
  String get typeMessage => translate('type_message');
  String get sendingMessages => translate('sending_messages');
  String get scrollToLatest => translate('scroll_to_latest');
  String get reconnecting => translate('reconnecting');
  String get loadingChatRooms => translate('loading_chat_rooms');
  String get someone => translate('someone');
  String get you => translate('you');
  String get user => translate('user');
  String get now => translate('now');

  String get departments => translate('departments');
  String get createDepartment => translate('create_department');
  String get nameIsRequired => translate('name_is_required');
  String get departmentCreatedSuccessfully =>
      translate('department_created_successfully');
  String get failedToCreateDepartment =>
      translate('failed_to_create_department');
  String get departmentActivated => translate('department_activated');
  String get departmentDeactivated => translate('department_deactivated');
  String get failedToUpdateDepartment =>
      translate('failed_to_update_department');
  String get total => translate('total');
  String get noDepartmentsYet => translate('no_departments_yet');
  String get createYourFirstDepartment =>
      translate('create_your_first_department');

  String get createPlace => translate('create_place');
  String get placeCreatedSuccessfully =>
      translate('place_created_successfully');
  String get failedToCreatePlace => translate('failed_to_create_place');
  String get placeActivated => translate('place_activated');
  String get placeDeactivated => translate('place_deactivated');
  String get failedToUpdatePlace => translate('failed_to_update_place');
  String get noPlacesYet => translate('no_places_yet');
  String get createYourFirstPlace => translate('create_your_first_place');

  String get addUser => translate('add_user');
  String get oF => translate('of');
  String get noUsersYet => translate('no_users_yet');
  String get createYourFirstUser => translate('create_your_first_user');
  String get userActivated => translate('user_activated');
  String get userDeactivated => translate('user_deactivated');
  String get removeUser => translate('remove_user');
  String get confirmRemoveUser => translate('confirm_remove_user');
  String get userRemoved => translate('user_removed');
  String get restoreUser => translate('restore_user');
  String get userRestored => translate('user_restored');
  String get failedToUpdateUserStatus =>
      translate('failed_to_update_user_status');

  String get activityLogs => translate('activity_logs');
  String get entries => translate('entries');
  String get searchActionTableUser => translate('search_action_table_user');
  String get allActions => translate('all_actions');
  String get noLogsFound => translate('no_logs_found');
  String get loadMore => translate('load_more');
  String get changedFrom => translate('changed_from');
  String get changedTo => translate('changed_to');
  String get newRecord => translate('new_record');
  String get deletedRecord => translate('deleted_record');
  String get details => translate('details');
  String get system => translate('system');
  String get all => translate('all');
  String get aiInsights => translate('ai_insights');
  String get analyzeWithAi => translate('analyze_with_ai');
  String get aiInsightsHint => translate('ai_insights_hint');
  String get aiSummary => translate('ai_summary');
  String get topProblemPlaces => translate('top_problem_places');
  String get recurringIssues => translate('recurring_issues');
  String get rootCauses => translate('root_causes');
  String get replacementRecommendations => translate('replacement_recommendations');
  String get preventionSuggestions => translate('prevention_suggestions');
  String get smartTitleSuggestions => translate('smart_title_suggestions');
  String get selectDepartment => translate('select_department');
  String get savedSuccessfully => translate('saved_successfully');

  String get problemTitles => translate('problem_titles');
  String get createProblemTitle => translate('create_problem_title');
  String get problemTitleCreatedSuccessfully =>
      translate('problem_title_created_successfully');
  String get failedToCreateProblemTitle =>
      translate('failed_to_create_problem_title');
  String get noProblemTitlesYet => translate('no_problem_titles_yet');
  String get createYourFirstProblemTitle =>
      translate('create_your_first_problem_title');
  String get searchProblemTitles => translate('search_problem_titles');

  String get createPart => translate('create_part');
  String get modelNumberRequired => translate('model_number_required');
  String get nameAndModelRequired => translate('name_and_model_required');
  String get partCreatedSuccessfully => translate('part_created_successfully');
  String get failedToCreatePart => translate('failed_to_create_part');
  String get noPartsYet => translate('no_parts_yet');
  String get createYourFirstPart => translate('create_your_first_part');
  String get searchParts => translate('search_parts');

  String get natureOfWorkManagement => translate('nature_of_work_management');
  String get createNatureOfWork => translate('create_nature_of_work');
  String get natureOfWorkCreatedSuccessfully =>
      translate('nature_of_work_created_successfully');
  String get failedToCreateNatureOfWork =>
      translate('failed_to_create_nature_of_work');
  String get deactivatedSuccessfully => translate('deactivated_successfully');
  String get activatedSuccessfully => translate('activated_successfully');
  String get failedToUpdateStatus => translate('failed_to_update_status');
  String get noNatureOfWorkYet => translate('no_nature_of_work_yet');
  String get defineYourFirstNatureOfWork =>
      translate('define_your_first_nature_of_work');
  String get searchNatureOfWork => translate('search_nature_of_work');

  String get complaintItems => translate('complaint_items');
  String get createComplaintItem => translate('create_complaint_item');
  String get itemNameRequired => translate('item_name_required');
  String get itemCreatedSuccessfully => translate('item_created_successfully');
  String get failedToCreateItem => translate('failed_to_create_item');
  String get itemActivated => translate('item_activated');
  String get itemDeactivated => translate('item_deactivated');
  String get failedToUpdateItem => translate('failed_to_update_item');
  String get noComplaintItemsYet => translate('no_complaint_items_yet');
  String get createYourFirstItem => translate('create_your_first_item');
  String get searchItems => translate('search_items');
  String get itemName => translate('item_name');

  String get complaintPermissions => translate('complaint_permissions');
  String get manageDepartmentAccess => translate('manage_department_access');
  String get enableComplaintAccessDescription =>
      translate('enable_complaint_access_description');
  String get searchDepartments => translate('search_departments');
  String get noDepartmentsFound => translate('no_departments_found');
  String get noDepartmentsMatchSearch =>
      translate('no_departments_match_search');
  String get canAccessComplaints => translate('can_access_complaints');
  String get noComplaintAccess => translate('no_complaint_access');
  String get complaintAccessEnabled => translate('complaint_access_enabled');
  String get complaintAccessDisabled => translate('complaint_access_disabled');
  String get failedToUpdatePermission =>
      translate('failed_to_update_permission');

  String get autoApprovalSettings => translate('auto_approval_settings');
  String get automaticallyApprovePrefinishedTickets =>
      translate('automatically_approve_prefinished_tickets');
  String get aboutAutoApproval => translate('about_auto_approval');
  String get autoApprovalInfo1 => translate('auto_approval_info_1');
  String get autoApprovalInfo2 => translate('auto_approval_info_2');
  String get autoApprovalInfo3 => translate('auto_approval_info_3');
  String get autoApprovalInfo4 => translate('auto_approval_info_4');
  String get currentAutoApprovalTime => translate('current_auto_approval_time');
  String get editTime => translate('edit_time');
  String get ticketsReadyForAutoApproval =>
      translate('tickets_ready_for_auto_approval');
  String get approveNow => translate('approve_now');
  String get howItWorks => translate('how_it_works');
  String get setAutoApprovalTime => translate('set_auto_approval_time');
  String get minimum1Minute => translate('minimum_1_minute');
  String get commonValues => translate('common_values');
  String get pleaseEnterValidNumber => translate('please_enter_valid_number');
  String get triggerAutoApproval => translate('trigger_auto_approval');
  String get thisWillImmediatelyAutoApprove =>
      translate('this_will_immediately_auto_approve');
  String get autoApprovalCompletedSuccessfully =>
      translate('auto_approval_completed_successfully');
  String get errorTriggeringAutoApproval =>
      translate('error_triggering_auto_approval');
  String get currentStatus => translate('current_status');
  String get push => translate('push');
  String get on => translate('on');
  String get off => translate('off');

  String get autoAssignmentSettings => translate('auto_assignment_settings');
  String get automaticallyAssignNewTickets =>
      translate('automatically_assign_new_tickets');
  String get autoAssignmentHowItWorks1 =>
      translate('auto_assignment_how_it_works_1');
  String get autoAssignmentHowItWorks2 =>
      translate('auto_assignment_how_it_works_2');
  String get autoAssignmentHowItWorks3 =>
      translate('auto_assignment_how_it_works_3');
  String get autoAssignmentHowItWorks4 =>
      translate('auto_assignment_how_it_works_4');
  String get autoAssignmentStatus => translate('auto_assignment_status');
  String get newTicketsWillBeAutomaticallyAssigned =>
      translate('new_tickets_will_be_automatically_assigned');
  String get newTicketsWillRequireManualAssignment =>
      translate('new_tickets_will_require_manual_assignment');
  String get assignNewTicketsTo => translate('assign_new_tickets_to');
  String get chooseWhichAdminWillReceive =>
      translate('choose_which_admin_will_receive');
  String get noNormalAdminsFound => translate('no_normal_admins_found');
  String get selectedAdmin => translate('selected_admin');
  String get savingSettings => translate('saving_settings');
  String get autoAssignmentIsActive => translate('auto_assignment_is_active');
  String get accessRestricted => translate('access_restricted');
  String get onlySuperAdminsCanManage =>
      translate('only_super_admins_can_manage');
  String get pleaseSelectAdminBeforeEnabling =>
      translate('please_select_admin_before_enabling');
  String get autoAssignmentEnabledSuccessfully =>
      translate('auto_assignment_enabled_successfully');
  String get autoAssignmentDisabledSuccessfully =>
      translate('auto_assignment_disabled_successfully');
  String get failedToSaveSettings => translate('failed_to_save_settings');

  String get manageHowYouReceiveNotifications =>
      translate('manage_how_you_receive_notifications');
  String get aboutNotifications => translate('about_notifications');
  String get notificationsInfo1 => translate('notifications_info_1');
  String get notificationsInfo2 => translate('notifications_info_2');
  String get notificationsInfo3 => translate('notifications_info_3');
  String get notificationsInfo4 => translate('notifications_info_4');
  String get pushNotifications => translate('push_notifications');
  String get enablePushNotifications => translate('enable_push_notifications');
  String get receivePushNotificationsOnDevice =>
      translate('receive_push_notifications_on_device');
  String get chatMessageNotifications =>
      translate('chat_message_notifications');
  String get getNotifiedNewChatMessages =>
      translate('get_notified_new_chat_messages');
  String get emailNotifications => translate('email_notifications');
  String get enableEmailNotifications =>
      translate('enable_email_notifications');
  String get receiveNotificationsViaEmail =>
      translate('receive_notifications_via_email');
  String get couldNotLoadPreferences => translate('could_not_load_preferences');
  String get preferencesUpdatedSuccessfully =>
      translate('preferences_updated_successfully');
  String get failedToUpdatePreferences =>
      translate('failed_to_update_preferences');

  String get places => translate('places');
  String get users => translate('users');
  String get parts => translate('parts');
  String get notificationPreferences => translate('notification_preferences');

  // Add these getters to the AppLocalizations class in app_localizations.dart:

// User Management
  String get noPermissionToCreateUsers =>
      translate('no_permission_to_create_users');
  String get createNewUser => translate('create_new_user');
  String get createUser => translate('create_user');
  String get pleaseSelectDepartmentForAdminUsers =>
      translate('please_select_department_for_admin_users');
  String get pleaseSelectPlaceForSuperUsers =>
      translate('please_select_place_for_super_users');
  String get userCreatedSuccessfully => translate('user_created_successfully');
  String get failedToCreateUser => translate('failed_to_create_user');
  String get addNatureOfWorkAndPressEnter =>
      translate('add_nature_of_work_and_press_enter');
  String get editUser => translate('edit_user');
  String get natureOfWorkExpertise => translate('nature_of_work_expertise');
  String get selectTypesOfWorkAdminSpecializesIn =>
      translate('select_types_of_work_admin_specializes_in');
  String get updateUser => translate('update_user');
  String get pleaseFillFullNameField =>
      translate('please_fill_full_name_field');
  String get userUpdatedSuccessfully => translate('user_updated_successfully');
  String get failedToUpdateUser => translate('failed_to_update_user');

// Nature of Work
  String get exampleNetworkIssuesHardwareRepair =>
      translate('example_network_issues_hardware_repair');
  String get noNatureOfWorkFound => translate('no_nature_of_work_found');
  String get tryAdjustingSearch => translate('try_adjusting_search');

// Complaint Items
  String get exampleProductXServiceY =>
      translate('example_product_x_service_y');
  String get addItem => translate('add_item');
  String get noItemsFound => translate('no_items_found');
  String get loadingSettings => translate('loading_settings');
  String get permissions => translate('permissions');
  String get autoApproval => translate('auto_approval');
  String get logs => translate('logs');
  String get preferences => translate('preferences');
  String get autoAssign => translate('auto_assign');
  String get reports => translate('reports');
  String get invalidTab => translate('invalid_tab');
  String get noManagementOptionsAvailable =>
      translate('no_management_options_available');

  String get failedToLoadPreferences => translate('failed_to_load_preferences');
  String get savingPreferences => translate('saving_preferences');
  String get problemTitleUpdatedSuccessfully =>
      translate('problem_title_updated_successfully');
  String get failedToUpdateProblemTitle =>
      translate('failed_to_update_problem_title');
  String get deleteProblemTitle => translate('delete_problem_title');
  String get areYouSureDeleteProblemTitle =>
      translate('are_you_sure_delete_problem_title');
  String get problemTitleDeletedSuccessfully =>
      translate('problem_title_deleted_successfully');
  String get failedToDeleteProblemTitle =>
      translate('failed_to_delete_problem_title');

// Parts
  String get partUpdatedSuccessfully => translate('part_updated_successfully');
  String get failedToUpdatePart => translate('failed_to_update_part');
  String get deletePart => translate('delete_part');
  String get areYouSureDeletePart => translate('are_you_sure_delete_part');
  String get partDeletedSuccessfully => translate('part_deleted_successfully');
  String get failedToDeletePart => translate('failed_to_delete_part');

// Nature of Work
  String get natureOfWorkUpdatedSuccessfully =>
      translate('nature_of_work_updated_successfully');
  String get failedToUpdateNatureOfWork =>
      translate('failed_to_update_nature_of_work');
  String get deleteNatureOfWork => translate('delete_nature_of_work');
  String get areYouSureDeleteNatureOfWork =>
      translate('are_you_sure_delete_nature_of_work');
  String get natureOfWorkDeletedSuccessfully =>
      translate('nature_of_work_deleted_successfully');
  String get failedToDeleteNatureOfWork =>
      translate('failed_to_delete_nature_of_work');

// Complaint Items
  String get itemUpdatedSuccessfully => translate('item_updated_successfully');
  String get deleteComplaintItem => translate('delete_complaint_item');
  String get areYouSureDeleteItem => translate('are_you_sure_delete_item');
  String get itemDeletedSuccessfully => translate('item_deleted_successfully');
  String get failedToDeleteItem => translate('failed_to_delete_item');

  String get departmentUpdatedSuccessfully =>
      translate('department_updated_successfully');
  String get deleteDepartment => translate('delete_department');
  String get areYouSureDeleteDepartment =>
      translate('are_you_sure_delete_department');
  String get departmentDeletedSuccessfully =>
      translate('department_deleted_successfully');
  String get failedToDeleteDepartment =>
      translate('failed_to_delete_department');

  String get placeUpdatedSuccessfully =>
      translate('place_updated_successfully');
  String get deletePlace => translate('delete_place');
  String get areYouSureDeletePlace => translate('are_you_sure_delete_place');
  String get placeDeletedSuccessfully =>
      translate('place_deleted_successfully');
  String get failedToDeletePlace => translate('failed_to_delete_place');
  String get realtimeUpdatesPaused => translate('realtime_updates_paused');
  String get reconnect => translate('reconnect');
  String get youStartedWorkingOnTicket =>
      translate('you_started_working_on_ticket');
  String get takeOver => translate('take_over');
  String get takeOverTicket => translate('take_over_ticket');
  String get ticketCurrentlyAssignedTo =>
      translate('ticket_currently_assigned_to');
  String get areYouSureTakeOverTicket =>
      translate('are_you_sure_take_over_ticket');
  String get ticketTakenOverSuccessfully =>
      translate('ticket_taken_over_successfully');
  String get errorStartingWork => translate('error_starting_work');
  String get errorTakingOver => translate('error_taking_over');
  String get branchAdmins => translate('branch_admins');
  String get branchAdminManagement => translate('branch_admin_management');
  String get branchAdminManagementDescription =>
      translate('branch_admin_management_description');
  String get noBranchAdminsYet => translate('no_branch_admins_yet');
  String get createBranchAdminsInUserManagement =>
      translate('create_branch_admins_in_user_management');
  String get searchBranchAdmins => translate('search_branch_admins');
  String get editPlacesFor => translate('edit_places_for');
  String get noPlacesAssigned => translate('no_places_assigned');
  String get placesUpdatedSuccessfully =>
      translate('places_updated_successfully');
  String get failedToUpdatePlaces => translate('failed_to_update_places');
  String get editPlaces => translate('edit_places');
  // Add more getters as needed...
}

// English translations
const Map<String, String> _enValues = {
  'app_name': 'Jala Ticketing',
  'welcome_back': 'Welcome back,',
  'dashboard': 'Dashboard',
  'tickets': 'Tickets',
  'chat': 'Chat',
  'notifications': 'Notifications',
  'complaints': 'Complaints',
  'management': 'Management',
  'profile': 'Profile',
  'sign_in': 'Sign In',
  'sign_out': 'Sign Out',
  'register': 'Register',
  'email': 'Email',
  'password': 'Password',
  'confirm_password': 'Confirm Password',
  'full_name': 'Full Name',
  'phone': 'Phone',
  'language': 'Language',
  'select_your_place': 'Select Your Place',
  'create_account': 'Create Account',
  'already_have_account': 'Already have an account?',
  'dont_have_account': "Don't have an account?",
  'sign_in_here': 'Sign in here',
  'register_here': 'Register here',
  'loading': 'Loading...',
  'loading_dashboard': 'Loading dashboard...',
  'pending': 'Pending',
  'in_progress': 'In Progress',
  'prefinished': 'Pre-finished',
  'completed': 'Completed',
  'closed': 'Closed',
  'ticket_overview': 'Ticket Overview',
  'ticket_distribution': 'Ticket Distribution',
  'recent_tickets': 'Recent Tickets',
  'view_all': 'View All',
  'no_recent_tickets': 'No recent tickets',
  'no_tickets_in_progress': 'No tickets in progress',
  'no_ticket_data': 'No ticket data available',
  'mobile': 'MOBILE',
  'web': 'WEB',
  'web_dashboard': 'WEB DASHBOARD',
  'in_progress_tickets': 'In Progress Tickets',
  'view_all_tickets': 'View All Tickets',
  'no_notifications': 'No notifications',
  'youll_see_updates_here': "You'll see updates here",
  'mark_all_read': 'Mark all',
  'mark_all_as_read': 'Mark all read',
  'new_message_in': 'New message in',
  'new_message_from': 'New message from',
  'ticket_created': 'Ticket Created',
  'ticket_assigned': 'Ticket Assigned',
  'ticket_status_changed': 'Status Changed',
  'ticket_approved': 'Ticket Approved',
  'ticket_rejected': 'Ticket Rejected',
  'new_message': 'New Message',
  'chat_mention': 'Mentioned in Chat',
  'subticket_created': 'Subticket Created',
  'update_profile': 'Update Profile',
  'account_information': 'Account Information',
  'edit_information': 'Edit Information',
  'user_type': 'User Type',
  'status': 'Status',
  'active': 'Active',
  'inactive': 'Inactive',
  'member_since': 'Member Since',
  'tap_camera_to_change': 'Tap the camera icon to change your profile picture',
  'profile_updated_successfully': 'Profile updated successfully',
  'failed_to_update_profile': 'Failed to update profile',
  'profile_image_updated_successfully': 'Profile image updated successfully',
  'failed_to_upload_image': 'Failed to upload image',
  'logout': 'Logout',
  'email_address': 'Email Address',
  'please_enter_your_email': 'Please enter your email',
  'please_enter_valid_email': 'Please enter a valid email',
  'please_enter_your_password': 'Please enter your password',
  'welcome_back_please_sign_in': 'Welcome back! Please sign in to continue',
  'login_failed': 'Login failed. Please check your credentials.',
  'please_check_credentials': 'Please check your credentials',
  'registration_successful': 'Registration Successful',
  'account_created_successfully': 'Your account has been created successfully!',
  'account_inactive_message':
      'Your account is currently inactive and will need to be activated by an administrator.\n\nYou will receive an email notification once your account is activated.',
  'registration_failed': 'Registration failed. Please try again.',
  'please_enter_full_name': 'Please enter your full name',
  'password_min_length': 'Password must be at least 6 characters',
  'passwords_do_not_match': 'Passwords do not match',
  'please_select_place': 'Please select a place',
  'please_confirm_password': 'Please confirm your password',
  'optional': 'Optional',
  'required': 'Required',
  'registration_information': 'Registration Information',
  'account_will_be_inactive': 'Account will be created as inactive',
  'admin_activation_required': 'Administrator activation required',
  'email_notification_on_activation': 'Email notification upon activation',
  'normal_user_account_only': 'Normal user account type only',
  'fill_in_your_information': 'Fill in your information to get started',
  'loading_places': 'Loading places...',
  'no_places_available': 'No places available',
  'retry': 'Retry',
  'ok': 'OK',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'search': 'Search',
  'filter': 'Filter',
  'sort': 'Sort',
  'no_access_to_complaints': 'No Access to Complaints',
  'department_no_permission':
      "Your department doesn't have permission to access the complaints module.",
  'contact_system_admin': 'Please contact your System Administrator.',
  'error_loading_user': 'Error loading user',
  'no_internet_connection': 'No internet connection',
  'connected': 'Connected',
  'disconnected': 'Disconnected',
  'search_tickets_places_creators': 'Search tickets, places, creators...',
  'clear_all_filters': 'Clear All Filters',
  'clear_all': 'Clear All',
  'place': 'Place',
  'showPlace': 'Branch Ticket',
  'showMyTicket': 'My Ticket',
  'all_places': 'All Places',
  'all_users': 'All Users',
  'removed': 'Removed',
  'creator': 'Creator',
  'all_creators': 'All Creators',
  'date_range': 'Date Range',
  'all_dates': 'All Dates',
  'sort_by_date': 'Sort by Date',
  'sort_by_priority': 'Sort by Priority',
  'by_date': 'By Date',
  'by_priority': 'By Priority',
  'date': 'Date',
  'filters_and_sort': 'Filters & Sort',
  'create_new_ticket': 'Create new ticket',
  'it_solution_ticket': 'IT Solution Ticket',
  'places_maintenance_ticket': 'Places Maintenance Ticket',
  'quality_complaint': 'Quality Complaint',
  'individuals_maintenance_ticket': 'Individuals Maintenance Ticket',
  'requests_ticket': 'Requests Ticket',
  'create': 'Create',
  'refresh': 'Refresh',
  'connection_issues_detected':
      'Connection issues detected. Data may not be real-time.',
  'connection_issues_detected_pull_to_refresh':
      'Connection issues detected. Pull to refresh manually.',
  'no_tickets_found': 'No tickets found',
  'try_adjusting_filters': 'Try adjusting your filters',
  'unknown': 'Unknown',
  'close_chat': 'Close chat',
  'wrong_info': 'Wrong Info',
  'deleted': 'Deleted',
  'checked_in_at': 'Checked in at',
  'elapsed': 'elapsed',
  'subtickets': 'Subtickets',
  'open_chat': 'Open Chat',
  'approve_and_close': 'Approve & Close',
  'request_changes': 'Request Changes',
  'basic_information': 'Basic Information',
  'technical_details': 'Technical Details',
  'description': 'Description',
  'work_tracking': 'Work Tracking',
  'work_report': 'Work Report',
  'approval_details': 'Approval Details',
  'work_rejected': 'Work Rejected',
  'information_issues': 'Information Issues',
  'attachments': 'Attachments',
  'recent_activity': 'Recent Activity',
  'title': 'Title',
  'created': 'Created',
  'updated': 'Updated',
  'assigned_to': 'Assigned To',
  'other_place': 'Other Place',
  'location': 'Location',
  'department': 'Department',
  'nature_of_problem': 'Nature of Problem',
  'problem_type': 'Problem Type',
  'custom_problem': 'Custom Problem',
  'part_device': 'Part/Device',
  'custom_model': 'Custom Model',
  'priority_explanation': 'Priority Explanation',
  'images': 'Images',
  'files': 'Files',
  'failed_to_load': 'Failed to load',
  'completed_by': 'Completed by',
  'report_attachments': 'Report Attachments',
  'unknown_admin': 'Unknown Admin',
  'approved_by': 'Approved by',
  'approval_notes': 'Approval Notes',
  'work_rejected_by': 'Work Rejected by',
  'rejection_reason': 'Rejection Reason',
  'issues_reported_by': 'Issues Reported by',
  'issues_to_address': 'Issues to Address',
  'ticket_under_supervision_desc':
      'This ticket is being monitored and will be automatically approved',
  'supervision_info_creator':
      'Your ticket is under supervision by the admin. It will be automatically approved after the monitoring period.',
  'supervision_info_admin':
      'This ticket is under supervision. Only the assigned admin can reject it before auto-approval.',
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'add_note': 'Add Note',
  'mark_finished': 'Mark Finished',
  'mark_under_supervision': 'Mark Under Supervision',
  'reject_from_supervision': 'Reject from Supervision',
  'review_and_approve': 'Review & Approve',
  'go_back': 'Go Back',
  'assign': 'Assign',
  'start_work': 'Start Work',
  'create_subticket': 'Create Subticket',
  'create_corrected_ticket': 'Create Corrected Ticket',
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'urgent': 'Urgent',
  'under_supervision': 'Under Supervision',
  'priority': 'priority',
  'view_profile': 'View Profile',
  'visit_duration': 'Visit Duration',
  'check_in_time': 'Check In',
  'duration': 'Duration',
  'visit_report': 'Visit Report',
  'work_performed': 'Work performed...',
  'please_describe_work': 'Please describe what work was performed',
  'checked_out_successfully': 'Checked out successfully',
  'error_checking_out': 'Error checking out',
  'add_tracking_point': 'Add Tracking Point',
  'tracking_type': 'Tracking Type',
  'site_visit': 'Site Visit',
  'track_check_in_out_time': 'Track check-in/out time',
  'note': 'Note',
  'simple_update': 'Simple update',
  'time_tracking': 'Time Tracking',
  'not_checked_in': 'Not checked in',
  'not_checked_out': 'Not checked out',
  'visit_complete': 'Visit Complete',
  'what_work_performed': 'What work was performed during this visit?',
  'add_update_note': 'Add update or note about the ticket...',
  'tracking_point_will_record':
      'This tracking point will record your site visit with check-in/out times.',
  'tracking_point_simple_note':
      'This tracking point will be added as a simple note without time tracking.',
  'tracking_point_added_successfully': 'Tracking point added successfully',
  'error_adding_tracking_point': 'Error adding tracking point',
  'please_enter_description': 'Please enter a description',
  'please_check_in_or_change_to_note':
      'Please check in or change to a simple note',
  'checked_out_at': 'Checked out at',
  'no_tracking_points_yet': 'No tracking points yet',
  'site_visit_upper': 'SITE VISIT',
  'note_upper': 'NOTE',
  'add_tracking_note': 'Add Tracking Note',
  'note_description': 'Note Description',
  'add_update_or_note': 'Add update or note...',
  'note_added_without_time_tracking': 'Note added without time tracking',
  'note_added_successfully': 'Note added successfully',
  'error_adding_note': 'Error adding note',
  'revert_ticket_status': 'Revert Ticket Status',
  'this_will_revert_ticket': 'This will revert ticket',
  'from': 'from',
  'back_to': 'back to',
  'changes_that_will_be_reverted': 'Changes that will be reverted:',
  'admin_assignment_will_be_removed': 'Admin assignment will be removed',
  'ticket_will_return_unassigned': 'Ticket will return to unassigned state',
  'work_report_will_be_deleted': 'Work report will be permanently deleted',
  'all_report_attachments_removed': 'All report attachments will be removed',
  'ticket_will_return_active_work': 'Ticket will return to active work state',
  'approval_record_deleted': 'Approval record will be deleted',
  'all_attachments_removed': 'All attachments will be removed',
  'ticket_will_return_awaiting_approval':
      'Ticket will return to awaiting approval state',
  'work_report_will_remain': 'Work report will remain intact',
  'ticket_will_be_reverted_previous':
      'Ticket will be reverted to previous state',
  'this_action_cannot_be_undone':
      'This action cannot be undone automatically. Are you sure?',
  'are_you_sure': 'Are you sure?',
  'revert_status': 'Revert Status',
  'delete_ticket': 'Delete Ticket',
  'are_you_sure_delete_ticket': 'Are you sure you want to delete ticket',
  'ticket_will_be_marked_deleted':
      'The ticket will be marked as deleted but can be recovered by administrators if needed.',
  'can_be_recovered_by_admin': 'Can be recovered by administrators if needed',
  'ticket_deleted_successfully': 'Ticket deleted successfully',
  'error_deleting_ticket': 'Error deleting ticket',
  'rejection_reason_required': 'Rejection Reason *',
  'please_provide_rejection_reason': 'Please provide a rejection reason',
  'ticket_rejected_returned_in_progress':
      'Ticket rejected and returned to in-progress',
  'rejection_reason_label': 'Rejection Reason',
  'why_work_being_rejected': 'Why is the work being rejected?',
  'reject': 'Reject',
  'this_will_return_ticket_in_progress':
      'This will return the ticket to in-progress status. Please provide a reason:',
  'please_provide_reason': 'Please provide a reason',
  'ticket_reverted_to': 'Ticket reverted to',
  'previous_state_restored': 'Previous state restored.',
  'error_reverting': 'Error reverting',
  'ticket_status_changed_to_in_progress':
      'Ticket status changed to In Progress',
  'error': 'There is error',
  'review_completed_work': 'Review Completed Work',
  'ticket': 'Ticket',
  'auto_approval_countdown': 'Auto-Approval Countdown',
  'time_expired': 'TIME EXPIRED',
  'time_remaining': 'Time Remaining',
  'total_time': 'Total Time',
  'your_decision': 'Your Decision',
  'approve': 'Approve',
  'approval_notes_label': 'Approval notes *',
  'work_meets_expectations': 'Work meets expectations...',
  'changes_needed': 'Changes Needed',
  'explain_changes': 'Explain changes *',
  'what_needs_improvement': 'What needs improvement...',
  'approval': 'Approval',
  'ticket_will_be_closed': 'Ticket will be closed',
  'no_further_work': 'No further work',
  'returns_to_in_progress': 'Returns to in-progress',
  'admin_sees_feedback': 'Admin sees feedback',
  'please_add_approval_notes': 'Please add approval notes',
  'ticket_approved_and_closed': 'Ticket approved and closed successfully',
  'ticket_returned_for_more_work': 'Ticket returned for more work',
  'error_submitting_approval': 'Error submitting approval',
  'calculating': 'Calculating...',
  'expired_auto_closing_now': 'EXPIRED - Auto-closing now',
  'days': 'days',
  'day': 'day',
  'hours': 'hours',
  'hour': 'hour',
  'minutes': 'minutes',
  'minute': 'minute',
  'seconds': 'seconds',
  'time_expired_auto_approval_now':
      '🚨 TIME EXPIRED: This ticket will be automatically approved NOW!',
  'urgent_auto_approval_in': '⚠️ URGENT: Auto-approval in',
  'warning_auto_approval_in': '⏰ Warning: Auto-approval in',

  // Assign Ticket Dialog
  'assign_ticket': 'Assign Ticket',
  'matching_admins_shown_first': 'Matching admins shown first',
  'no_available_admins_found': 'No available admins found.',
  'match': 'MATCH',
  'please_select_admin': 'Please select an admin',
  'ticket_assigned_successfully': 'Ticket assigned successfully',
  'error_assigning_ticket': 'Error assigning ticket',

  // Finish Ticket Dialog
  'mark_ticket_finished': 'Mark Ticket Finished',
  'auto_approval_after_monitoring': 'Auto-approval after monitoring period',
  'creator_will_review_work': 'Creator will review your work',
  'report_title': 'Report Title',
  'brief_summary': 'Brief summary',
  'add': 'Add',
  'mark_supervised': 'Mark Supervised',
  'submit': 'Submit',
  'ticket_marked_under_supervision':
      'Ticket marked as under supervision. It will be automatically approved after the monitoring period.',
  'work_report_submitted_success':
      'Work report submitted successfully. Awaiting creator approval.',
  'failed_to_submit_report': 'Failed to submit report. Please try again.',

  // Image Gallery Viewer
  'image_details': 'Image Details',
  'name': 'Name',
  'size': 'Size',
  'type': 'Type',
  'uploaded': 'Uploaded',
  'close': 'Close',
  'share_not_implemented': 'Share not implemented — add your logic',
  'failed_to_load_image': 'Failed to load image',
  'unknown_file': 'Unknown file',
  'loading_image': 'Loading image...',
  'previous': 'Previous',
  'next': 'Next',
  // Wrong Info Dialog
  'mark_as_wrong_information': 'Mark as Wrong Information',
  'provide_feedback_incorrect':
      'Please provide feedback about what information is incorrect or missing:',
  'feedback': 'Feedback',
  'explain_what_needs_corrected': 'Explain what needs to be corrected...',
  'mark_as_wrong_info': 'Mark as Wrong Info',
  'ticket_marked_wrong_information': 'Ticket marked as wrong information',
  'error_marking_wrong_info': 'Error marking as wrong info',
  'please_provide_feedback': 'Please provide feedback',

  // Create Subticket
  'parent_ticket': 'Parent Ticket',
  'subticket_title': 'Subticket Title',
  'brief_description_subtask': 'Brief description of the sub-task',
  'detailed_description_todo': 'Detailed description of what needs to be done',
  'target_department': 'Target Department',
  'select_department_subtask': 'Select department to handle this sub-task',
  'nature_of_work': 'Nature of Work',
  'select_nature_of_work': 'Select nature of work',
  'no_nature_of_work_available':
      'No nature of work options available for this department.',
  'high_priority_explanation': 'High Priority Explanation',
  'explain_why_urgent': 'Explain why this is urgent/high priority',
  'no_files_selected': 'No files selected',
  'files_selected': 'files selected',
  'file': 'file',
  'subticket_information': 'Subticket Information',
  'subticket_will_be_linked': 'Subticket will be linked to parent ticket',
  'can_be_assigned_different_dept': 'Can be assigned to a different department',
  'helps_break_down_tasks': 'Helps break down complex tasks',
  'parent_can_track_subtickets': 'Parent ticket can track all subtickets',
  'uploading': 'Uploading...',
  'creating': 'Creating...',
  'error_picking_files': 'Error picking files',
  'error_picking_images': 'Error picking images',
  'please_fill_all_required': 'Please fill all required fields',
  'please_explain_high_priority':
      'Please explain why this is high/urgent priority',
  'please_enter_phone_number': 'Please enter phone number',
  'subticket_created_successfully': 'Subticket created successfully',
  'with_attachment': 'with attachment',
  'with_attachments': 'with attachments',
  'failed_to_create_subticket': 'Failed to create subticket',
  'it_solution_ticket_title': 'IT Solution Ticket',
  'it_brief_description': 'Brief description of the IT issue',
  'it_detailed_description': 'Detailed description of the IT problem',
  'it_ticket_info': 'IT Solution Ticket',
  'it_ticket_sent_to_dept': 'This ticket will be sent to IT Department',
  'provide_detailed_info': 'Provide detailed information for faster resolution',
  'attach_screenshots': 'Attach screenshots if applicable',
  'you_will_be_notified': 'You will be notified of any updates',
  'create_ticket': 'Create Ticket',

  // Places Maintenance Ticket
  'places_maintenance_ticket_title': 'Places Maintenance Ticket',
  'places_brief_description': 'Brief description of the maintenance issue',
  'places_detailed_description': 'Detailed description of the problem',
  'select_place': 'Select place',
  'place_info': 'Place',
  'place_locked_for_user': 'Place: ',
  'specific_location': 'Specific Location',
  'specific_location_hint': 'Room number, floor, etc.',
  'problem_title': 'Problem Title',
  'select_problem_type': 'Select problem type',
  'enter_custom_problem': 'Enter custom problem title',
  'custom_problem_title': 'Custom Problem Title',
  'describe_problem': 'Describe the problem',
  'model_number': 'Model Number',
  'select_device_part': 'Select device/part',
  'enter_custom_model': 'Enter custom model number',
  'custom_model_number': 'Custom Model Number',
  'enter_model_number': 'Enter model number',
  'places_ticket_info': 'Places Maintenance Ticket',
  'fill_required_fields': 'Fill all required fields (*)',
  'provide_accurate_location': 'Provide accurate location details',
  'add_photos_if_possible': 'Add photos of the issue if possible',
  'notified_when_work_begins': 'You will be notified when work begins',

  // Individuals Maintenance Ticket
  'individuals_maintenance_ticket_title': 'Individuals Maintenance Ticket',
  'individuals_brief_description': 'Brief description of the issue',
  'individuals_detailed_description': 'Detailed description of the problem',
  'place_individual_info': 'Place: Individual (Not tied to specific location)',
  'specific_location_optional': 'Specific Location (Optional)',
  'where_individual_located': 'Where is this individual located?',
  'individuals_ticket_info': 'Individuals Maintenance Ticket',
  'for_issues_related_individuals':
      'For issues related to individuals (not tied to places)',
  'add_photos_documents': 'Add photos or documents if helpful',
  'track_ticket_status': 'Track your ticket status in the system',

  // Requests Ticket
  'requests_ticket_title': 'Request Ticket',
  'request_title': 'Request Title',
  'what_are_you_requesting': 'What are you requesting?',
  'request_description': 'Request Description',
  'detailed_request_description': 'Detailed description of your request',
  'select_department_handle_request': 'Select department to handle request',
  'where_items_delivered': 'Where should items/services be delivered?',
  'requests_ticket_info': 'Request Ticket',
  'use_for_requesting_items': 'Use this for requesting items or services',
  'commonly_used_inter_dept': 'Commonly used for inter-department requests',
  'can_be_used_subtickets': 'Can also be used in subtickets',
  'track_request_status': 'Track the status of your request',
  'create_request': 'Create Request',

  // Common across all dialogs
  'title_required': 'Title *',
  'description_required': 'Description *',
  'target_department_required': 'Target Department *',
  'nature_of_work_required': 'Nature of Work *',
  'priority_required': 'Priority *',
  'high_priority_explanation_required': 'High Priority Explanation *',
  'explain_high_urgent_priority': 'Explain why this is urgent/high priority',
  'model_number_optional': 'Model Number (Optional)',
  'phone_number': 'Phone Number',
  'attachments_section': 'Attachments',
  'no_nature_work_for_dept':
      'No nature of work options available for this department.',
  'please_select_problem_or_custom':
      'Please select problem title or enter custom',
  'please_enter_custom_problem': 'Please enter custom problem title',
  'it_ticket_created_successfully':
      'IT Solution Ticket #{ticketNumber} created successfully',
  'places_ticket_created_successfully':
      'Places Maintenance Ticket #{ticketNumber} created successfully',
  'individuals_ticket_created_successfully':
      'Individuals Maintenance Ticket #{ticketNumber} created successfully',
  'requests_ticket_created_successfully':
      'Request Ticket #{ticketNumber} created successfully',
  'with_attachment_count': 'with {count} attachment',
  'with_attachments_count': 'with {count} attachments',
  'failed_create_ticket': 'Failed to create ticket',
  'creating_corrected_ticket_from': 'Creating corrected ticket from',
  'please_review_and_update': 'Please review and update the information below.',
  'phone_number_required': 'Phone Number *',
  'contact_phone_number': 'Contact phone number',
  'please_select_nature_of_work': 'Please select nature of work',
  'please_specify_other_nature_of_work': 'Please specify other nature of work',
  'please_specify_other_place': 'Please specify other place',
  'specify_nature_of_work': 'Specify Nature of Work *',
  'describe_nature_of_work': 'Describe the nature of work',
  'no_nature_work_available_click_below':
      'No nature of work options available. Click below to specify.',
  'specify_other': 'Specify Other',
  'specify_place': 'Specify Place *',
  'enter_place_name': 'Enter place name',
  'specify_problem_title': 'Specify Problem Title',
  'specify_model_number': 'Specify Model Number',
  'ticket_information': 'Ticket Information',
  'make_sure_all_required_fields_filled':
      'Make sure all required fields (*) are filled',
  'provide_accurate_phone_number': 'Provide accurate phone number for contact',
  'add_detailed_description': 'Add detailed description for faster resolution',
  'attach_relevant_images': 'Attach relevant images or documents if available',
  'use_other_option_if_not_in_list':
      'Use "Other" option if your choice is not in the list',
  'ticket_created_successfully_with': 'created successfully with',
  'ticket_created_successfully': 'created successfully',
  'other_specify': 'Other (Specify)',
  'no_results_found': 'No results found',
  'select': 'Select',
  'it_department_not_found': 'IT Department not found',
  'quality_complaints': 'Quality Complaints',
  'all_complaints': 'All Complaints',
  'complainant': 'Complainant',
  'complainant_name': 'Complainant Name',
  'receiver': 'Receiver',
  'complaint_receiver': 'Complaint Receiver',
  'item': 'Item',
  'batch_number': 'Batch Number',
  'quantity': 'Quantity',
  'produce_date': 'Produce Date',
  'expired_date': 'Expired Date',
  'complaint_type': 'Complaint Type',
  'complaint_description': 'Complaint Description',
  'technical': 'Technical',
  'coordination_delivery': 'Coordination & Delivery',
  'complaint_check': 'Complaint Check',
  'complaint_valid': 'Complaint Valid',
  'complaint_invalid': 'Complaint Invalid',
  'check_report': 'Check Report',
  'therapeutic_procedure': 'Therapeutic Procedure',
  'checker': 'Checker',
  'check_date': 'Check Date',
  'signed_document': 'Signed Document',
  'upload_signed': 'Upload Signed',
  'download_pdf': 'Download PDF',
  'check_complaint': 'Check Complaint',
  'assign_complaint': 'Assign Complaint',
  'no_complaints_found': 'No complaints found',
  'complaint_number': 'Complaint Number',
  'select_admin': 'Select Admin',
  'admins_available': 'admins available',
  'no_admins_available': 'No admins available in your department',
  'complaint_assigned_successfully': 'Complaint assigned successfully',
  'error_assigning_complaint': 'Error assigning complaint',
  'please_select_an_admin': 'Please select an admin',
  'select_admin_from_department':
      'Select an admin from your department to assign this complaint',
  'report_required': 'Report *',
  'enter_detailed_check_report': 'Enter detailed check report...',
  'therapeutic_procedure_optional': 'Therapeutic Procedure (Optional)',
  'enter_therapeutic_procedure': 'Enter therapeutic procedure if applicable...',
  'add_images_optional': 'Add Images (Optional)',
  'after_submission': 'After submission:',
  'status_will_change_prefinished': '• Status will change to Pre-Finished',
  'pdf_report_auto_download': '• PDF report will auto-download',
  'can_print_sign_upload':
      '• You can print, sign, and upload the signed document',
  'submit_check': 'Submit Check',
  'please_enter_report': 'Please enter report',
  'check_submitted_successfully': 'Check submitted successfully',
  'error_submitting_check': 'Error submitting check',
  'yes': 'Yes',
  'no': 'No',
  'check_images': 'Check Images',
  'initial_attachments': 'Initial Attachments',
  'images_count': 'Images',
  'documents_count': 'Documents',
  'no_initial_attachments': 'No initial attachments uploaded',
  'initial': 'Initial',
  'check': 'Check',
  'signed': 'Signed',
  'zoom_in': 'Zoom In',
  'zoom_out': 'Zoom Out',
  'reset_zoom': 'Reset Zoom',
  'download': 'Download',
  'downloading_image': 'Downloading image...',
  'image_downloaded_successfully': 'Image downloaded successfully',
  'failed_to_download_image': 'Failed to download image',
  'download_not_supported':
      'Download feature is currently available on web only.\nYou can view and screenshot images instead.',
  'generating_pdf': 'Generating PDF...',
  'pdf_generated_successfully': 'PDF generated successfully',
  'error_generating_pdf': 'Error generating PDF',
  'no_check_report_available': 'No check report available for this complaint',
  'loading_check_data': 'Loading check data...',
  'no_check_record_found': 'No check record found for this complaint',
  'error_loading_check_data': 'Error loading check data',
  'replace_signed_document': 'Replace Signed Document?',
  'signed_document_exists':
      'A signed document already exists for this complaint. Do you want to replace it?',
  'replace': 'Replace',
  'could_not_read_file': 'Could not read file',
  'file_size_exceeds_limit': 'File size exceeds 50MB limit',
  'uploading_pdf': 'Uploading PDF...',
  'uploading_image': 'Uploading image...',
  'signed_pdf_uploaded': 'Signed PDF uploaded successfully',
  'signed_image_uploaded': 'Signed image uploaded successfully',
  'failed_upload_signed': 'Failed to upload signed document',
  'error_uploading': 'Error',
  'select_file_pdf_or_image': 'Select PDF or Image file (PDF, JPG, PNG)',
  'create_complaint': 'Create Complaint',
  'create_quality_complaint': 'Create Quality Complaint',
  'complaint_form': 'Complaint Form',
  'receiver_name': 'Receiver Name',
  'complainant_information': 'Complainant Information',
  'complainants_name': "Complainant's Name",
  'mobile_number': 'Mobile Number',
  'phone_number_optional': 'Phone Number (Optional)',
  'product_information': 'Product Information',
  'select_item': 'Select Item',
  'please_select_item': 'Please select an item',
  'batch_number_optional': 'Batch Number (Optional)',
  'quantity_optional': 'Quantity (Optional)',
  'select_produce_date': 'Select produce date',
  'select_expired_date': 'Select expired date',
  'complaint_details': 'Complaint Details',
  'describe_issue_detail': 'Describe the issue in detail...',
  'select_complaint_type': 'Select complaint type',
  'add_images': 'Add Images',
  'submit_complaint': 'Submit Complaint',
  'complaint_created_successfully': 'Quality complaint created successfully',
  'error_creating_complaint': 'Error creating complaint',
  'please_enter_complainant_name': "Please enter complainant's name",
  'please_enter_location': 'Please enter location',
  'please_enter_mobile': 'Please enter mobile number',
  'loading_items': 'Loading items...',
  'no_items_available': 'No items available',
  'product_details': 'Product Details',
  'no_item': 'No Item',
  'assign_to_admin': 'Assign to Admin',
  'check_and_validate': 'Check & Validate',
  'view_report': 'View Report',
  'complaint_checked_by': 'Checked by',
  'is_valid': 'Is Valid',
  'check_details': 'Check Details',
  'no_check_data': 'No check data available',
  'therapeutic_procedure_details': 'Therapeutic Procedure Details',
  'not_applicable': 'N/A',
  'documents': 'documents',

  'after_submission_info':
      '• Status will change to Pre-Finished\n• PDF report will auto-download\n• You can print, sign, and upload the signed document',
  'loading_admins': 'Loading admins...',
  'error_loading_admins': 'Error loading admins',
  'available': 'available',
  'report': 'report',
  'enter_therapeutic_procedure_if_applicable':
      'Enter therapeutic procedure if applicable',
  'chat_rooms': 'Chat Rooms',
  'recent_conversations': 'Recent Conversations',
  'unread': 'unread',
  'no_active_chat_rooms': 'No active chat rooms',
  'chat_rooms_appear_when_tickets_in_progress':
      'Chat rooms appear when tickets are in progress',
  'select_conversation_to_start_chatting':
      'Select a conversation to start chatting',
  'choose_from_active_tickets_on_left':
      'Choose from your active tickets on the left',
  'no_messages_yet': 'No messages yet',
  'start_conversation': 'Start a conversation!',
  'type_message': 'Type a message...',
  'sending_messages': 'Sending {count} message(s)...',
  'scroll_to_latest': 'Scroll to latest',
  'reconnecting': 'Reconnecting...',
  'loading_chat_rooms': 'Loading chat rooms...',
  'someone': 'Someone',
  'you': 'You',
  'user': 'User',
  'now': 'now',

  // Add to _enValues:
  'departments': 'Departments',
  'create_department': 'Create Department',
  'name_is_required': 'Name is required',
  'department_created_successfully': 'Department created successfully',
  'failed_to_create_department': 'Failed to create department',
  'department_activated': 'Department activated',
  'department_deactivated': 'Department deactivated',
  'failed_to_update_department': 'Failed to update department',
  'total': 'total',
  'no_departments_yet': 'No departments yet',
  'create_your_first_department': 'Create your first department',

  'places': 'Places',
  'create_place': 'Create Place',
  'place_created_successfully': 'Place created successfully',
  'failed_to_create_place': 'Failed to create place',
  'place_activated': 'Place activated',
  'place_deactivated': 'Place deactivated',
  'failed_to_update_place': 'Failed to update place',
  'no_places_yet': 'No places yet',
  'create_your_first_place': 'Create your first place',

  'users': 'Users',
  'add_user': 'Add User',
  'of': 'of',
  'no_users_yet': 'No users yet',
  'create_your_first_user': 'Create your first user',
  'user_activated': 'User activated',
  'user_deactivated': 'User deactivated',
  'remove_user': 'Remove User',
  'confirm_remove_user': 'Are you sure you want to remove',
  'user_removed': 'User removed',
  'restore_user': 'Restore User',
  'user_restored': 'User restored',
  'failed_to_update_user_status': 'Failed to update user status',

  'activity_logs': 'Activity Logs',
  'entries': 'entries',
  'search_action_table_user': 'Search action, table, user…',
  'all_actions': 'All Actions',
  'no_logs_found': 'No logs found',
  'load_more': 'Load more',
  'changed_from': 'from',
  'changed_to': 'to',
  'new_record': 'New record',
  'deleted_record': 'Deleted record',
  'details': 'Details',
  'system': 'System',
  'all': 'All',
  'ai_insights': 'AI Insights',
  'analyze_with_ai': 'Analyze with AI',
  'ai_insights_hint': 'Select filters and tap Analyze to get AI-powered insights',
  'ai_summary': 'AI Summary',
  'top_problem_places': 'Top Problem Places',
  'recurring_issues': 'Recurring Issues',
  'root_causes': 'Root Causes',
  'replacement_recommendations': 'Replacement Recommendations',
  'prevention_suggestions': 'Prevention Suggestions',
  'smart_title_suggestions': 'Smart Title Suggestions',
  'select_department': 'Select Department',
  'saved_successfully': 'Saved successfully',

  'problem_titles': 'Problem Titles',
  'create_problem_title': 'Create Problem Title',
  'problem_title_created_successfully': 'Problem title created successfully',
  'failed_to_create_problem_title': 'Failed to create problem title',
  'no_problem_titles_yet': 'No problem titles yet',
  'create_your_first_problem_title': 'Create your first problem title',
  'search_problem_titles': 'Search problem titles...',

  'parts': 'Parts',
  'create_part': 'Create Part',
  'model_number_required': 'Model number is required',
  'name_and_model_required': 'Name and model number are required',
  'part_created_successfully': 'Part created successfully',
  'failed_to_create_part': 'Failed to create part',
  'no_parts_yet': 'No parts yet',
  'create_your_first_part': 'Create your first part',
  'search_parts': 'Search parts...',

  'nature_of_work_management': 'Nature of Work',
  'create_nature_of_work': 'Create Nature of Work',
  'nature_of_work_created_successfully': 'Nature of work created successfully',
  'failed_to_create_nature_of_work': 'Failed to create nature of work',
  'deactivated_successfully': 'Deactivated successfully',
  'activated_successfully': 'Activated successfully',
  'failed_to_update_status': 'Failed to update status',
  'no_nature_of_work_yet': 'No nature of work yet',
  'define_your_first_nature_of_work': 'Define your first nature of work',
  'search_nature_of_work': 'Search nature of work...',

  'complaint_items': 'Complaint Items',
  'create_complaint_item': 'Create Complaint Item',
  'item_name_required': 'Item name is required',
  'item_created_successfully': 'Item created successfully',
  'failed_to_create_item': 'Failed to create item',
  'item_activated': 'Item activated',
  'item_deactivated': 'Item deactivated',
  'failed_to_update_item': 'Failed to update item',
  'no_complaint_items_yet': 'No complaint items yet',
  'create_your_first_item': 'Create your first item',
  'search_items': 'Search items...',
  'item_name': 'Item Name',

  'complaint_permissions': 'Complaint Permissions',
  'manage_department_access': 'Manage department access',
  'enable_complaint_access_description':
      'Enable complaint access for departments that need to manage quality complaints',
  'search_departments': 'Search departments...',
  'no_departments_found': 'No departments found',
  'no_departments_match_search': 'No departments match your search',
  'can_access_complaints': 'Can access complaints',
  'no_complaint_access': 'No complaint access',
  'complaint_access_enabled': 'Complaint access enabled',
  'complaint_access_disabled': 'Complaint access disabled',
  'failed_to_update_permission': 'Failed to update permission',

  'auto_approval_settings': 'Auto-Approval Settings',
  'automatically_approve_prefinished_tickets':
      'Automatically approve pre-finished tickets',
  'about_auto_approval': 'About auto-approval',
  'auto_approval_info_1':
      'Tickets in "Pre-Finished" status will be automatically approved after the configured time',
  'auto_approval_info_2':
      'Creator notes will be empty for auto-approved tickets',
  'auto_approval_info_3': 'The system checks periodically for eligible tickets',
  'auto_approval_info_4': 'Minimum time is 1 minute (for testing)',
  'current_auto_approval_time': 'Current Auto-Approval Time',
  'edit_time': 'Edit time',
  'tickets_ready_for_auto_approval': 'ticket(s) ready for auto-approval',
  'approve_now': 'Approve Now',
  'how_it_works': 'How it works',
  'set_auto_approval_time': 'Set Auto-Approval Time',
  'minimum_1_minute': 'Minimum: 1 minute',
  'common_values': 'Common values:',
  'update': 'Update',
  'please_enter_valid_number': 'Please enter a valid number (minimum 1)',
  'trigger_auto_approval': 'Trigger Auto-Approval',
  'this_will_immediately_auto_approve':
      'This will immediately auto-approve {count} ticket(s) that have exceeded the time limit.\n\nAre you sure you want to continue?',
  'auto_approval_completed_successfully':
      'Auto-approval completed successfully',
  'error_triggering_auto_approval': 'Error triggering auto-approval',
  'current_status': 'Current Status',
  'push': 'Push',
  'on': 'ON',
  'off': 'OFF',

  'auto_assignment_settings': 'Auto-Assignment Settings',
  'automatically_assign_new_tickets': 'Automatically assign new tickets',
  'auto_assignment_how_it_works_1':
      'When enabled, all new tickets targeted to your department will be automatically assigned to the selected admin',
  'auto_assignment_how_it_works_2':
      'Tickets will immediately have "In Progress" status',
  'auto_assignment_how_it_works_3':
      'Both the ticket creator and assigned admin will receive notifications',
  'auto_assignment_how_it_works_4':
      'You can change or disable this at any time',
  'auto_assignment_status': 'Auto-Assignment Status',
  'new_tickets_will_be_automatically_assigned':
      'New tickets will be automatically assigned',
  'new_tickets_will_require_manual_assignment':
      'New tickets will require manual assignment',
  'assign_new_tickets_to': 'Assign New Tickets To',
  'choose_which_admin_will_receive':
      'Choose which admin will receive auto-assigned tickets',
  'no_normal_admins_found':
      'No normal admins found in your department. Please create admin users first.',
  'selected_admin': 'Selected Admin',
  'saving_settings': 'Saving settings...',
  'auto_assignment_is_active':
      'Auto-assignment is active. New tickets will be assigned to',
  'access_restricted': 'Access Restricted',
  'only_super_admins_can_manage':
      'Only Super Admins can manage auto-assignment settings',
  'please_select_admin_before_enabling':
      'Please select an admin before enabling auto-assignment',
  'auto_assignment_enabled_successfully':
      'Auto-assignment enabled successfully',
  'auto_assignment_disabled_successfully':
      'Auto-assignment disabled successfully',
  'failed_to_save_settings': 'Failed to save settings',

  'notification_preferences': 'Notification Preferences',
  'manage_how_you_receive_notifications':
      'Manage how you receive notifications',
  'about_notifications': 'About notifications',
  'notifications_info_1': 'Control which types of notifications you receive',
  'notifications_info_2': 'Choose between push notifications and emails',
  'notifications_info_3': 'Settings apply to all devices',
  'notifications_info_4': 'Changes take effect immediately',
  'push_notifications': 'Push Notifications',
  'enable_push_notifications': 'Enable Push Notifications',
  'receive_push_notifications_on_device':
      'Receive push notifications on your device',
  'chat_message_notifications': 'Chat Message Notifications',
  'get_notified_new_chat_messages':
      'Get notified when you receive new chat messages',
  'email_notifications': 'Email Notifications',
  'enable_email_notifications': 'Enable Email Notifications',
  'receive_notifications_via_email': 'Receive notifications via email',
  'could_not_load_preferences': 'Could not load preferences',
  'preferences_updated_successfully': 'Preferences updated successfully',
  'failed_to_update_preferences': 'Failed to update preferences',
  'failed_to_load_preferences': 'Failed to load preferences',
  'no_permission_to_create_users':
      'You do not have permission to create users.',
  'create_new_user': 'Create New User',
  'create_user': 'Create User',
  'please_select_department_for_admin_users':
      'Please select a department for admin users',
  'please_select_place_for_super_users':
      'Please select a place for super users',
  'user_created_successfully':
      'User created successfully and credentials sent via email',
  'failed_to_create_user': 'Failed to create user',
  'add_nature_of_work_and_press_enter': 'Add nature of work and press Enter',
  'edit_user': 'Edit User',
  'nature_of_work_expertise': 'Nature of Work Expertise',
  'select_types_of_work_admin_specializes_in':
      'Select the types of work this admin specializes in',
  'update_user': 'Update User',
  'please_fill_full_name_field': 'Please fill the full name field',
  'user_updated_successfully': 'User updated successfully',
  'failed_to_update_user': 'Failed to update user',
  'example_network_issues_hardware_repair':
      'e.g., Network Issues, Hardware Repair',
  'no_nature_of_work_found': 'No nature of work found',
  'try_adjusting_search': 'Try adjusting your search',
  'example_product_x_service_y': 'e.g., Product X, Service Y',
  'add_item': 'Add Item',
  'no_items_found': 'No items found',
  'loading_settings': 'Loading settings...',
  'permissions': 'Permissions',
  'auto_approval': 'Auto-Approval',
  'logs': 'Logs',
  'preferences': 'Preferences',
  'auto_assign': 'Auto-Assign',
  'reports': 'Reports',
  'invalid_tab': 'Invalid tab',
  'no_management_options_available': 'No management options available',
  'saving_preferences': 'Saving preferences...',
  // Problem Titles
  'problem_title_updated_successfully': 'Problem title updated successfully',
  'failed_to_update_problem_title': 'Failed to update problem title',
  'delete_problem_title': 'Delete Problem Title',
  'are_you_sure_delete_problem_title':
      'Are you sure you want to delete this problem title?',
  'problem_title_deleted_successfully': 'Problem title deleted successfully',
  'failed_to_delete_problem_title': 'Failed to delete problem title',
  'failed_to_delete_item': 'Failed to delete item',

// Parts
  'part_updated_successfully': 'Part updated successfully',
  'failed_to_update_part': 'Failed to update part',
  'delete_part': 'Delete Part',
  'are_you_sure_delete_part': 'Are you sure you want to delete this part?',
  'part_deleted_successfully': 'Part deleted successfully',
  'failed_to_delete_part': 'Failed to delete part',

// Nature of Work
  'nature_of_work_updated_successfully': 'Nature of work updated successfully',
  'failed_to_update_nature_of_work': 'Failed to update nature of work',
  'delete_nature_of_work': 'Delete Nature of Work',
  'are_you_sure_delete_nature_of_work':
      'Are you sure you want to delete this nature of work?',
  'nature_of_work_deleted_successfully': 'Nature of work deleted successfully',
  'failed_to_delete_nature_of_work': 'Failed to delete nature of work',

// Complaint Items
  'item_updated_successfully': 'Item updated successfully',
  'delete_complaint_item': 'Delete Complaint Item',
  'are_you_sure_delete_item': 'Are you sure you want to delete this item?',
  'item_deleted_successfully': 'Item deleted successfully',
  'department_updated_successfully': 'Department updated successfully',
  'delete_department': 'Delete Department',
  'are_you_sure_delete_department': 'Are you sure you want to delete',
  'department_deleted_successfully': 'Department deleted successfully',
  'failed_to_delete_department': 'Failed to delete department',

  'place_updated_successfully': 'Place updated successfully',
  'delete_place': 'Delete Place',
  'are_you_sure_delete_place': 'Are you sure you want to delete',
  'place_deleted_successfully': 'Place deleted successfully',
  'failed_to_delete_place': 'Failed to delete place',

  // In _enValues (English translations):
  'realtime_updates_paused': 'Real-time updates paused',
  'reconnect': 'Reconnect',
  'you_started_working_on_ticket': 'You started working on this ticket',
  'take_over': 'Take Over',
  'take_over_ticket': 'Take Over Ticket',
  'ticket_currently_assigned_to': 'This ticket is currently assigned to',
  'are_you_sure_take_over_ticket':
      'Are you sure you want to take over this ticket?',
  'ticket_taken_over_successfully': 'Ticket taken over successfully',
  'error_starting_work': 'Error starting work',
  'error_taking_over': 'Error taking over',
  "branch_admins": "Branch Admins",
  "branch_admin_management": "Branch Admin Management",
  "branch_admin_management_description":
      "Manage branch administrators and their assigned locations",
  "no_branch_admins_yet": "No Branch Admins Yet",
  "create_branch_admins_in_user_management":
      "Create branch admin users in user management first",
  "search_branch_admins": "Search branch admins...",
  "edit_places_for": "Edit Places for",
  "no_places_assigned": "No places assigned",
  "places_updated_successfully": "Places updated successfully",
  "failed_to_update_places": "Failed to update places",
  "edit_places": "Edit Places",
  "showing_my_tickets": "Showing my tickets only",
  "showing_all_place_tickets": "Showing all place tickets",
  "my_tickets": "Mine",
  "security": "Security",
  "change_password": "Change Password",
  "current_password": "Current Password",
  "new_password": "New Password",
  "confirm_new_password": "Confirm New Password",
  "password_updated_successfully": "Password updated successfully",
  "incorrect_current_password": "Incorrect current password",
  "password_too_short": "Password must be at least 6 characters",
  "reset_password": "Reset Password",
  "reset_password_with_otp": "Reset Password with OTP",
  "send_otp": "Send OTP",
  "enter_otp": "Enter OTP",
  "otp_sent_to_email": "A 6-digit code was sent to your email",
  "verify_and_set_password": "Verify & Set Password",
  "invalid_otp": "Invalid OTP code",
  "otp_expired_or_invalid": "OTP expired or invalid. Please try again.",
  "enter_your_email": "Enter your email",
  "step1_send_otp": "Step 1: Send OTP",
  "step2_enter_otp": "Step 2: Enter OTP & New Password",
  "forgot_password": "Forgot Password?",
};

// Arabic translations
const Map<String, String> _arValues = {
  'app_name': 'Jala Ticketing',
  'welcome_back': 'مرحباً بعودتك،',
  'dashboard': 'لوحة التحكم',
  'tickets': 'التذاكر',
  'chat': 'المحادثة',
  'notifications': 'الإشعارات',
  'complaints': 'الشكاوى',
  'management': 'الإدارة',
  'profile': 'الملف الشخصي',
  'sign_in': 'تسجيل الدخول',
  'sign_out': 'تسجيل الخروج',
  'register': 'تسجيل',
  'email': 'البريد الإلكتروني',
  'password': 'كلمة المرور',
  'confirm_password': 'تأكيد كلمة المرور',
  'full_name': 'الاسم الكامل',
  'phone': 'رقم الهاتف',
  'language': 'اللغة',
  'select_your_place': 'اختر موقعك',
  'create_account': 'إنشاء حساب',
  'already_have_account': 'لديك حساب بالفعل؟',
  'dont_have_account': 'ليس لديك حساب؟',
  'sign_in_here': 'سجل دخولك هنا',
  'register_here': 'سجل هنا',
  'loading': 'جاري التحميل...',
  'loading_dashboard': 'جاري تحميل لوحة التحكم...',
  'pending': 'قيد الانتظار',
  'in_progress': 'قيد التنفيذ',
  'prefinished': 'شبه منتهي',
  'completed': 'مكتمل',
  'closed': 'مغلق',
  'ticket_overview': 'نظرة عامة على التذاكر',
  'ticket_distribution': 'توزيع التذاكر',
  'recent_tickets': 'التذاكر الأخيرة',
  'view_all': 'عرض الكل',
  'no_recent_tickets': 'لا توجد تذاكر حديثة',
  'no_tickets_in_progress': 'لا توجد تذاكر قيد التنفيذ',
  'no_ticket_data': 'لا توجد بيانات تذاكر متاحة',
  'mobile': 'موبايل',
  'web': 'ويب',
  'web_dashboard': 'لوحة التحكم - ويب',
  'in_progress_tickets': 'التذاكر قيد التنفيذ',
  'view_all_tickets': 'عرض جميع التذاكر',
  'no_notifications': 'لا توجد إشعارات',
  'youll_see_updates_here': 'ستظهر التحديثات هنا',
  'mark_all_read': 'تحديد الكل',
  'mark_all_as_read': 'تحديد الكل كمقروء',
  'new_message_in': 'رسالة جديدة في',
  'new_message_from': 'رسالة جديدة من',
  'ticket_created': 'تذكرة جديدة',
  'ticket_assigned': 'تم تعيين التذكرة',
  'ticket_status_changed': 'تغيرت الحالة',
  'ticket_approved': 'تمت الموافقة',
  'ticket_rejected': 'تم الرفض',
  'new_message': 'رسالة جديدة',
  'chat_mention': 'ذكر في المحادثة',
  'subticket_created': 'تذكرة فرعية جديدة',
  'update_profile': 'تحديث الملف الشخصي',
  'account_information': 'معلومات الحساب',
  'edit_information': 'تعديل المعلومات',
  'user_type': 'نوع المستخدم',
  'status': 'الحالة',
  'active': 'نشط',
  'inactive': 'غير نشط',
  'member_since': 'عضو منذ',
  'tap_camera_to_change': 'اضغط على أيقونة الكاميرا لتغيير صورة الملف الشخصي',
  'profile_updated_successfully': 'تم تحديث الملف الشخصي بنجاح',
  'failed_to_update_profile': 'فشل تحديث الملف الشخصي',
  'profile_image_updated_successfully': 'تم تحديث صورة الملف الشخصي بنجاح',
  'failed_to_upload_image': 'فشل تحميل الصورة',
  'logout': 'تسجيل الخروج',
  'email_address': 'عنوان البريد الإلكتروني',
  'please_enter_your_email': 'الرجاء إدخال بريدك الإلكتروني',
  'please_enter_valid_email': 'الرجاء إدخال بريد إلكتروني صحيح',
  'please_enter_your_password': 'الرجاء إدخال كلمة المرور',
  'welcome_back_please_sign_in': 'مرحباً بعودتك! الرجاء تسجيل الدخول للمتابعة',
  'login_failed': 'فشل تسجيل الدخول. يرجى التحقق من بيانات الاعتماد.',
  'please_check_credentials': 'يرجى التحقق من بيانات الاعتماد',
  'registration_successful': 'نجح التسجيل',
  'account_created_successfully': 'تم إنشاء حسابك بنجاح!',
  'account_inactive_message':
      'حسابك غير نشط حالياً ويحتاج إلى تفعيل من قبل المسؤول.\n\nستتلقى إشعاراً عبر البريد الإلكتروني عند تفعيل حسابك.',
  'registration_failed': 'فشل التسجيل. يرجى المحاولة مرة أخرى.',
  'please_enter_full_name': 'الرجاء إدخال اسمك الكامل',
  'password_min_length': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
  'passwords_do_not_match': 'كلمات المرور غير متطابقة',
  'please_select_place': 'الرجاء اختيار موقع',
  'please_confirm_password': 'الرجاء تأكيد كلمة المرور',
  'optional': 'اختياري',
  'required': 'مطلوب',
  'registration_information': 'معلومات التسجيل',
  'account_will_be_inactive': 'سيتم إنشاء الحساب كحساب غير نشط',
  'admin_activation_required': 'يتطلب تفعيل من المسؤول',
  'email_notification_on_activation': 'إشعار عبر البريد عند التفعيل',
  'normal_user_account_only': 'نوع حساب مستخدم عادي فقط',
  'fill_in_your_information': 'املأ معلوماتك للبدء',
  'loading_places': 'جاري تحميل المواقع...',
  'no_places_available': 'لا توجد مواقع متاحة',
  'retry': 'إعادة المحاولة',
  'ok': 'موافق',
  'cancel': 'إلغاء',
  'save': 'حفظ',
  'delete': 'حذف',
  'edit': 'تعديل',
  'search': 'بحث',
  'filter': 'تصفية',
  'sort': 'ترتيب',
  'no_access_to_complaints': 'لا يوجد وصول إلى الشكاوى',
  'department_no_permission': 'قسمك ليس لديه إذن للوصول إلى وحدة الشكاوى.',
  'contact_system_admin': 'يرجى الاتصال بمسؤول النظام.',
  'error_loading_user': 'خطأ في تحميل المستخدم',
  'no_internet_connection': 'لا يوجد اتصال بالإنترنت',
  'connected': 'متصل',
  'disconnected': 'غير متصل',
  'search_tickets_places_creators': 'البحث في التذاكر، الأماكن، المنشئين...',
  'clear_all_filters': 'مسح جميع الفلاتر',
  'clear_all': 'مسح الكل',
  'place': 'المكان',
  'showPlace': 'تذاكر الفرع',
  'showMyTicket': 'تذاكري',
  'all_places': 'جميع الأماكن',
  'all_users': 'جميع المستخدمين',
  'removed': 'محذوف',
  'creator': 'المنشئ',
  'all_creators': 'جميع المنشئين',
  'date_range': 'نطاق التاريخ',
  'all_dates': 'جميع التواريخ',
  'sort_by_date': 'ترتيب حسب التاريخ',
  'sort_by_priority': 'ترتيب حسب الأولوية',
  'by_date': 'حسب التاريخ',
  'by_priority': 'حسب الأولوية',
  'date': 'التاريخ',
  'filters_and_sort': 'الفلاتر والترتيب',
  'create_new_ticket': 'إنشاء تذكرة جديدة',
  'it_solution_ticket': 'تذكرة حلول تقنية',
  'places_maintenance_ticket': 'تذكرة صيانة أماكن',
  'quality_complaint': 'شكوى جودة',
  'individuals_maintenance_ticket': 'تذكرة صيانة مشاكل فردية',
  'requests_ticket': 'تذكرة طلبات',
  'create': 'إنشاء',
  'refresh': 'تحديث',
  'connection_issues_detected':
      'تم اكتشاف مشاكل في الاتصال. قد لا تكون البيانات في الوقت الفعلي.',
  'connection_issues_detected_pull_to_refresh':
      'تم اكتشاف مشاكل في الاتصال. اسحب للتحديث يدوياً.',
  'no_tickets_found': 'لم يتم العثور على تذاكر',
  'try_adjusting_filters': 'حاول ضبط الفلاتر',
  'unknown': 'غير معروف',
  'close_chat': 'إغلاق المحادثة',
  'wrong_info': 'معلومات خاطئة',
  'deleted': 'محذوف',
  'checked_in_at': 'تسجيل دخول في',
  'elapsed': 'مضى',
  'subtickets': 'التذاكر الفرعية',
  'open_chat': 'فتح المحادثة',
  'approve_and_close': 'موافقة وإغلاق',
  'request_changes': 'طلب تغييرات',
  'basic_information': 'المعلومات الأساسية',
  'technical_details': 'التفاصيل التقنية',
  'description': 'الوصف',
  'work_tracking': 'تتبع العمل',
  'work_report': 'تقرير العمل',
  'approval_details': 'تفاصيل الموافقة',
  'work_rejected': 'العمل مرفوض',
  'information_issues': 'مشاكل المعلومات',
  'attachments': 'المرفقات',
  'recent_activity': 'النشاط الأخير',
  'title': 'العنوان',
  'created': 'تم الإنشاء',
  'updated': 'تم التحديث',
  'assigned_to': 'مكلف إلى',
  'other_place': 'مكان آخر',
  'location': 'الموقع',
  'department': 'القسم',
  'nature_of_problem': 'طبيعة المشكلة',
  'problem_type': 'نوع المشكلة',
  'custom_problem': 'مشكلة مخصصة',
  'part_device': 'جزء/جهاز',
  'custom_model': 'موديل مخصص',
  'priority_explanation': 'توضيح الأولوية',
  'images': 'الصور',
  'files': 'الملفات',
  'failed_to_load': 'فشل التحميل',
  'completed_by': 'أكمله',
  'report_attachments': 'مرفقات التقرير',
  'unknown_admin': 'مسؤول غير معروف',
  'approved_by': 'وافق عليه',
  'approval_notes': 'ملاحظات الموافقة',
  'work_rejected_by': 'رفض العمل من قبل',
  'rejection_reason': 'سبب الرفض',
  'issues_reported_by': 'المشاكل المبلغ عنها من قبل',
  'issues_to_address': 'المشاكل التي يجب معالجتها',
  'ticket_under_supervision_desc':
      'يتم مراقبة هذه التذكرة وسيتم الموافقة عليها تلقائياً',
  'supervision_info_creator':
      'تذكرتك تحت إشراف المسؤول. سيتم الموافقة عليها تلقائياً بعد فترة المراقبة.',
  'supervision_info_admin':
      'هذه التذكرة تحت الإشراف. فقط المسؤول المكلف يمكنه رفضها قبل الموافقة التلقائية.',
  'check_in': 'تسجيل دخول',
  'check_out': 'تسجيل خروج',
  'add_note': 'إضافة ملاحظة',
  'mark_finished': 'تحديد كمنتهي',
  'mark_under_supervision': 'تحديد تحت الإشراف',
  'reject_from_supervision': 'رفض من الإشراف',
  'review_and_approve': 'مراجعة وموافقة',
  'go_back': 'رجوع',
  'assign': 'تعيين',
  'start_work': 'بدء العمل',
  'create_subticket': 'إنشاء تذكرة فرعية',
  'create_corrected_ticket': 'إنشاء تذكرة مصححة',
  'low': 'منخفضة',
  'medium': 'متوسطة',
  'high': 'عالية',
  'urgent': 'عاجلة',
  'under_supervision': 'تحت المراقبة',
  'priority': 'الأولوية',
  'view_profile': 'معاينة الحساب',
  'visit_duration': 'مدة الزيارة',
  'check_in_time': 'تسجيل دخول',
  'duration': 'المدة',
  'visit_report': 'تقرير الزيارة',
  'work_performed': 'العمل المنجز...',
  'please_describe_work': 'يرجى وصف العمل الذي تم إنجازه',
  'checked_out_successfully': 'تم تسجيل الخروج بنجاح',
  'error_checking_out': 'خطأ في تسجيل الخروج',
  'add_tracking_point': 'إضافة نقطة تتبع',
  'tracking_type': 'نوع التتبع',
  'site_visit': 'زيارة موقع',
  'track_check_in_out_time': 'تتبع وقت الدخول/الخروج',
  'note': 'ملاحظة',
  'simple_update': 'تحديث بسيط',
  'time_tracking': 'تتبع الوقت',
  'not_checked_in': 'لم يتم تسجيل الدخول',
  'not_checked_out': 'لم يتم تسجيل الخروج',
  'visit_complete': 'اكتملت الزيارة',
  'what_work_performed': 'ما هو العمل الذي تم إنجازه خلال هذه الزيارة؟',
  'add_update_note': 'إضافة تحديث أو ملاحظة عن التذكرة...',
  'tracking_point_will_record':
      'ستسجل نقطة التتبع هذه زيارتك للموقع مع أوقات الدخول/الخروج.',
  'tracking_point_simple_note':
      'ستتم إضافة نقطة التتبع هذه كملاحظة بسيطة بدون تتبع الوقت.',
  'tracking_point_added_successfully': 'تمت إضافة نقطة التتبع بنجاح',
  'error_adding_tracking_point': 'خطأ في إضافة نقطة التتبع',
  'please_enter_description': 'يرجى إدخال وصف',
  'please_check_in_or_change_to_note':
      'يرجى تسجيل الدخول أو التغيير إلى ملاحظة بسيطة',
  'checked_out_at': 'تسجيل خروج في',
  'no_tracking_points_yet': 'لا توجد نقاط تتبع بعد',
  'site_visit_upper': 'زيارة موقع',
  'note_upper': 'ملاحظة',
  'add_tracking_note': 'إضافة ملاحظة تتبع',
  'note_description': 'وصف الملاحظة',
  'add_update_or_note': 'إضافة تحديث أو ملاحظة...',
  'note_added_without_time_tracking': 'تمت الإضافة بدون تتبع الوقت',
  'note_added_successfully': 'تمت إضافة الملاحظة بنجاح',
  'error_adding_note': 'خطأ في إضافة الملاحظة',
  'revert_ticket_status': 'إرجاع حالة التذكرة',
  'this_will_revert_ticket': 'سيؤدي هذا إلى إرجاع التذكرة',
  'from': 'من',
  'back_to': 'إلى',
  'changes_that_will_be_reverted': 'التغييرات التي سيتم إرجاعها:',
  'admin_assignment_will_be_removed': 'سيتم إزالة تعيين المسؤول',
  'ticket_will_return_unassigned': 'ستعود التذكرة إلى حالة غير مخصصة',
  'work_report_will_be_deleted': 'سيتم حذف تقرير العمل نهائياً',
  'all_report_attachments_removed': 'ستتم إزالة جميع مرفقات التقرير',
  'ticket_will_return_active_work': 'ستعود التذكرة إلى حالة العمل النشط',
  'approval_record_deleted': 'سيتم حذف سجل الموافقة',
  'all_attachments_removed': 'ستتم إزالة جميع المرفقات',
  'ticket_will_return_awaiting_approval':
      'ستعود التذكرة إلى حالة انتظار الموافقة',
  'work_report_will_remain': 'سيبقى تقرير العمل كما هو',
  'ticket_will_be_reverted_previous': 'ستتم إعادة التذكرة إلى الحالة السابقة',
  'this_action_cannot_be_undone':
      'لا يمكن التراجع عن هذا الإجراء تلقائياً. هل أنت متأكد؟',
  'are_you_sure': 'هل أنت متأكد؟',
  'revert_status': 'إرجاع الحالة',
  'delete_ticket': 'حذف التذكرة',
  'are_you_sure_delete_ticket': 'هل أنت متأكد من حذف التذكرة',
  'ticket_will_be_marked_deleted':
      'سيتم وضع علامة حذف على التذكرة ولكن يمكن للمسؤولين استعادتها إذا لزم الأمر.',
  'can_be_recovered_by_admin': 'يمكن استعادتها من قبل المسؤولين إذا لزم الأمر',
  'ticket_deleted_successfully': 'تم حذف التذكرة بنجاح',
  'error_deleting_ticket': 'خطأ في حذف التذكرة',
  'rejection_reason_required': 'سبب الرفض *',
  'please_provide_rejection_reason': 'يرجى تقديم سبب الرفض',
  'ticket_rejected_returned_in_progress':
      'تم رفض التذكرة وإعادتها إلى قيد التنفيذ',
  'rejection_reason_label': 'سبب الرفض',
  'why_work_being_rejected': 'لماذا يتم رفض العمل؟',
  'reject': 'رفض',
  'this_will_return_ticket_in_progress':
      'سيؤدي هذا إلى إعادة التذكرة إلى حالة قيد التنفيذ. يرجى تقديم السبب:',
  'please_provide_reason': 'يرجى تقديم السبب',
  'ticket_reverted_to': 'تم إرجاع التذكرة إلى',
  'previous_state_restored': 'تمت استعادة الحالة السابقة.',
  'error_reverting': 'خطأ في الإرجاع',
  'ticket_status_changed_to_in_progress':
      'تم تغيير حالة التذكرة إلى قيد التنفيذ',
  'error': 'هنالك خطأ ما',
  'review_completed_work': 'مراجعة العمل المكتمل',
  'ticket': 'التذكرة',
  'auto_approval_countdown': 'العد التنازلي للموافقة التلقائية',
  'time_expired': 'انتهى الوقت',
  'time_remaining': 'الوقت المتبقي',
  'total_time': 'الوقت الإجمالي',
  'your_decision': 'قرارك',
  'approve': 'موافقة',
  'approval_notes_label': 'ملاحظات الموافقة *',
  'work_meets_expectations': 'العمل يلبي التوقعات...',
  'changes_needed': 'التغييرات المطلوبة',
  'explain_changes': 'شرح التغييرات *',
  'what_needs_improvement': 'ما يحتاج إلى تحسين...',
  'approval': 'موافقة',
  'ticket_will_be_closed': 'سيتم إغلاق التذكرة',
  'no_further_work': 'لا مزيد من العمل',
  'returns_to_in_progress': 'تعود إلى قيد التنفيذ',
  'admin_sees_feedback': 'المسؤول يرى الملاحظات',
  'please_add_approval_notes': 'يرجى إضافة ملاحظات الموافقة',
  'ticket_approved_and_closed': 'تمت الموافقة على التذكرة وإغلاقها بنجاح',
  'ticket_returned_for_more_work': 'تم إرجاع التذكرة للمزيد من العمل',
  'error_submitting_approval': 'خطأ في إرسال الموافقة',
  'calculating': 'جاري الحساب...',
  'expired_auto_closing_now': 'منتهي - سيتم الإغلاق تلقائياً الآن',
  'days': 'أيام',
  'day': 'يوم',
  'hours': 'ساعات',
  'hour': 'ساعة',
  'minutes': 'دقائق',
  'minute': 'دقيقة',
  'seconds': 'ثوان',
  'time_expired_auto_approval_now':
      '🚨 انتهى الوقت: سيتم الموافقة على هذه التذكرة تلقائياً الآن!',
  'urgent_auto_approval_in': '⚠️ عاجل: موافقة تلقائية خلال',
  'warning_auto_approval_in': '⏰ تحذير: موافقة تلقائية خلال',

  // Assign Ticket Dialog
  'assign_ticket': 'تعيين التذكرة',
  'matching_admins_shown_first': 'يتم عرض المسؤولين المطابقين أولاً',
  'no_available_admins_found': 'لم يتم العثور على مسؤولين متاحين.',
  'match': 'مطابق',
  'please_select_admin': 'يرجى اختيار مسؤول',
  'ticket_assigned_successfully': 'تم تعيين التذكرة بنجاح',
  'error_assigning_ticket': 'خطأ في تعيين التذكرة',

  // Finish Ticket Dialog
  'mark_ticket_finished': 'وضع علامة منتهي على التذكرة',
  'auto_approval_after_monitoring': 'موافقة تلقائية بعد فترة المراقبة',
  'creator_will_review_work': 'سيراجع منشئ التذكرة عملك',
  'report_title': 'عنوان التقرير',
  'brief_summary': 'ملخص موجز',
  'add': 'إضافة',
  'mark_supervised': 'وضع علامة تحت المراقبة',
  'submit': 'إرسال',
  'ticket_marked_under_supervision':
      'تم وضع التذكرة تحت المراقبة. سيتم الموافقة عليها تلقائياً بعد فترة المراقبة.',
  'work_report_submitted_success':
      'تم إرسال تقرير العمل بنجاح. في انتظار موافقة المنشئ.',
  'failed_to_submit_report': 'فشل إرسال التقرير. يرجى المحاولة مرة أخرى.',

  // Image Gallery Viewer
  'image_details': 'تفاصيل الصورة',
  'name': 'الاسم',
  'size': 'الحجم',
  'type': 'النوع',
  'uploaded': 'تم الرفع',
  'close': 'إغلاق',
  'share_not_implemented': 'المشاركة غير متوفرة - أضف الوظيفة الخاصة بك',
  'failed_to_load_image': 'فشل تحميل الصورة',
  'unknown_file': 'ملف غير معروف',
  'loading_image': 'جاري تحميل الصورة...',
  'previous': 'السابق',
  'next': 'التالي',

  // Wrong Info Dialog
  'mark_as_wrong_information': 'وضع علامة معلومات خاطئة',
  'provide_feedback_incorrect':
      'يرجى تقديم ملاحظات حول المعلومات غير الصحيحة أو الناقصة:',
  'feedback': 'الملاحظات',
  'explain_what_needs_corrected': 'اشرح ما يحتاج إلى تصحيح...',
  'mark_as_wrong_info': 'وضع علامة معلومات خاطئة',
  'ticket_marked_wrong_information': 'تم وضع علامة معلومات خاطئة على التذكرة',
  'error_marking_wrong_info': 'خطأ في وضع علامة معلومات خاطئة',
  'please_provide_feedback': 'يرجى تقديم الملاحظات',

  // Create Subticket
  'parent_ticket': 'التذكرة الرئيسية',
  'subticket_title': 'عنوان التذكرة الفرعية',
  'brief_description_subtask': 'وصف موجز للمهمة الفرعية',
  'detailed_description_todo': 'وصف تفصيلي لما يجب القيام به',
  'target_department': 'القسم المستهدف',
  'select_department_subtask': 'اختر القسم للتعامل مع هذه المهمة الفرعية',
  'nature_of_work': 'طبيعة العمل',
  'select_nature_of_work': 'اختر طبيعة العمل',
  'no_nature_of_work_available':
      'لا توجد خيارات لطبيعة العمل متاحة لهذا القسم.',
  'high_priority_explanation': 'توضيح الأولوية العالية',
  'explain_why_urgent': 'اشرح لماذا هذا عاجل/أولوية عالية',
  'no_files_selected': 'لم يتم تحديد ملفات',
  'files_selected': 'ملفات محددة',
  'file': 'ملف',
  'subticket_information': 'معلومات التذكرة الفرعية',
  'subticket_will_be_linked': 'سيتم ربط التذكرة الفرعية بالتذكرة الرئيسية',
  'can_be_assigned_different_dept': 'يمكن تعيينها لقسم مختلف',
  'helps_break_down_tasks': 'يساعد في تقسيم المهام المعقدة',
  'parent_can_track_subtickets':
      'يمكن للتذكرة الرئيسية تتبع جميع التذاكر الفرعية',
  'uploading': 'جاري الرفع...',
  'creating': 'جاري الإنشاء...',
  'error_picking_files': 'خطأ في اختيار الملفات',
  'error_picking_images': 'خطأ في اختيار الصور',
  'please_fill_all_required': 'يرجى ملء جميع الحقول المطلوبة',
  'please_explain_high_priority': 'يرجى توضيح سبب الأولوية العالية/العاجلة',
  'please_enter_phone_number': 'يرجى إدخال رقم الهاتف',
  'subticket_created_successfully': 'تم إنشاء التذكرة الفرعية بنجاح',
  'with_attachment': 'مع مرفق',
  'with_attachments': 'مع مرفقات',
  'failed_to_create_subticket': 'فشل إنشاء التذكرة الفرعية',

  'it_solution_ticket_title': 'تذكرة حلول تقنية',
  'it_brief_description': 'وصف موجز لمشكلة تقنية المعلومات',
  'it_detailed_description': 'وصف تفصيلي لمشكلة تقنية المعلومات',
  'it_ticket_info': 'تذكرة حلول تقنية',
  'it_ticket_sent_to_dept': 'سيتم إرسال هذه التذكرة إلى قسم تقنية المعلومات',
  'provide_detailed_info': 'قدم معلومات تفصيلية لحل أسرع',
  'attach_screenshots': 'أرفق لقطات الشاشة إن أمكن',
  'you_will_be_notified': 'سيتم إشعارك بأي تحديثات',
  'create_ticket': 'إنشاء تذكرة',

  // Places Maintenance Ticket
  'places_maintenance_ticket_title': 'تذكرة صيانة أماكن',
  'places_brief_description': 'وصف موجز لمشكلة الصيانة',
  'places_detailed_description': 'وصف تفصيلي للمشكلة',
  'select_place': 'اختر المكان',
  'place_info': 'المكان',
  'place_locked_for_user': 'المكان: ',
  'specific_location': 'الموقع المحدد',
  'specific_location_hint': 'رقم الغرفة، الطابق، إلخ.',
  'problem_title': 'عنوان المشكلة',
  'select_problem_type': 'اختر نوع المشكلة',
  'enter_custom_problem': 'أدخل عنوان مشكلة مخصص',
  'custom_problem_title': 'عنوان مشكلة مخصص',
  'describe_problem': 'صف المشكلة',
  'model_number': 'رقم الموديل',
  'select_device_part': 'اختر الجهاز/الجزء',
  'enter_custom_model': 'أدخل رقم موديل مخصص',
  'custom_model_number': 'رقم موديل مخصص',
  'enter_model_number': 'أدخل رقم الموديل',
  'places_ticket_info': 'تذكرة صيانة أماكن',
  'fill_required_fields': 'املأ جميع الحقول المطلوبة (*)',
  'provide_accurate_location': 'قدم تفاصيل الموقع بدقة',
  'add_photos_if_possible': 'أضف صور المشكلة إن أمكن',
  'notified_when_work_begins': 'سيتم إشعارك عند بدء العمل',

  // Individuals Maintenance Ticket
  'individuals_maintenance_ticket_title': 'تذكرة صيانة مشاكل فردية',
  'individuals_brief_description': 'وصف موجز للمشكلة',
  'individuals_detailed_description': 'وصف تفصيلي للمشكلة',
  'place_individual_info': 'المكان: فرد (غير مرتبط بموقع محدد)',
  'specific_location_optional': 'الموقع المحدد (اختياري)',
  'where_individual_located': 'أين يقع هذا الفرد؟',
  'individuals_ticket_info': 'تذكرة صيانة مشاكل فردية',
  'for_issues_related_individuals':
      'للمشاكل المتعلقة بالأفراد (غير مرتبطة بالأماكن)',
  'add_photos_documents': 'أضف صور أو مستندات إذا كانت مفيدة',
  'track_ticket_status': 'تتبع حالة تذكرتك في النظام',

  // Requests Ticket
  'requests_ticket_title': 'تذكرة طلب',
  'request_title': 'عنوان الطلب',
  'what_are_you_requesting': 'ما الذي تطلبه؟',
  'request_description': 'وصف الطلب',
  'detailed_request_description': 'وصف تفصيلي لطلبك',
  'select_department_handle_request': 'اختر القسم للتعامل مع الطلب',
  'where_items_delivered': 'أين يجب تسليم العناصر/الخدمات؟',
  'requests_ticket_info': 'تذكرة طلب',
  'use_for_requesting_items': 'استخدم هذا لطلب العناصر أو الخدمات',
  'commonly_used_inter_dept': 'يُستخدم عادة للطلبات بين الأقسام',
  'can_be_used_subtickets': 'يمكن استخدامه أيضاً في التذاكر الفرعية',
  'track_request_status': 'تتبع حالة طلبك',
  'create_request': 'إنشاء طلب',

  // Common across all dialogs
  'title_required': 'العنوان *',
  'description_required': 'الوصف *',
  'target_department_required': 'القسم المستهدف *',
  'nature_of_work_required': 'طبيعة العمل *',
  'priority_required': 'الأولوية *',
  'high_priority_explanation_required': 'توضيح الأولوية العالية *',
  'explain_high_urgent_priority': 'اشرح لماذا هذا عاجل/أولوية عالية',
  'model_number_optional': 'رقم الموديل (اختياري)',
  'phone_number': 'رقم الهاتف',
  'attachments_section': 'المرفقات',
  'no_nature_work_for_dept': 'لا توجد خيارات لطبيعة العمل متاحة لهذا القسم.',
  'please_select_problem_or_custom': 'يرجى اختيار عنوان المشكلة أو إدخال مخصص',
  'please_enter_custom_problem': 'يرجى إدخال عنوان مشكلة مخصص',
  'it_ticket_created_successfully':
      'تم إنشاء تذكرة حلول تقنية #{ticketNumber} بنجاح',
  'places_ticket_created_successfully':
      'تم إنشاء تذكرة صيانة أماكن #{ticketNumber} بنجاح',
  'individuals_ticket_created_successfully':
      'تم إنشاء تذكرة صيانة مشاكل فردية #{ticketNumber} بنجاح',
  'requests_ticket_created_successfully':
      'تم إنشاء تذكرة طلب #{ticketNumber} بنجاح',
  'with_attachment_count': 'مع {count} مرفق',
  'with_attachments_count': 'مع {count} مرفقات',
  'failed_create_ticket': 'فشل إنشاء التذكرة',
  'creating_corrected_ticket_from': 'إنشاء تذكرة مصححة من',
  'please_review_and_update': 'يرجى مراجعة وتحديث المعلومات أدناه.',
  'phone_number_required': 'رقم الهاتف *',
  'contact_phone_number': 'رقم هاتف الاتصال',
  'please_select_nature_of_work': 'يرجى اختيار طبيعة العمل',
  'please_specify_other_nature_of_work': 'يرجى تحديد طبيعة عمل أخرى',
  'please_specify_other_place': 'يرجى تحديد مكان آخر',
  'specify_nature_of_work': 'حدد طبيعة العمل *',
  'describe_nature_of_work': 'صف طبيعة العمل',
  'no_nature_work_available_click_below':
      'لا توجد خيارات لطبيعة العمل متاحة. انقر أدناه للتحديد.',
  'specify_other': 'حدد آخر',
  'specify_place': 'حدد المكان *',
  'enter_place_name': 'أدخل اسم المكان',
  'specify_problem_title': 'حدد عنوان المشكلة',
  'specify_model_number': 'حدد رقم الموديل',
  'ticket_information': 'معلومات التذكرة',
  'make_sure_all_required_fields_filled':
      'تأكد من ملء جميع الحقول المطلوبة (*)',
  'provide_accurate_phone_number': 'قدم رقم هاتف دقيق للتواصل',
  'add_detailed_description': 'أضف وصفاً تفصيلياً لحل أسرع',
  'attach_relevant_images': 'أرفق صوراً أو مستندات ذات صلة إن وجدت',
  'use_other_option_if_not_in_list':
      'استخدم خيار "آخر" إذا لم يكن اختيارك في القائمة',
  'ticket_created_successfully_with': 'تم إنشاؤها بنجاح مع',
  'ticket_created_successfully': 'تم إنشاؤها بنجاح',
  'other_specify': 'آخر (مخصص)',
  'no_results_found': 'لا توجد نتائج',
  'select': 'اختار',
  'it_department_not_found': 'لم يتم إيجاد قسم تكنولوجيا المعلومات',
  'quality_complaints': 'شكاوى الجودة',
  'all_complaints': 'جميع الشكاوى',
  'complainant': 'المشتكي',
  'complainant_name': 'اسم المشتكي',
  'receiver': 'المستقبل',
  'complaint_receiver': 'مستقبل الشكوى',
  'item': 'الصنف',
  'batch_number': 'رقم الدفعة',
  'quantity': 'الكمية',
  'produce_date': 'تاريخ الإنتاج',
  'expired_date': 'تاريخ الانتهاء',
  'complaint_type': 'نوع الشكوى',
  'complaint_description': 'وصف الشكوى',
  'technical': 'تقني',
  'coordination_delivery': 'التنسيق والتسليم',
  'complaint_check': 'فحص الشكوى',
  'complaint_valid': 'شكوى صحيحة',
  'complaint_invalid': 'شكوى غير صحيحة',
  'check_report': 'تقرير الفحص',
  'therapeutic_procedure': 'الإجراء العلاجي',
  'checker': 'الفاحص',
  'check_date': 'تاريخ الفحص',
  'signed_document': 'المستند الموقع',
  'upload_signed': 'رفع موقع',
  'download_pdf': 'تحميل PDF',
  'check_complaint': 'فحص الشكوى',
  'assign_complaint': 'تعيين الشكوى',
  'no_complaints_found': 'لم يتم العثور على شكاوى',
  'complaint_number': 'رقم الشكوى',
  'select_admin': 'اختر مسؤول',
  'admins_available': 'مسؤولين متاحين',
  'no_admins_available': 'لا يوجد مسؤولين متاحين في قسمك',
  'complaint_assigned_successfully': 'تم تعيين الشكوى بنجاح',
  'error_assigning_complaint': 'خطأ في تعيين الشكوى',
  'please_select_an_admin': 'يرجى اختيار مسؤول',
  'select_admin_from_department': 'اختر مسؤولاً من قسمك لتعيين هذه الشكوى',
  'report_required': 'التقرير *',
  'enter_detailed_check_report': 'أدخل تقرير فحص مفصل...',
  'therapeutic_procedure_optional': 'الإجراء العلاجي (اختياري)',
  'enter_therapeutic_procedure': 'أدخل الإجراء العلاجي إن وجد...',
  'add_images_optional': 'إضافة صور (اختياري)',
  'after_submission': 'بعد الإرسال:',
  'status_will_change_prefinished': '• سيتم تغيير الحالة إلى شبه منتهية',
  'pdf_report_auto_download': '• سيتم تحميل تقرير PDF تلقائياً',
  'can_print_sign_upload': '• يمكنك الطباعة والتوقيع ورفع المستند الموقع',
  'submit_check': 'إرسال الفحص',
  'please_enter_report': 'يرجى إدخال التقرير',
  'check_submitted_successfully': 'تم إرسال الفحص بنجاح',
  'error_submitting_check': 'خطأ في إرسال الفحص',
  'yes': 'نعم',
  'no': 'لا',
  'check_images': 'صور الفحص',
  'initial_attachments': 'المرفقات الأولية',
  'images_count': 'الصور',
  'documents_count': 'المستندات',
  'no_initial_attachments': 'لم يتم رفع مرفقات أولية',
  'initial': 'أولي',
  'check': 'فحص',
  'signed': 'موقع',
  'zoom_in': 'تكبير',
  'zoom_out': 'تصغير',
  'reset_zoom': 'إعادة ضبط التكبير',
  'download': 'تحميل',
  'downloading_image': 'جاري تحميل الصورة...',
  'image_downloaded_successfully': 'تم تحميل الصورة بنجاح',
  'failed_to_download_image': 'فشل تحميل الصورة',
  'download_not_supported':
      'ميزة التحميل متاحة حالياً على الويب فقط.\nيمكنك عرض الصور والتقاط لقطة شاشة بدلاً من ذلك.',
  'generating_pdf': 'جاري إنشاء PDF...',
  'pdf_generated_successfully': 'تم إنشاء PDF بنجاح',
  'error_generating_pdf': 'خطأ في إنشاء PDF',
  'no_check_report_available': 'لا يوجد تقرير فحص متاح لهذه الشكوى',
  'loading_check_data': 'جاري تحميل بيانات الفحص...',
  'no_check_record_found': 'لم يتم العثور على سجل فحص لهذه الشكوى',
  'error_loading_check_data': 'خطأ في تحميل بيانات الفحص',
  'replace_signed_document': 'استبدال المستند الموقع؟',
  'signed_document_exists':
      'يوجد مستند موقع بالفعل لهذه الشكوى. هل تريد استبداله؟',
  'replace': 'استبدال',
  'could_not_read_file': 'تعذرت قراءة الملف',
  'file_size_exceeds_limit': 'حجم الملف يتجاوز حد 50 ميجابايت',
  'uploading_pdf': 'جاري رفع PDF...',
  'uploading_image': 'جاري رفع الصورة...',
  'signed_pdf_uploaded': 'تم رفع PDF الموقع بنجاح',
  'signed_image_uploaded': 'تم رفع الصورة الموقعة بنجاح',
  'failed_upload_signed': 'فشل رفع المستند الموقع',
  'error_uploading': 'خطأ',
  'select_file_pdf_or_image': 'اختر ملف PDF أو صورة (PDF، JPG، PNG)',
  'create_complaint': 'إنشاء شكوى',
  'create_quality_complaint': 'إنشاء شكوى جودة',
  'complaint_form': 'نموذج الشكوى',
  'receiver_name': 'اسم المستقبل',
  'complainant_information': 'معلومات المشتكي',
  'complainants_name': 'اسم المشتكي',
  'mobile_number': 'رقم الموبايل',
  'phone_number_optional': 'رقم الهاتف (اختياري)',
  'product_information': 'معلومات المنتج',
  'select_item': 'اختر الصنف',
  'please_select_item': 'يرجى اختيار صنف',
  'batch_number_optional': 'رقم الدفعة (اختياري)',
  'quantity_optional': 'الكمية (اختياري)',
  'select_produce_date': 'اختر تاريخ الإنتاج',
  'select_expired_date': 'اختر تاريخ الانتهاء',
  'complaint_details': 'تفاصيل الشكوى',
  'describe_issue_detail': 'صف المشكلة بالتفصيل...',
  'select_complaint_type': 'اختر نوع الشكوى',
  'add_images': 'إضافة صور',
  'submit_complaint': 'إرسال الشكوى',
  'complaint_created_successfully': 'تم إنشاء شكوى الجودة بنجاح',
  'error_creating_complaint': 'خطأ في إنشاء الشكوى',
  'please_enter_complainant_name': 'يرجى إدخال اسم المشتكي',
  'please_enter_location': 'يرجى إدخال الموقع',
  'please_enter_mobile': 'يرجى إدخال رقم الموبايل',
  'loading_items': 'جاري تحميل الأصناف...',
  'no_items_available': 'لا توجد أصناف متاحة',
  'product_details': 'تفاصيل المنتج',
  'no_item': 'لا يوجد صنف',
  'assign_to_admin': 'تعيين لمسؤول',
  'check_and_validate': 'فحص والتحقق',
  'view_report': 'عرض التقرير',
  'complaint_checked_by': 'تم الفحص بواسطة',
  'is_valid': 'صحيح',
  'check_details': 'تفاصيل الفحص',
  'no_check_data': 'لا توجد بيانات فحص متاحة',
  'therapeutic_procedure_details': 'تفاصيل الإجراء العلاجي',
  'not_applicable': 'غير متوفر',
  'documents': 'مستندات',

  'after_submission_info':
      '• سيتغير الحالة إلى شبه منتهية\n• سيتم تنزيل تقرير PDF تلقائياً\n• يمكنك طباعة وتوقيع وتحميل المستند الموقع',
  'loading_admins': 'جاري تحميل المسؤولين...',
  'error_loading_admins': 'خطأ في تحميل المسؤولين',
  'available': 'متوفر',
  'report': 'تقرير',
  'enter_therapeutic_procedure_if_applicable':
      'أدخل الإجراء العلاجي إذا كان ذلك مناسبًا',
  'chat_rooms': 'غرف المحادثة',
  'recent_conversations': 'المحادثات الأخيرة',
  'unread': 'غير مقروءة',
  'no_active_chat_rooms': 'لا توجد غرف محادثة نشطة',
  'chat_rooms_appear_when_tickets_in_progress':
      'تظهر غرف المحادثة عندما تكون التذاكر قيد التنفيذ',
  'select_conversation_to_start_chatting': 'اختر محادثة لبدء الدردشة',
  'choose_from_active_tickets_on_left': 'اختر من التذاكر النشطة على اليسار',
  'no_messages_yet': 'لا توجد رسائل بعد',
  'start_conversation': 'ابدأ محادثة!',
  'type_message': 'اكتب رسالة...',
  'sending_messages': 'جاري إرسال {count} رسالة...',
  'scroll_to_latest': 'انتقل إلى الأحدث',
  'reconnecting': 'جاري إعادة الاتصال...',
  'loading_chat_rooms': 'جاري تحميل غرف المحادثة...',
  'someone': 'شخص ما',
  'you': 'أنت',
  'user': 'مستخدم',
  'now': 'الآن',
  'departments': 'الأقسام',
  'create_department': 'إنشاء قسم',
  'name_is_required': 'الاسم مطلوب',
  'department_created_successfully': 'تم إنشاء القسم بنجاح',
  'failed_to_create_department': 'فشل إنشاء القسم',
  'department_activated': 'تم تفعيل القسم',
  'department_deactivated': 'تم إلغاء تفعيل القسم',
  'failed_to_update_department': 'فشل تحديث القسم',
  'total': 'إجمالي',
  'no_departments_yet': 'لا توجد أقسام بعد',
  'create_your_first_department': 'أنشئ قسمك الأول',

  'places': 'الأماكن',
  'create_place': 'إنشاء مكان',
  'place_created_successfully': 'تم إنشاء المكان بنجاح',
  'failed_to_create_place': 'فشل إنشاء المكان',
  'place_activated': 'تم تفعيل المكان',
  'place_deactivated': 'تم إلغاء تفعيل المكان',
  'failed_to_update_place': 'فشل تحديث المكان',
  'no_places_yet': 'لا توجد أماكن بعد',
  'create_your_first_place': 'أنشئ مكانك الأول',

  'users': 'المستخدمون',
  'add_user': 'إضافة مستخدم',
  'of': 'من',
  'no_users_yet': 'لا يوجد مستخدمون بعد',
  'create_your_first_user': 'أنشئ مستخدمك الأول',
  'user_activated': 'تم تفعيل المستخدم',
  'user_deactivated': 'تم إلغاء تفعيل المستخدم',
  'remove_user': 'إزالة المستخدم',
  'confirm_remove_user': 'هل أنت متأكد من إزالة',
  'user_removed': 'تم إزالة المستخدم',
  'restore_user': 'استعادة المستخدم',
  'user_restored': 'تم استعادة المستخدم',
  'failed_to_update_user_status': 'فشل تحديث حالة المستخدم',

  'activity_logs': 'سجلات النشاط',
  'entries': 'سجل',
  'search_action_table_user': 'البحث في الإجراء، الجدول، المستخدم…',
  'all_actions': 'جميع الإجراءات',
  'no_logs_found': 'لا توجد سجلات',
  'load_more': 'تحميل المزيد',
  'changed_from': 'من',
  'changed_to': 'إلى',
  'new_record': 'سجل جديد',
  'deleted_record': 'سجل محذوف',
  'details': 'التفاصيل',
  'system': 'النظام',
  'all': 'الكل',
  'ai_insights': 'تحليل الذكاء الاصطناعي',
  'analyze_with_ai': 'تحليل بالذكاء الاصطناعي',
  'ai_insights_hint': 'حدد الفلاتر واضغط تحليل للحصول على رؤى ذكية',
  'ai_summary': 'ملخص الذكاء الاصطناعي',
  'top_problem_places': 'أكثر الأماكن مشاكل',
  'recurring_issues': 'المشاكل المتكررة',
  'root_causes': 'الأسباب الجذرية',
  'replacement_recommendations': 'توصيات الاستبدال',
  'prevention_suggestions': 'اقتراحات الوقاية',
  'smart_title_suggestions': 'اقتراحات عناوين ذكية',
  'select_department': 'اختر القسم',
  'saved_successfully': 'تم الحفظ بنجاح',

  'problem_titles': 'عناوين المشاكل',
  'create_problem_title': 'إنشاء عنوان مشكلة',
  'problem_title_created_successfully': 'تم إنشاء عنوان المشكلة بنجاح',
  'failed_to_create_problem_title': 'فشل إنشاء عنوان المشكلة',
  'no_problem_titles_yet': 'لا توجد عناوين مشاكل بعد',
  'create_your_first_problem_title': 'أنشئ عنوان مشكلتك الأول',
  'search_problem_titles': 'بحث في عناوين المشاكل...',

  'parts': 'القطع',
  'create_part': 'إنشاء قطعة',
  'model_number_required': 'رقم الموديل مطلوب',
  'name_and_model_required': 'الاسم ورقم الموديل مطلوبان',
  'part_created_successfully': 'تم إنشاء القطعة بنجاح',
  'failed_to_create_part': 'فشل إنشاء القطعة',
  'no_parts_yet': 'لا توجد قطع بعد',
  'create_your_first_part': 'أنشئ قطعتك الأولى',
  'search_parts': 'بحث في القطع...',

  'nature_of_work_management': 'طبيعة العمل',
  'create_nature_of_work': 'إنشاء طبيعة عمل',
  'nature_of_work_created_successfully': 'تم إنشاء طبيعة العمل بنجاح',
  'failed_to_create_nature_of_work': 'فشل إنشاء طبيعة العمل',
  'deactivated_successfully': 'تم إلغاء التفعيل بنجاح',
  'activated_successfully': 'تم التفعيل بنجاح',
  'failed_to_update_status': 'فشل تحديث الحالة',
  'no_nature_of_work_yet': 'لا توجد طبيعة عمل بعد',
  'define_your_first_nature_of_work': 'حدد طبيعة عملك الأولى',
  'search_nature_of_work': 'بحث في طبيعة العمل...',

  'complaint_items': 'أصناف الشكاوى',
  'create_complaint_item': 'إنشاء صنف شكوى',
  'item_name_required': 'اسم الصنف مطلوب',
  'item_created_successfully': 'تم إنشاء الصنف بنجاح',
  'failed_to_create_item': 'فشل إنشاء الصنف',
  'item_activated': 'تم تفعيل الصنف',
  'item_deactivated': 'تم إلغاء تفعيل الصنف',
  'failed_to_update_item': 'فشل تحديث الصنف',
  'no_complaint_items_yet': 'لا توجد أصناف شكاوى بعد',
  'create_your_first_item': 'أنشئ صنفك الأول',
  'search_items': 'بحث في الأصناف...',
  'item_name': 'اسم الصنف',

  'complaint_permissions': 'صلاحيات الشكاوى',
  'manage_department_access': 'إدارة وصول الأقسام',
  'enable_complaint_access_description':
      'تفعيل الوصول للشكاوى للأقسام التي تحتاج لإدارة شكاوى الجودة',
  'search_departments': 'بحث في الأقسام...',
  'no_departments_found': 'لم يتم العثور على أقسام',
  'no_departments_match_search': 'لا توجد أقسام تطابق بحثك',
  'can_access_complaints': 'يمكن الوصول للشكاوى',
  'no_complaint_access': 'لا يوجد وصول للشكاوى',
  'complaint_access_enabled': 'تم تفعيل الوصول للشكاوى',
  'complaint_access_disabled': 'تم إلغاء الوصول للشكاوى',
  'failed_to_update_permission': 'فشل تحديث الصلاحية',

  'auto_approval_settings': 'إعدادات الموافقة التلقائية',
  'automatically_approve_prefinished_tickets':
      'الموافقة التلقائية على التذاكر شبه المنتهية',
  'about_auto_approval': 'حول الموافقة التلقائية',
  'auto_approval_info_1':
      'التذاكر في حالة "شبه منتهية" سيتم الموافقة عليها تلقائياً بعد الوقت المحدد',
  'auto_approval_info_2':
      'ملاحظات المنشئ ستكون فارغة للتذاكر المعتمدة تلقائياً',
  'auto_approval_info_3': 'يفحص النظام التذاكر المؤهلة بشكل دوري',
  'auto_approval_info_4': 'الحد الأدنى للوقت هو دقيقة واحدة (للاختبار)',
  'current_auto_approval_time': 'وقت الموافقة التلقائية الحالي',
  'edit_time': 'تعديل الوقت',
  'tickets_ready_for_auto_approval': 'تذكرة جاهزة للموافقة التلقائية',
  'approve_now': 'موافقة الآن',
  'how_it_works': 'كيف يعمل',
  'set_auto_approval_time': 'تعيين وقت الموافقة التلقائية',
  'minimum_1_minute': 'الحد الأدنى: دقيقة واحدة',
  'common_values': 'القيم الشائعة:',
  'update': 'تحديث',
  'please_enter_valid_number': 'يرجى إدخال رقم صحيح (الحد الأدنى 1)',
  'trigger_auto_approval': 'تفعيل الموافقة التلقائية',
  'this_will_immediately_auto_approve':
      'سيتم الموافقة التلقائية فوراً على {count} تذكرة تجاوزت الحد الزمني.\n\nهل أنت متأكد من المتابعة؟',
  'auto_approval_completed_successfully': 'تمت الموافقة التلقائية بنجاح',
  'error_triggering_auto_approval': 'خطأ في تفعيل الموافقة التلقائية',
  'current_status': 'الحالة الحالية',
  'push': 'إشعارات',
  'on': 'مفعل',
  'off': 'معطل',

  'auto_assignment_settings': 'إعدادات التعيين التلقائي',
  'automatically_assign_new_tickets': 'تعيين التذاكر الجديدة تلقائياً',
  'auto_assignment_how_it_works_1':
      'عند التفعيل، سيتم تعيين جميع التذاكر الجديدة الموجهة لقسمك تلقائياً للمسؤول المحدد',
  'auto_assignment_how_it_works_2':
      'ستكون التذاكر في حالة "قيد التنفيذ" مباشرة',
  'auto_assignment_how_it_works_3':
      'سيتلقى كل من منشئ التذكرة والمسؤول المعين إشعارات',
  'auto_assignment_how_it_works_4': 'يمكنك التغيير أو التعطيل في أي وقت',
  'auto_assignment_status': 'حالة التعيين التلقائي',
  'new_tickets_will_be_automatically_assigned':
      'سيتم تعيين التذاكر الجديدة تلقائياً',
  'new_tickets_will_require_manual_assignment':
      'ستتطلب التذاكر الجديدة تعييناً يدوياً',
  'assign_new_tickets_to': 'تعيين التذاكر الجديدة إلى',
  'choose_which_admin_will_receive':
      'اختر المسؤول الذي سيستقبل التذاكر المعينة تلقائياً',
  'no_normal_admins_found':
      'لم يتم العثور على مسؤولين عاديين في قسمك. يرجى إنشاء مستخدمي مسؤول أولاً.',
  'selected_admin': 'المسؤول المحدد',
  'saving_settings': 'جاري حفظ الإعدادات...',
  'auto_assignment_is_active':
      'التعيين التلقائي نشط. سيتم تعيين التذاكر الجديدة إلى',
  'access_restricted': 'وصول محدود',
  'only_super_admins_can_manage':
      'فقط المسؤولون الرئيسيون يمكنهم إدارة إعدادات التعيين التلقائي',
  'please_select_admin_before_enabling':
      'يرجى اختيار مسؤول قبل تفعيل التعيين التلقائي',
  'auto_assignment_enabled_successfully': 'تم تفعيل التعيين التلقائي بنجاح',
  'auto_assignment_disabled_successfully': 'تم تعطيل التعيين التلقائي بنجاح',
  'failed_to_save_settings': 'فشل حفظ الإعدادات',

  'notification_preferences': 'تفضيلات الإشعارات',
  'manage_how_you_receive_notifications': 'إدارة كيفية استقبال الإشعارات',
  'about_notifications': 'حول الإشعارات',
  'notifications_info_1': 'التحكم في أنواع الإشعارات التي تستقبلها',
  'notifications_info_2': 'الاختيار بين الإشعارات الفورية والبريد الإلكتروني',
  'notifications_info_3': 'الإعدادات تطبق على جميع الأجهزة',
  'notifications_info_4': 'التغييرات تصبح سارية فوراً',
  'push_notifications': 'الإشعارات الفورية',
  'enable_push_notifications': 'تفعيل الإشعارات الفورية',
  'receive_push_notifications_on_device': 'استقبال الإشعارات الفورية على جهازك',
  'chat_message_notifications': 'إشعارات رسائل المحادثة',
  'get_notified_new_chat_messages':
      'احصل على إشعار عند استقبال رسائل محادثة جديدة',
  'email_notifications': 'إشعارات البريد الإلكتروني',
  'enable_email_notifications': 'تفعيل إشعارات البريد الإلكتروني',
  'receive_notifications_via_email': 'استقبال الإشعارات عبر البريد الإلكتروني',
  'could_not_load_preferences': 'تعذر تحميل التفضيلات',
  'preferences_updated_successfully': 'تم تحديث التفضيلات بنجاح',
  'failed_to_update_preferences': 'فشل تحديث التفضيلات',
  'failed_to_load_preferences': 'فشل تحميل التفضيلات',
  'no_permission_to_create_users': 'ليس لديك إذن لإنشاء مستخدمين.',
  'create_new_user': 'إنشاء مستخدم جديد',
  'create_user': 'إنشاء مستخدم',
  'please_select_department_for_admin_users':
      'يرجى اختيار قسم للمستخدمين المسؤولين',
  'please_select_place_for_super_users':
      'يرجى اختيار مكان للمستخدمين الممتازين',
  'user_created_successfully':
      'تم إنشاء المستخدم بنجاح وإرسال بيانات الاعتماد عبر البريد الإلكتروني',
  'failed_to_create_user': 'فشل إنشاء المستخدم',
  'add_nature_of_work_and_press_enter': 'أضف طبيعة العمل واضغط Enter',
  'edit_user': 'تعديل المستخدم',
  'nature_of_work_expertise': 'خبرة طبيعة العمل',
  'select_types_of_work_admin_specializes_in':
      'اختر أنواع العمل التي يتخصص فيها المسؤول',
  'update_user': 'تحديث المستخدم',
  'please_fill_full_name_field': 'يرجى ملء حقل الاسم الكامل',
  'user_updated_successfully': 'تم تحديث المستخدم بنجاح',
  'failed_to_update_user': 'فشل تحديث المستخدم',
  'example_network_issues_hardware_repair': 'مثل، مشاكل الشبكة، إصلاح الأجهزة',
  'no_nature_of_work_found': 'لم يتم العثور على طبيعة عمل',
  'try_adjusting_search': 'حاول تعديل بحثك',
  'example_product_x_service_y': 'مثل، المنتج X، الخدمة Y',
  'add_item': 'إضافة صنف',
  'no_items_found': 'لم يتم العثور على أصناف',
  'loading_settings': 'جاري تحميل الإعدادات...',
  'permissions': 'الصلاحيات',
  'auto_approval': 'الموافقة التلقائية',
  'logs': 'السجلات',
  'preferences': 'التفضيلات',
  'auto_assign': 'التعيين التلقائي',
  'reports': 'التقارير',
  'invalid_tab': 'علامة تبويب غير صالحة',
  'no_management_options_available': 'لا توجد خيارات إدارة متاحة',
  'saving_preferences': 'جاري حفظ التفضيلات...',
  // Problem Titles
  'problem_title_updated_successfully': 'تم تحديث عنوان المشكلة بنجاح',
  'failed_to_update_problem_title': 'فشل تحديث عنوان المشكلة',
  'delete_problem_title': 'حذف عنوان المشكلة',
  'are_you_sure_delete_problem_title': 'هل أنت متأكد من حذف عنوان المشكلة؟',
  'problem_title_deleted_successfully': 'تم حذف عنوان المشكلة بنجاح',
  'failed_to_delete_problem_title': 'فشل حذف عنوان المشكلة',

// Parts
  'part_updated_successfully': 'تم تحديث القطعة بنجاح',
  'failed_to_update_part': 'فشل تحديث القطعة',
  'delete_part': 'حذف القطعة',
  'are_you_sure_delete_part': 'هل أنت متأكد من حذف هذه القطعة؟',
  'part_deleted_successfully': 'تم حذف القطعة بنجاح',
  'failed_to_delete_part': 'فشل حذف القطعة',

// Nature of Work
  'nature_of_work_updated_successfully': 'تم تحديث طبيعة العمل بنجاح',
  'failed_to_update_nature_of_work': 'فشل تحديث طبيعة العمل',
  'delete_nature_of_work': 'حذف طبيعة العمل',
  'are_you_sure_delete_nature_of_work': 'هل أنت متأكد من حذف طبيعة العمل؟',
  'nature_of_work_deleted_successfully': 'تم حذف طبيعة العمل بنجاح',
  'failed_to_delete_nature_of_work': 'فشل حذف طبيعة العمل',

// Complaint Items
  'item_updated_successfully': 'تم تحديث الصنف بنجاح',
  'delete_complaint_item': 'حذف صنف الشكوى',
  'are_you_sure_delete_item': 'هل أنت متأكد من حذف هذا الصنف؟',
  'item_deleted_successfully': 'تم حذف الصنف بنجاح',
  'failed_to_delete_item': 'فشل في حذف الصنف',

  // Add to _arValues:
  'department_updated_successfully': 'تم تحديث القسم بنجاح',
  'delete_department': 'حذف القسم',
  'are_you_sure_delete_department': 'هل أنت متأكد من حذف',
  'department_deleted_successfully': 'تم حذف القسم بنجاح',
  'failed_to_delete_department': 'فشل حذف القسم',

  'place_updated_successfully': 'تم تحديث المكان بنجاح',
  'delete_place': 'حذف المكان',
  'are_you_sure_delete_place': 'هل أنت متأكد من حذف',
  'place_deleted_successfully': 'تم حذف المكان بنجاح',
  'failed_to_delete_place': 'فشل حذف المكان',
  // In _arValues (Arabic translations):
  'realtime_updates_paused': 'توقفت التحديثات في الوقت الفعلي',
  'reconnect': 'إعادة الاتصال',
  'you_started_working_on_ticket': 'لقد بدأت العمل على هذه التذكرة',
  'take_over': 'الاستيلاء',
  'take_over_ticket': 'الاستيلاء على التذكرة',
  'ticket_currently_assigned_to': 'هذه التذكرة مخصصة حالياً إلى',
  'are_you_sure_take_over_ticket':
      'هل أنت متأكد من رغبتك في الاستيلاء على هذه التذكرة؟',
  'ticket_taken_over_successfully': 'تم الاستيلاء على التذكرة بنجاح',
  'error_starting_work': 'خطأ في بدء العمل',
  'error_taking_over': 'خطأ في الاستيلاء',
  "branch_admins": "مدراء الفروع",
  "branch_admin_management": "إدارة مدراء الفروع",
  "branch_admin_management_description":
      "إدارة مدراء الفروع والمواقع المعينة لهم",
  "no_branch_admins_yet": "لا يوجد مدراء فروع بعد",
  "create_branch_admins_in_user_management":
      "قم بإنشاء مستخدمي مدراء الفروع في إدارة المستخدمين أولاً",
  "search_branch_admins": "البحث عن مدراء الفروع...",
  "edit_places_for": "تعديل الأماكن لـ",
  "no_places_assigned": "لم يتم تعيين أماكن",
  "places_updated_successfully": "تم تحديث الأماكن بنجاح",
  "failed_to_update_places": "فشل تحديث الأماكن",
  "edit_places": "تعديل الأماكن",
  "showing_my_tickets": "عرض تذاكري فقط",
  "showing_all_place_tickets": "عرض جميع تذاكر المكان",
  "my_tickets": "تذاكري",
  "security": "الأمان",
  "change_password": "تغيير كلمة المرور",
  "current_password": "كلمة المرور الحالية",
  "new_password": "كلمة المرور الجديدة",
  "confirm_new_password": "تأكيد كلمة المرور الجديدة",
  "password_updated_successfully": "تم تحديث كلمة المرور بنجاح",
  "incorrect_current_password": "كلمة المرور الحالية غير صحيحة",
  "password_too_short": "كلمة المرور يجب أن تكون 6 أحرف على الأقل",
  "reset_password": "إعادة تعيين كلمة المرور",
  "reset_password_with_otp": "إعادة التعيين عبر رمز OTP",
  "send_otp": "إرسال الرمز",
  "enter_otp": "أدخل الرمز",
  "otp_sent_to_email": "تم إرسال رمز مكوّن من 6 أرقام إلى بريدك الإلكتروني",
  "verify_and_set_password": "تحقق وعيّن كلمة المرور",
  "invalid_otp": "رمز OTP غير صحيح",
  "otp_expired_or_invalid": "انتهت صلاحية الرمز أو أنه غير صحيح. يرجى المحاولة مجدداً.",
  "enter_your_email": "أدخل بريدك الإلكتروني",
  "step1_send_otp": "الخطوة 1: إرسال الرمز",
  "step2_enter_otp": "الخطوة 2: أدخل الرمز وكلمة المرور الجديدة",
  "forgot_password": "نسيت كلمة المرور؟",
};

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
