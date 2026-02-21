// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get jobDataExtractor => 'Shift Data Extractor';

  @override
  String get uploadPdfToExtract =>
      'Upload a PDF or image to extract catering shift details';

  @override
  String get enterJobDetailsManually =>
      'Enter shift details manually for precise control';

  @override
  String get createJobsThroughAI =>
      'Create jobs through natural conversation with AI';

  @override
  String get jobDetails => 'Shift Details';

  @override
  String get jobInformation => 'Shift Information';

  @override
  String get jobTitle => 'Shift Title';

  @override
  String get clientName => 'Client Name';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get headcount => 'Headcount';

  @override
  String get locationInformation => 'Location Information';

  @override
  String get locationName => 'Location Name';

  @override
  String get address => 'Address';

  @override
  String get city => 'City';

  @override
  String get state => 'State';

  @override
  String get contactName => 'Contact Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get email => 'Email';

  @override
  String get notes => 'Notes';

  @override
  String get shift => 'Shift';

  @override
  String get client => 'Client';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get location => 'Location';

  @override
  String get phone => 'Phone';

  @override
  String jobsTabLabel(int pendingCount, int upcomingCount, int pastCount) {
    return 'Jobs • $pendingCount pending, $upcomingCount upcoming, $pastCount past';
  }

  @override
  String pendingUpcomingStatus(
    int pendingCount,
    int upcomingCount,
    String baseTime,
  ) {
    return '$pendingCount pending • $upcomingCount upcoming • $baseTime';
  }

  @override
  String upcomingPastStatus(int upcomingCount, int pastCount, String baseTime) {
    return '$upcomingCount upcoming • $pastCount past • $baseTime';
  }

  @override
  String get pleaseSelectDate => 'Please select a date for the shift';

  @override
  String get jobSavedToPending =>
      'Shift saved to pending. Go to Jobs tab to review.';

  @override
  String get jobDetailsCopied => 'Shift details copied to clipboard';

  @override
  String get jobPosted => 'Shift posted';

  @override
  String get sendJobInvitation => 'Send Shift Invitation';

  @override
  String inviteToJob(String name) {
    return 'Invite $name to a shift';
  }

  @override
  String get jobInvitationSent => 'Shift invitation sent!';

  @override
  String get jobNotFound => 'Shift not found';

  @override
  String guests(int count) {
    return '$count guests';
  }

  @override
  String get rolesNeeded => 'Roles Needed';

  @override
  String get untitledJob => 'Untitled Shift';

  @override
  String get expectedHeadcount => 'Expected Headcount';

  @override
  String get contactPhone => 'Contact Phone';

  @override
  String get contactEmail => 'Contact Email';

  @override
  String get errorJobIdMissing => 'Error: Shift ID is missing...';

  @override
  String get postJob => 'Post Shift';

  @override
  String get setRolesForJob => 'Set roles for this shift';

  @override
  String get searchJobs => 'Search jobs...';

  @override
  String get locationTbd => 'Location TBD';

  @override
  String shareJobPrefix(String clientName) {
    return 'Shift: $clientName';
  }

  @override
  String get navCreate => 'Create';

  @override
  String get navJobs => 'Jobs';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navChat => 'Chat';

  @override
  String get navHours => 'Hours';

  @override
  String get navCatalog => 'Catalog';

  @override
  String get uploadData => 'Upload Data';

  @override
  String get manualEntry => 'Manual Entry';

  @override
  String get multiUpload => 'Multi-Upload';

  @override
  String get aiChat => 'AI Chat';

  @override
  String get chooseFile => 'Choose File';

  @override
  String get detailedExplanation => 'Detailed Explanation';

  @override
  String get messagesAndTeamMembers => 'Messages and team members';

  @override
  String get searchNameOrEmail => 'Search name or email';

  @override
  String get all => 'All';

  @override
  String get bartender => 'Bartender';

  @override
  String get server => 'Server';

  @override
  String messages(int count) {
    return 'Messages ($count)';
  }

  @override
  String youveBeenInvitedTo(String jobName) {
    return 'You\'ve been invited to $jobName';
  }

  @override
  String get hoursApproval => 'Hours Approval';

  @override
  String get needsSheet => 'Needs Sheet';

  @override
  String needsSheetCount(int count) {
    return '$count Needs Sheet';
  }

  @override
  String staffCount(int count) {
    return '$count staff';
  }

  @override
  String catalogClientsRoles(int clientCount, int roleCount) {
    return 'Catalog • $clientCount clients, $roleCount roles';
  }

  @override
  String get clients => 'Clients';

  @override
  String get roles => 'Roles';

  @override
  String get tariffs => 'Tariffs';

  @override
  String get addClient => 'Add Client';

  @override
  String get teams => 'Teams';

  @override
  String members(int count) {
    return '$count members';
  }

  @override
  String pendingInvites(int count) {
    return '$count pending invites';
  }

  @override
  String get viewDetails => 'View details';

  @override
  String get newTeam => 'New team';

  @override
  String get myProfile => 'My Profile';

  @override
  String get settings => 'Settings';

  @override
  String get manageTeams => 'Manage Teams';

  @override
  String get logout => 'Logout';

  @override
  String get selectFiles => 'Select Files';

  @override
  String get multiSelectTip =>
      'Tip: Long-press to multi-select in the picker. Or use Add More to append.';

  @override
  String get contactInformation => 'Contact Information';

  @override
  String get additionalNotes => 'Additional Notes';

  @override
  String get saveJobDetails => 'Save Shift Details';

  @override
  String get saveToPending => 'Save to Pending';

  @override
  String get pending => 'Pending';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get startConversation => 'Start a Conversation';

  @override
  String get aiWillGuideYou => 'The AI will guide you through creating a shift';

  @override
  String get startNewConversation => 'Start New Conversation';

  @override
  String get fecha => 'Date';

  @override
  String get hora => 'Time';

  @override
  String get ubicacion => 'Location';

  @override
  String get direccion => 'Address';

  @override
  String jobFor(String clientName) {
    return 'Shift for: $clientName';
  }

  @override
  String get accepted => 'Accepted';

  @override
  String get invitation => 'Invitation';

  @override
  String get viewJobs => 'View Jobs';

  @override
  String get addToBartender => 'Add to Bartender';

  @override
  String get addToServer => 'Add to Server';

  @override
  String addToRole(String role) {
    return 'Add to $role';
  }

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get remove => 'Remove';

  @override
  String get add => 'Add';

  @override
  String get share => 'Share';

  @override
  String get refresh => 'Refresh';

  @override
  String get create => 'Create';

  @override
  String get unknown => 'Unknown';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get clearAll => 'Clear All';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get or => 'or';

  @override
  String get cancel => 'Cancel';

  @override
  String get approve => 'Approve';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get apply => 'Apply';

  @override
  String get skip => 'Skip';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This Week';

  @override
  String get account => 'Account';

  @override
  String get role => 'Role';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get signOut => 'Sign out';

  @override
  String get password => 'Password';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithPhone => 'Continue with Phone';

  @override
  String get appRoleManager => 'Manager';

  @override
  String get termsAndPrivacyDisclaimer =>
      'By continuing, you agree to our\nTerms of Service and Privacy Policy';

  @override
  String get pleaseEnterEmailAndPassword => 'Please enter email and password';

  @override
  String get googleSignInFailed => 'Google sign-in failed';

  @override
  String get appleSignInFailed => 'Apple sign-in failed';

  @override
  String get emailSignInFailed => 'Email sign-in failed';

  @override
  String get phoneSignIn => 'Phone Sign In';

  @override
  String get enterVerificationCode => 'Enter the verification code';

  @override
  String get weWillSendVerificationCode =>
      'We\'ll send you a verification code';

  @override
  String get sendVerificationCode => 'Send Verification Code';

  @override
  String get verifyCode => 'Verify Code';

  @override
  String get change => 'Change';

  @override
  String get pleaseEnterPhoneNumber => 'Please enter your phone number';

  @override
  String get pleaseEnterValidPhoneNumber => 'Please enter a valid phone number';

  @override
  String get pleaseEnterVerificationCode =>
      'Please enter the verification code';

  @override
  String get verificationCodeMustBe6Digits =>
      'Verification code must be 6 digits';

  @override
  String get didntReceiveCodeResend => 'Didn\'t receive the code? Resend';

  @override
  String get welcomeToFlowShift => 'Welcome to FlowShift!';

  @override
  String get personalizeExperienceWithVenues =>
      'Let\'s personalize your experience by finding popular event venues in your area.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get whereAreYouLocated => 'Where are you\nlocated?';

  @override
  String get addCitiesWhereYouOperate =>
      'Add one or more cities where you operate. You can discover venues for each city later.';

  @override
  String get settingUpYourCity => 'Setting up your city...';

  @override
  String settingUpYourCities(int cityCount) {
    return 'Setting up your $cityCount cities...';
  }

  @override
  String get thisWillOnlyTakeAMoment => 'This will only take a moment...';

  @override
  String get allSet => 'All Set!';

  @override
  String get yourCityConfiguredSuccessfully =>
      'Your city has been configured successfully!';

  @override
  String yourCitiesConfiguredSuccessfully(int count) {
    return 'Your $count cities have been configured successfully!';
  }

  @override
  String get discoverVenuesFromSettings =>
      'You can discover venues for each city from Settings > Manage Cities.';

  @override
  String get startUsingFlowShift => 'Start Using FlowShift';

  @override
  String get couldNotDetectLocationEnterManually =>
      'Could not detect your location. Please enter your city manually.';

  @override
  String get locationDetectionFailed =>
      'Location detection failed. Please enter your city manually.';

  @override
  String get pleaseAddAtLeastOneCity => 'Please add at least one city';

  @override
  String get anErrorOccurredTryAgain => 'An error occurred. Please try again.';

  @override
  String get letsGetYouSetUp => 'Let\'s get you set up';

  @override
  String stepsComplete(int completedCount, int totalSteps) {
    return '$completedCount of $totalSteps steps complete';
  }

  @override
  String get finishStepsToActivateWorkspace =>
      'Finish these steps to activate your FlowShift workspace:';

  @override
  String get statusChipProfile => 'Profile';

  @override
  String get statusChipTeam => 'Team';

  @override
  String get statusChipClient => 'Client';

  @override
  String get statusChipRole => 'Role';

  @override
  String get statusChipTariff => 'Tariff';

  @override
  String nextUp(String step) {
    return 'Next up: $step';
  }

  @override
  String get completeAllStepsForDashboard =>
      'Complete all steps above to access the full dashboard.';

  @override
  String get addFirstLastNameForStaff =>
      'Add your first and last name so staff know who you are.';

  @override
  String get reviewProfile => 'Review profile';

  @override
  String get updateProfile => 'Update profile';

  @override
  String get updateYourProfile => '1. Update your profile';

  @override
  String get profileDetailsUpdated => 'Profile details updated.';

  @override
  String get createYourTeamCompany => '2. Create your team/company';

  @override
  String get setupStaffingCompanyExample =>
      'Set up your staffing company (e.g., \"MES - Minneapolis Event Staffing\")';

  @override
  String get teamCompanyName => 'Team/Company name';

  @override
  String get exampleTeamName => 'e.g. MES - Minneapolis Event Staffing';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get briefDescriptionStaffingCompany =>
      'Brief description of your staffing company';

  @override
  String get completeProfileFirst => 'Complete your profile first';

  @override
  String get createTeam => 'Create team';

  @override
  String get addAnotherTeam => 'Add another team';

  @override
  String get createYourFirstClient => '3. Create your first client';

  @override
  String get needAtLeastOneClient =>
      'You need at least one client before you can staff events.';

  @override
  String get exampleClientName => 'e.g. Bluebird Catering';

  @override
  String get completeProfileAndTeamFirst => 'Complete profile and team first';

  @override
  String get createClient => 'Create client';

  @override
  String get addAnotherClient => 'Add another client';

  @override
  String get addAtLeastOneRole => '4. Add at least one role';

  @override
  String get rolesHelpMatchStaff =>
      'Roles help match staff to the right job (waiter, chef, bartender...).';

  @override
  String get roleName => 'Role name';

  @override
  String get exampleRoleName => 'e.g. Lead Server';

  @override
  String get finishPreviousStepsFirst => 'Finish previous steps first';

  @override
  String get createRole => 'Create role';

  @override
  String get addAnotherRole => 'Add another role';

  @override
  String get setYourFirstTariff => '5. Set your first tariff';

  @override
  String get setRateForBilling =>
      'Set a rate so staffing assignments know what to bill.';

  @override
  String get createClientFirst => 'Create a client first';

  @override
  String get createRoleFirst => 'Create a role first';

  @override
  String get hourlyRateUsd => 'Hourly rate (USD)';

  @override
  String get exampleHourlyRate => 'e.g. 24.00';

  @override
  String get adjustTariffsInCatalog =>
      'You can adjust this later in Catalog > Tariffs';

  @override
  String get saveTariff => 'Save tariff';

  @override
  String get addAnotherTariff => 'Add another tariff';

  @override
  String get enterTeamNameToContinue => 'Enter a team/company name to continue';

  @override
  String get teamCreatedSuccessfully => 'Team created successfully!';

  @override
  String get failedToCreateTeam => 'Failed to create team';

  @override
  String get enterClientNameToContinue => 'Enter a client name to continue';

  @override
  String get clientCreated => 'Client created';

  @override
  String get failedToCreateClient => 'Failed to create client';

  @override
  String get enterRoleNameToContinue => 'Enter a role name to continue';

  @override
  String get roleCreated => 'Role created';

  @override
  String get failedToCreateRole => 'Failed to create role';

  @override
  String get createClientAndRoleBeforeTariff =>
      'Create a client and a role before adding a tariff';

  @override
  String get selectClientAndRole => 'Select a client and a role';

  @override
  String get enterValidHourlyRate => 'Enter a valid hourly rate (e.g. 22.50)';

  @override
  String get tariffSaved => 'Tariff saved';

  @override
  String get failedToSaveTariff => 'Failed to save tariff';

  @override
  String get failedToOpenProfile => 'Failed to open profile';

  @override
  String get navAttendance => 'Attendance';

  @override
  String get navStats => 'Stats';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get manageYourEvents => 'Manage your events';

  @override
  String get featureChatDesc => 'send jobs through the chat';

  @override
  String get featureAIChatDesc => 'create, update, ask questions';

  @override
  String get featureJobsDesc => 'Manage your created cards';

  @override
  String get featureTeamsDesc => 'invite people to Join';

  @override
  String get featureHoursDesc => 'Track team work hours';

  @override
  String get featureCatalogDesc => 'create clients, roles, and tariffs';

  @override
  String get quickActionUpload => 'Upload';

  @override
  String get quickActionTimesheet => 'Timesheet';

  @override
  String get teamMembers => 'Team Members';

  @override
  String get hours => 'Hours';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get confirmLogoutMessage => 'Are you sure you want to logout?';

  @override
  String get attendanceTitle => 'Attendance';

  @override
  String get forceClockOut => 'Force Clock-Out';

  @override
  String confirmClockOutMessage(String staffName) {
    return 'Are you sure you want to clock out $staffName?';
  }

  @override
  String get clockOut => 'Clock Out';

  @override
  String staffClockedOutSuccessfully(String staffName) {
    return '$staffName clocked out successfully';
  }

  @override
  String get failedToClockOutStaff => 'Failed to clock out staff';

  @override
  String viewingHistoryFor(String staffName) {
    return 'Viewing history for $staffName';
  }

  @override
  String viewingDetailsFor(String staffName) {
    return 'Viewing details for $staffName';
  }

  @override
  String get noAttendanceRecords => 'No attendance records';

  @override
  String get tryAdjustingFilters => 'Try adjusting your filters';

  @override
  String get recordsAppearWhenStaffClockIn =>
      'Records will appear here when staff clock in';

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get aiAnalysis => 'AI Analysis';

  @override
  String get failedToLoadData => 'Failed to load data';

  @override
  String get bulkClockIn => 'Bulk Clock-In';

  @override
  String get pleaseSelectAtLeastOneStaff =>
      'Please select at least one staff member';

  @override
  String successfullyClockedIn(int successful, int total) {
    return 'Successfully clocked in $successful of $total staff';
  }

  @override
  String get failedBulkClockIn => 'Failed to perform bulk clock-in';

  @override
  String get noAcceptedStaffForEvent => 'No accepted staff for this event';

  @override
  String get overrideNoteOptional => 'Override Note (optional)';

  @override
  String get groupCheckInHint => 'e.g., Group check-in at entrance';

  @override
  String clockInStaffCount(int count) {
    return 'Clock In $count Staff';
  }

  @override
  String get bulkClockInResults => 'Bulk Clock-In Results';

  @override
  String get alreadyClockedIn => 'Already clocked in';

  @override
  String get flaggedAttendance => 'Flagged Attendance';

  @override
  String get approved => 'Approved';

  @override
  String get dismissed => 'Dismissed';

  @override
  String get noPendingFlags => 'No pending flags!';

  @override
  String get noFlaggedEntriesFound => 'No flagged entries found';

  @override
  String get allEntriesLookNormal => 'All attendance entries look normal';

  @override
  String get reviewFlag => 'Review Flag';

  @override
  String get reviewNotesOptional => 'Review Notes (optional)';

  @override
  String get addNotesAboutReview => 'Add any notes about this review...';

  @override
  String get unknownStaff => 'Unknown Staff';

  @override
  String get unknownEvent => 'Unknown Event';

  @override
  String get clockInTime => 'Clock-In';

  @override
  String get clockOutTime => 'Clock-Out';

  @override
  String get durationLabel => 'Duration';

  @override
  String get expectedDuration => 'Expected';

  @override
  String get unusualHours => 'Unusual Hours';

  @override
  String get excessiveDuration => 'Excessive Duration';

  @override
  String get lateClockOut => 'Late Clock-Out';

  @override
  String get locationMismatch => 'Location Mismatch';

  @override
  String get filterAttendance => 'Filter Attendance';

  @override
  String get dateRange => 'Date Range';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get custom => 'Custom';

  @override
  String get event => 'Event';

  @override
  String get allEvents => 'All Events';

  @override
  String get status => 'Status';

  @override
  String get applyFilters => 'Apply Filters';

  @override
  String get working => 'Working';

  @override
  String get flags => 'Flags';

  @override
  String get currentlyWorking => 'Currently Working';

  @override
  String get noStaffWorking => 'No staff working';

  @override
  String get staffAppearsWhenClockIn =>
      'Staff will appear here when they clock in';

  @override
  String get history => 'History';

  @override
  String get onSite => 'On-site';

  @override
  String get autoClockOut => 'Auto clocked-out';

  @override
  String get completed => 'Completed';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewTwoWeeks => '2 Wks';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get scheduleIsClear => 'Your schedule is clear going forward';

  @override
  String get hidePastEvents => 'Hide past events';

  @override
  String showPastDaysWithEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $countString past days with events',
      one: 'Show 1 past day with events',
    );
    return '$_temp0';
  }

  @override
  String get noEventsThisDay => 'No events this day';

  @override
  String get freeDayLabel => 'Free day';

  @override
  String get nothingWasScheduled => 'Nothing was scheduled';

  @override
  String get nothingScheduledYet => 'Nothing scheduled yet';

  @override
  String get couldNotLoadEvents => 'Could not load events';

  @override
  String noFullTerminology(String terminology) {
    return 'No full $terminology yet';
  }

  @override
  String get whenPositionsFilled =>
      'When all positions are filled, they\'ll appear here';

  @override
  String expiredUnfulfilledEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expired unfulfilled events',
      one: '1 expired unfulfilled event',
    );
    return '$_temp0';
  }

  @override
  String get pastEventsNeverFullyStaffed =>
      'Past events that were never fully staffed';

  @override
  String expiredUnfulfilledTitle(int count) {
    return 'Expired Unfulfilled ($count)';
  }

  @override
  String noCompletedTerminology(String terminology) {
    return 'No completed $terminology yet';
  }

  @override
  String completedTerminologyAppear(String terminology) {
    return 'Completed $terminology will show up here';
  }

  @override
  String noPendingTerminology(String terminology) {
    return 'No pending $terminology';
  }

  @override
  String draftTerminologyWaiting(String terminology) {
    return 'Draft $terminology waiting to be posted will appear here';
  }

  @override
  String noPostedTerminology(String terminology) {
    return 'No posted $terminology';
  }

  @override
  String postedTerminologyWaiting(String terminology) {
    return 'Posted $terminology waiting for staff will appear here';
  }

  @override
  String get flagged => 'Flagged';

  @override
  String get noShow => 'No-show';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get clockIn => 'Clock In';

  @override
  String get verifiedOnSite => 'Verified on-site';

  @override
  String get weeklyHours => 'Weekly Hours';

  @override
  String get noDataForPeriod => 'No data for this period';

  @override
  String get failedToLoadFlaggedAttendance =>
      'Failed to load flagged attendance';

  @override
  String get failedToUpdateFlag => 'Failed to update flag';

  @override
  String get stats => 'Stats';

  @override
  String get failedToLoadStatistics => 'Failed to load statistics';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get allTime => 'All Time';

  @override
  String get downloadReport => 'Download report';

  @override
  String get downloadPdf => 'Download PDF';

  @override
  String get downloadWord => 'Download Word';

  @override
  String get analyzingYourData => 'Analyzing your data...';

  @override
  String get failedToGenerate => 'Failed to generate';

  @override
  String get payrollSummary => 'Payroll Summary';

  @override
  String staffMembersCount(int count) {
    return '$count staff members';
  }

  @override
  String get viewAll => 'View All';

  @override
  String get totalHours => 'Total Hours';

  @override
  String get totalPayroll => 'Total Payroll';

  @override
  String get averagePerStaff => 'Avg/Staff';

  @override
  String get topEarners => 'Top Earners';

  @override
  String get noPayrollDataForPeriod => 'No payroll data for this period';

  @override
  String shiftsAndHours(int shifts, String hours) {
    return '$shifts shifts • ${hours}h';
  }

  @override
  String get topPerformers => 'Top Performers';

  @override
  String get basedOnShiftsCompleted => 'Based on shifts completed';

  @override
  String get approveHours => 'Approve Hours';

  @override
  String get uploadSignInSheet => 'Upload Sign-In Sheet';

  @override
  String get takePhotoOrUploadSheet =>
      'Take a photo or upload the client\'s sign-in/out sheet';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get analyzeWithAi => 'Analyze with AI';

  @override
  String get analyzingSignInSheetWithAi => 'Analyzing sign-in sheet with AI...';

  @override
  String get extractedStaffHours => 'Extracted Staff Hours';

  @override
  String get reviewAndEditBeforeSubmitting =>
      'Review and edit before submitting';

  @override
  String get signInLabel => 'Sign In';

  @override
  String get signOutLabel => 'Sign Out';

  @override
  String get notAvailable => 'N/A';

  @override
  String hoursCount(String hours) {
    return '$hours hours';
  }

  @override
  String get bulkApprove => 'Bulk Approve';

  @override
  String approveHoursForAllStaff(int count) {
    return 'Approve hours for all $count staff members?';
  }

  @override
  String get approveAll => 'Approve All';

  @override
  String get nameMatchingResults => 'Name Matching Results';

  @override
  String staffMembersMatched(int processed, int total) {
    return '$processed/$total staff members matched';
  }

  @override
  String editHoursFor(String name) {
    return 'Edit Hours - $name';
  }

  @override
  String get signInTime => 'Sign In Time';

  @override
  String get signOutTime => 'Sign Out Time';

  @override
  String get approvedHours => 'Approved Hours';

  @override
  String get optionalNotes => 'Optional notes';

  @override
  String get noHoursMatched =>
      'No hours were matched. Please check the names on the sheet.';

  @override
  String get noHoursApproved =>
      'No hours were approved. Check match results above.';

  @override
  String get failedToBulkApprove => 'Failed to bulk approve';

  @override
  String get analysisFailed => 'Analysis failed';

  @override
  String get failedToPickImage => 'Failed to pick image';

  @override
  String get failedToLoadEvents => 'Failed to load events';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get allCaughtUp => 'All Caught Up!';

  @override
  String get noEventsNeedApproval =>
      'No events need hours approval at the moment.';

  @override
  String pendingReviewCount(int count) {
    return '$count Pending Review';
  }

  @override
  String get pendingReview => 'Pending Review';

  @override
  String get dateUnknown => 'Date unknown';

  @override
  String get manualHoursEntry => 'Manual Hours Entry';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get searchStaffByNameEmail => 'Search staff by name or email';

  @override
  String get failedToLoadUsers => 'Failed to load users';

  @override
  String get failedToSearchUsers => 'Failed to search users';

  @override
  String get noUsersFound => 'No users found';

  @override
  String submitHoursCount(int count) {
    return 'Submit Hours ($count)';
  }

  @override
  String hoursForStaff(String name) {
    return 'Hours for $name';
  }

  @override
  String get signInTimeRequired => 'Sign-In Time *';

  @override
  String get notSet => 'Not set';

  @override
  String get signOutTimeRequired => 'Sign-Out Time *';

  @override
  String totalHoursFormat(String hours) {
    return 'Total: $hours hours';
  }

  @override
  String get hoursSubmittedApprovedSuccess =>
      'Hours submitted and approved successfully';

  @override
  String get failedToSubmitHours => 'Failed to submit hours';

  @override
  String get pleaseEnterSignInSignOut =>
      'Please enter sign-in and sign-out times for all selected staff';

  @override
  String get createTeamTitle => 'Create Team';

  @override
  String get teamNameLabel => 'Team name';

  @override
  String get enterTeamNameError => 'Enter a team name';

  @override
  String get deleteTeamConfirmation => 'Delete team?';

  @override
  String get deleteTeamWarning =>
      'Deleting this team will remove it permanently. Events that reference it will block deletion.';

  @override
  String get teamDeleted => 'Team deleted';

  @override
  String get failedToDeleteTeam => 'Failed to delete team';

  @override
  String get noTeamsYet => 'No teams yet. Tap \"New team\" to create one.';

  @override
  String get untitledTeam => 'Untitled team';

  @override
  String get coManager => 'Co-Manager';

  @override
  String get inviteByEmail => 'Invite by email';

  @override
  String get messageOptional => 'Message (optional)';

  @override
  String get sendInvite => 'Send invite';

  @override
  String get failedToSendInvite => 'Failed to send invite';

  @override
  String inviteSentTo(String email) {
    return 'Invite sent to $email';
  }

  @override
  String get revokeInviteLink => 'Revoke Invite Link';

  @override
  String get revokeInviteLinkConfirmation =>
      'This will prevent anyone from using this link to join. Continue?';

  @override
  String get revoke => 'Revoke';

  @override
  String get inviteLinkRevoked => 'Invite link revoked';

  @override
  String get usageLog => 'Usage Log';

  @override
  String get noUsageRecorded => 'No usage recorded yet.';

  @override
  String get errorLoadingUsage => 'Error loading usage';

  @override
  String get publicLinkCreated => 'Public Link Created!';

  @override
  String get publicLinkDescription =>
      'Share this link on social media to recruit new team members. All applicants will require your approval.';

  @override
  String get linkCopied => 'Link copied!';

  @override
  String get codeLabel => 'Code:';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get shareJoinTeam => 'Join our team on FlowShift';

  @override
  String get addCoManager => 'Add Co-Manager';

  @override
  String get addCoManagerInstructions =>
      'Enter the email of a manager to add them as a co-manager. They must already have a FlowShift Manager account.';

  @override
  String get managerEmailLabel => 'Manager email';

  @override
  String get enterEmailError => 'Enter an email';

  @override
  String get enterValidEmailError => 'Enter a valid email';

  @override
  String get coManagerAdded => 'Co-manager added';

  @override
  String get removeCoManager => 'Remove co-manager';

  @override
  String removeCoManagerConfirmation(String name) {
    return 'Remove $name as co-manager?';
  }

  @override
  String get coManagerRemoved => 'Co-manager removed';

  @override
  String get userMissingProviderError =>
      'User is missing provider/subject information';

  @override
  String get addTeamMember => 'Add team member';

  @override
  String get searchByNameOrEmail => 'Search by name or email';

  @override
  String get noUsersFoundTryAnother => 'No users found. Try another search.';

  @override
  String get memberChip => 'Member';

  @override
  String addedToTeam(String name) {
    return 'Added $name to the team';
  }

  @override
  String get failedToAddMember => 'Failed to add member';

  @override
  String get inviteCancelled => 'Invite cancelled';

  @override
  String get failedToCancelInvite => 'Failed to cancel invite';

  @override
  String get failedToLoadTeamData => 'Could not load team data';

  @override
  String get membersSection => 'Members';

  @override
  String get noActiveMembersYet => 'No active members yet.';

  @override
  String get pendingMember => 'Pending member';

  @override
  String get coManagersSection => 'Co-Managers';

  @override
  String get noCoManagersYet => 'No co-managers yet.';

  @override
  String get removeCoManagerTooltip => 'Remove co-manager';

  @override
  String get invitesSection => 'Invites';

  @override
  String get inviteLinkButton => 'Invite Link';

  @override
  String get publicLinkButton => 'Public Link';

  @override
  String get emailInviteButton => 'Email';

  @override
  String get noInvitesYet => 'No invites yet.';

  @override
  String get pendingApplicants => 'Pending Applicants';

  @override
  String get activeInviteLinks => 'Active Invite Links';

  @override
  String get publicBadge => 'PUBLIC';

  @override
  String get usedLabel => 'Used:';

  @override
  String get unlimitedUses => '(unlimited)';

  @override
  String get joinsLabel => 'joins';

  @override
  String get denyApplicant => 'Deny Applicant';

  @override
  String get denyApplicantConfirmation =>
      'Are you sure you want to deny this applicant?';

  @override
  String get deny => 'Deny';

  @override
  String get applicantApproved => 'Applicant approved!';

  @override
  String get applicantDenied => 'Applicant denied';

  @override
  String get chatTitle => 'Chats';

  @override
  String get searchConversations => 'Search conversations...';

  @override
  String get failedToLoadConversations => 'Failed to load conversations';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get startChattingWithTeam =>
      'Start chatting with your team to see your messages here';

  @override
  String get managerBadge => 'Manager';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get addMembersToStartChatting =>
      'Add members to your team to start chatting';

  @override
  String get newChat => 'New Chat';

  @override
  String get searchContacts => 'Search contacts...';

  @override
  String get failedToLoadContacts => 'Failed to load contacts';

  @override
  String get noContactsMatch => 'No contacts match your search';

  @override
  String get noTeamMembersYet => 'No team members yet';

  @override
  String get active => 'Active';

  @override
  String get valerioAssistant => 'Valerio Assistant';

  @override
  String get valerioAssistantDesc =>
      'Create events, manage jobs, and get instant help';

  @override
  String get typing => 'typing...';

  @override
  String get failedToSendMessage => 'Failed to send message';

  @override
  String get sendMessageToStartConversation =>
      'Send a message to start the conversation';

  @override
  String get failedToLoadMessages => 'Failed to load messages';

  @override
  String staffAcceptedInvitation(String name) {
    return '$name accepted the invitation!';
  }

  @override
  String staffDeclinedInvitation(String name) {
    return '$name declined the invitation';
  }

  @override
  String get failedToSendInvitation => 'Failed to send invitation';

  @override
  String get noUpcomingJobs => 'No upcoming jobs';

  @override
  String get noJobsMatch => 'No jobs match your search';

  @override
  String get unknownClient => 'Unknown Client';

  @override
  String get noVenueSpecified => 'No venue specified';

  @override
  String get noDateSpecified => 'No date specified';

  @override
  String get selectRoleForStaffMember => 'Select a role for the staff member:';

  @override
  String get noRolesAvailable => 'No roles available for this job';

  @override
  String get sending => 'Sending...';

  @override
  String get sendInvitation => 'Send Invitation';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get waitingForResponse => 'Waiting for response...';

  @override
  String callTime(String time) {
    return 'Call time: $time';
  }

  @override
  String acceptedStaffCount(int count) {
    return 'Accepted Staff ($count)';
  }

  @override
  String get workingHoursSheet => 'Working Hours Sheet';

  @override
  String get hoursSheetPdf => 'Hours Sheet (PDF)';

  @override
  String get hoursSheetWord => 'Hours Sheet (Word)';

  @override
  String get member => 'Member';

  @override
  String staffIdDisplay(String id) {
    return 'ID: $id';
  }

  @override
  String get removeStaffMember => 'Remove Staff Member';

  @override
  String get confirmRemoveStaff =>
      'Are you sure you want to remove this staff member from the event?';

  @override
  String get staffRemovedSuccess => 'Staff member removed successfully';

  @override
  String get failedToRemoveStaff => 'Failed to remove staff member';

  @override
  String confirmClockIn(String staffName) {
    return 'Clock in $staffName for this event?';
  }

  @override
  String alreadyClockedInName(String staffName) {
    return '$staffName is already clocked in';
  }

  @override
  String clockedInSuccess(String staffName) {
    return '$staffName clocked in successfully';
  }

  @override
  String get clockInFailed => 'Clock-in failed. Please try again.';

  @override
  String get publish => 'Publish';

  @override
  String get editDetails => 'Edit Details';

  @override
  String get keepOpenAfterEvent => 'Keep Open After Event';

  @override
  String get preventAutoCompletion =>
      'Prevent automatic completion when event date passes';

  @override
  String get moveToDrafts => 'Move to Drafts';

  @override
  String get clockInStaff => 'Clock In Staff';

  @override
  String get openToAllStaff => 'Open to All Staff';

  @override
  String moveToDraftsWithStaff(int count) {
    return 'This will:\n• Remove all $count accepted staff members\n• Send them a notification\n• Hide the job from staff view\n\nYou can republish it later.';
  }

  @override
  String get moveToDraftsNoStaff =>
      'This will hide the job from staff view. You can republish it later.';

  @override
  String eventMovedToDrafts(String name) {
    return '$name moved to drafts!';
  }

  @override
  String get failedToMoveToDrafts => 'Failed to move to drafts';

  @override
  String get eventStaysOpen => 'Event will stay open after completion';

  @override
  String get eventAutoCompletes => 'Event will auto-complete when past';

  @override
  String get failedToUpdate => 'Failed to update';

  @override
  String get failedToGenerateSheet => 'Failed to generate sheet';

  @override
  String confirmOpenToAll(String name) {
    return 'Make \"$name\" visible to all staff members?\n\nThis will change the job from private (invited only) to public, allowing all team members to see and accept it.';
  }

  @override
  String get openToAll => 'Open to All';

  @override
  String eventNowOpenToAll(String name) {
    return '$name is now open to all staff!';
  }

  @override
  String get failedToMakePublic => 'Failed to make public';

  @override
  String get vacanciesLeft => 'left';

  @override
  String get manageYourPreferences => 'Manage your preferences';

  @override
  String get workTerminology => 'Work Terminology';

  @override
  String get howPreferWorkAssignments =>
      'How do you prefer to call your work assignments?';

  @override
  String get jobs => 'Jobs';

  @override
  String get jobsExample => 'e.g., \"My Jobs\", \"Create Job\"';

  @override
  String get shifts => 'Shifts';

  @override
  String get shiftsExample => 'e.g., \"My Shifts\", \"Create Shift\"';

  @override
  String get events => 'Events';

  @override
  String get eventsExample => 'e.g., \"My Events\", \"Create Event\"';

  @override
  String get saveTerminology => 'Save Terminology';

  @override
  String get terminologyUpdateInfo =>
      'This will update how work assignments appear throughout the app';

  @override
  String get venuesUpdatedSuccess => 'Venues updated successfully!';

  @override
  String get terminologyUpdatedSuccess => 'Terminology updated successfully!';

  @override
  String get locationVenues => 'Location & Venues';

  @override
  String get cities => 'Cities';

  @override
  String get citiesConfigured => 'cities configured';

  @override
  String get venues => 'Venues';

  @override
  String get discovered => 'discovered';

  @override
  String get lastUpdated => 'Last Updated';

  @override
  String get noCitiesConfiguredDescription =>
      'No cities configured yet. Add cities to discover venues and help the AI suggest accurate event locations in your area.';

  @override
  String get manageCities => 'Manage Cities';

  @override
  String get addCities => 'Add Cities';

  @override
  String viewAllVenues(int count) {
    return 'View All $count Venues';
  }

  @override
  String get addNewVenue => 'Add New Venue';

  @override
  String get venueAddedSuccess => 'Venue added successfully!';

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get failedToLoadProfile =>
      'Failed to load profile. Please try again in a few minutes.';

  @override
  String get failedToUploadImage => 'Failed to upload image';

  @override
  String get newLookSaved => 'New look saved!';

  @override
  String get failedToSave => 'Failed to save';

  @override
  String get profilePictureUpdated => 'Profile picture updated!';

  @override
  String get deleteCreationConfirm => 'Delete creation?';

  @override
  String get deleteCreationMessage => 'This will remove it from your gallery.';

  @override
  String get creationDeleted => 'Creation deleted';

  @override
  String get failedToDelete => 'Failed to delete';

  @override
  String get revertedToOriginal => 'Reverted to original photo';

  @override
  String get failedToRevert => 'Failed to revert';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get appIdOptional => 'App ID (9 digits, optional)';

  @override
  String get linkedAccounts => 'Linked Accounts';

  @override
  String get primary => 'Primary';

  @override
  String get linkAccount => 'Link';

  @override
  String get phoneNumberLinkedSuccess => 'Phone number linked successfully!';

  @override
  String get upload => 'Upload';

  @override
  String get glowUp => 'Glow Up';

  @override
  String get originalPhoto => 'Original Photo';

  @override
  String get myCreations => 'My Creations';

  @override
  String get viewFullSize => 'View Full Size';

  @override
  String get useThisPhoto => 'Use This Photo';

  @override
  String get linkPhoneNumber => 'Link Phone Number';

  @override
  String get addPhoneSigninMethod =>
      'Add a phone number as an alternative sign-in method';

  @override
  String get sixDigitCode => '6-digit code';

  @override
  String get verifyAndLink => 'Verify & Link';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get invalidPhoneNumberFormat => 'Invalid phone number format';

  @override
  String get tooManyAttempts => 'Too many attempts. Try later.';

  @override
  String get enterSixDigitCode => 'Please enter the 6-digit code';

  @override
  String get noVerificationInProgress => 'No verification in progress';

  @override
  String get invalidCode => 'Invalid code. Check and try again.';

  @override
  String get codeExpired => 'Code expired. Request a new one.';

  @override
  String get firebaseAuthFailed => 'Firebase authentication failed';

  @override
  String get failedToGetAuthToken => 'Failed to get auth token';

  @override
  String get failedToLinkPhoneNumber => 'Failed to link phone number';

  @override
  String get failedToLink => 'Failed to link';

  @override
  String get failedToSendCode => 'Failed to send code';

  @override
  String get welcomeFlowShiftPro =>
      'Welcome to FlowShift Pro! All business features unlocked.';

  @override
  String get purchaseCancelledFailed =>
      'Purchase cancelled or failed. Please try again.';

  @override
  String get subscriptionRestoredSuccess =>
      'Subscription restored successfully!';

  @override
  String get noActiveSubscription => 'No active subscription found to restore.';

  @override
  String get restoreError => 'Restore error';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get scaleYourBusiness => 'Scale Your Business';

  @override
  String get unlimitedTeamMembers => 'Unlimited team members';

  @override
  String get noLimitsStaffSize => 'No limits on staff size';

  @override
  String get unlimitedEvents => 'Unlimited events';

  @override
  String get createManyEvents => 'Create as many events as you need';

  @override
  String get advancedAnalytics => 'Advanced analytics';

  @override
  String get insightsReports => 'Insights & reports for your business';

  @override
  String get prioritySupport => 'Priority support';

  @override
  String get getHelpWhenNeeded => 'Get help when you need it';

  @override
  String get allFutureProFeatures => 'All future Pro features';

  @override
  String get earlyAccessCapabilities => 'Early access to new capabilities';

  @override
  String get perMonth => 'per month';

  @override
  String get cancelAnytimeNoCommitments => 'Cancel anytime • No commitments';

  @override
  String get restorePurchase => 'Restore Purchase';

  @override
  String get freeTierLimits => 'Free Tier Limits';

  @override
  String get freeTierLimitsList =>
      '• 25 team members max\n• 10 events per month\n• No analytics access';

  @override
  String get subscriptionTermsDisclaimer =>
      'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String get failedToLoadVenues => 'Failed to load venues';

  @override
  String get venueAddedSuccessfully => 'Venue added successfully!';

  @override
  String get venueUpdatedSuccessfully => 'Venue updated successfully!';

  @override
  String get venueRemovedSuccessfully => 'Venue removed successfully!';

  @override
  String get failedToDeleteVenue => 'Failed to delete venue';

  @override
  String get removeVenueConfirmation => 'Remove Venue?';

  @override
  String confirmRemoveVenue(String name) {
    return 'Are you sure you want to remove \"$name\"?';
  }

  @override
  String get myVenues => 'My Venues';

  @override
  String get addVenue => 'Add Venue';

  @override
  String get noVenuesYet => 'No venues yet';

  @override
  String get addFirstVenueOrDiscover =>
      'Add your first venue or run venue discovery';

  @override
  String get addFirstVenue => 'Add First Venue';

  @override
  String get yourArea => 'Your Area';

  @override
  String get placesSource => 'Places';

  @override
  String get manualSource => 'Manual';

  @override
  String get aiSource => 'AI';

  @override
  String get searchVenues => 'Search venues...';

  @override
  String noVenuesInCity(String cityName) {
    return 'No venues in $cityName yet';
  }

  @override
  String get addVenuesManuallyOrDiscover =>
      'Add venues manually or discover them from Settings > Manage Cities';

  @override
  String get addCitiesFromSettings =>
      'Add cities from Settings > Manage Cities';

  @override
  String get noVenuesMatch => 'No venues match your search';

  @override
  String get tryDifferentFilterOrTerm =>
      'Try a different filter or search term';

  @override
  String get tryDifferentSearchTerm => 'Try a different search term';

  @override
  String get failedToGetPlaceDetails => 'Failed to get place details';

  @override
  String get editVenue => 'Edit Venue';

  @override
  String get editVenueDetailsBelow => 'Edit venue details below';

  @override
  String get searchVenueAutoFill =>
      'Search for a venue and we\'ll auto-fill the details';

  @override
  String get searchVenue => 'Search venue';

  @override
  String get venueSearchExample => 'e.g., Ball Arena Denver';

  @override
  String get enterManuallyInstead => 'Enter manually instead';

  @override
  String get venueFoundGooglePlaces => 'Venue found via Google Places';

  @override
  String get clear => 'Clear';

  @override
  String get venueName => 'Venue Name *';

  @override
  String get venueNameExample => 'e.g., Ball Arena';

  @override
  String get pleaseEnterVenueName => 'Please enter a venue name';

  @override
  String get addressRequired => 'Address *';

  @override
  String get addressExample => 'e.g., 1000 Chopper Cir, Denver, CO 80204';

  @override
  String get pleaseEnterAddress => 'Please enter an address';

  @override
  String get required => 'Required';

  @override
  String get venueAddedCityTabCreated =>
      'Venue added and new city tab created!';

  @override
  String get venueUpdatedCityTabAdded => 'Venue updated and city tab added!';

  @override
  String get failedToSaveVenue => 'Failed to save venue';

  @override
  String get saving => 'Saving...';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get failedToLoadCities => 'Failed to load cities';

  @override
  String get cityAlreadyInList => 'This city is already in your list';

  @override
  String addedCity(String city) {
    return 'Added $city';
  }

  @override
  String get failedToAddCity => 'Failed to add city';

  @override
  String get failedToUpdateCity => 'Failed to update city';

  @override
  String get deleteCity => 'Delete City';

  @override
  String confirmDeleteCity(String cityName) {
    return 'Delete $cityName?\n\nThis will also remove all venues associated with this city.';
  }

  @override
  String deletedCity(String cityName) {
    return 'Deleted $cityName';
  }

  @override
  String get failedToDeleteCity => 'Failed to delete city';

  @override
  String get discoverVenues => 'Discover Venues';

  @override
  String discoverVenuesWarning(String cityName) {
    return 'AI will search the web for event venues in $cityName. This can take up to 2-3 minutes depending on the city size.\n\nPlease keep the app open during the search.';
  }

  @override
  String get startSearch => 'Start Search';

  @override
  String discoveredVenuesCount(int count, String cityName) {
    return 'Discovered $count venues for $cityName';
  }

  @override
  String get failedToDiscoverVenues => 'Failed to discover venues';

  @override
  String get noCitiesAddedYet => 'No cities added yet';

  @override
  String get addFirstCityDiscover => 'Add your first city to discover venues';

  @override
  String get touristCityStrictSearch => 'Tourist City (strict search)';

  @override
  String get metroAreaBroadSearch => 'Metro Area (broad search)';

  @override
  String get searchingWeb => 'Searching web... (up to 3 min)';

  @override
  String get addCity => 'Add City';

  @override
  String get selectOrTypeCity => 'Select or Type City';

  @override
  String get country => 'Country';

  @override
  String get allCountries => 'All Countries';

  @override
  String get stateProvince => 'State/Province';

  @override
  String get allStates => 'All States';

  @override
  String get typeOrSearchCity => 'Type or Search City';

  @override
  String get enterAnyCityName => 'Enter any city name...';

  @override
  String get useCustomCity => 'Use custom city:';

  @override
  String get noMatchingCitiesSuggestions => 'No matching cities in suggestions';

  @override
  String get canTypeAnyCityAbove => 'You can type any city name above';

  @override
  String get tourist => 'Tourist';

  @override
  String get metro => 'Metro';

  @override
  String get suggestedCities => 'suggested cities';

  @override
  String get addYourFirstCity => 'Add Your First City';

  @override
  String get addAnotherCity => 'Add Another City';

  @override
  String get logoUploadedColorsExtracted =>
      'Logo uploaded and colors extracted!';

  @override
  String get failedToUploadLogo => 'Failed to upload logo';

  @override
  String get removeBrandingConfirmation => 'Remove Branding?';

  @override
  String get removeBrandingWarning =>
      'This will delete your logo and custom colors. Exported documents will revert to the default FlowShift styling.';

  @override
  String get brandCustomization => 'Brand Customization';

  @override
  String get pro => 'PRO';

  @override
  String get upgradeToProCustomization =>
      'Upgrade to Pro to personalize your exported documents with your own logo and brand colors.';

  @override
  String get uploadYourLogo => 'Upload Your Logo';

  @override
  String get logoFormats => 'JPEG, PNG, or WebP (max 5MB)';

  @override
  String get replaceLogo => 'Replace Logo';

  @override
  String get documentStyle => 'Document Style';

  @override
  String get chooseDocumentStyle => 'Choose how exported documents look';

  @override
  String get extractingColors => 'Extracting brand colors with AI...';

  @override
  String get uploadingLogo => 'Uploading logo...';

  @override
  String get brandingRemoved => 'Branding removed';

  @override
  String get colorsSaved => 'Colors saved!';

  @override
  String get saveColors => 'Save Colors';

  @override
  String get aiExtracted => 'AI Extracted';

  @override
  String get hexColor => 'Hex Color';

  @override
  String get presets => 'Presets';

  @override
  String get mergeDuplicateClients => 'Merge Duplicate Clients';

  @override
  String get mergingClients => 'Merging clients...';

  @override
  String get confirmMerge => 'Confirm Merge';

  @override
  String keepPrimary(String name) {
    return 'Keep: \"$name\"';
  }

  @override
  String mergeDuplicatesCount(int count) {
    return 'Merge & delete $count duplicate(s):';
  }

  @override
  String transferEventsAndTariffs(String name) {
    return 'All events and tariffs will be transferred to \"$name\".';
  }

  @override
  String get merge => 'Merge';

  @override
  String get failedToMerge => 'Failed to merge';

  @override
  String mergedClients(int count, String name) {
    return 'Merged $count client(s) into \"$name\"';
  }

  @override
  String sensitivityLabel(int percent) {
    return 'Sensitivity: $percent%';
  }

  @override
  String get noDuplicatesFound => 'No duplicates found';

  @override
  String get lowerSensitivity =>
      'Try lowering the sensitivity to find looser matches.';

  @override
  String groupNumber(int number) {
    return 'Group $number';
  }

  @override
  String get similarPercent => '% similar';

  @override
  String clientsCountLabel(int count) {
    return '$count clients';
  }

  @override
  String get tapClientSetPrimary => 'Tap a client to set it as primary (kept):';

  @override
  String get willBeMerged => 'will be merged';

  @override
  String get keep => 'KEEP';

  @override
  String mergeInto(int count, String name) {
    return 'Merge $count into \"$name\"';
  }

  @override
  String get profileGlowUp => 'Profile Glow Up';

  @override
  String get whoAreYouToday => 'Who are you today?';

  @override
  String seeMore(int count) {
    return 'See $count more';
  }

  @override
  String get seeLess => 'Less';

  @override
  String get pickYourVibe => 'Pick your vibe';

  @override
  String get quality => 'Quality';

  @override
  String get standard => 'Standard';

  @override
  String get hd => 'HD';

  @override
  String get higherDetailFacialPreservation =>
      'Higher detail & better facial preservation';

  @override
  String get textInImage => 'Text in image';

  @override
  String get optional => 'Optional';

  @override
  String get none => 'None';

  @override
  String get readyForNewLook => 'Ready for a new look?';

  @override
  String get hitButtonSeeMagic => 'Hit the button and see the magic';

  @override
  String get lookingGood => 'Looking good!';

  @override
  String get fromYourHistory => 'From your history';

  @override
  String get before => 'Before';

  @override
  String get after => 'After';

  @override
  String get usuallyTakes15Seconds => 'This usually takes about 15 seconds';

  @override
  String get failedToLoadStyles => 'Failed to load styles';

  @override
  String get aiGeneratedMayNotBeAccurate =>
      'AI-generated images may not be accurate';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get generateNew => 'Generate New';

  @override
  String get getMyNewLook => 'Get My New Look';

  @override
  String get sendEventInvitationTooltip => 'Send Event Invitation';

  @override
  String get exportReport => 'Export Report';

  @override
  String get chooseFormatAndReportType => 'Choose format and report type';

  @override
  String get reportType => 'Report Type';

  @override
  String get payrollReportLabel => 'Payroll Report';

  @override
  String get payrollReportDescription =>
      'Staff earnings breakdown by hours and pay rate';

  @override
  String get attendanceReportLabel => 'Attendance Report';

  @override
  String get attendanceReportDescription =>
      'Clock-in/out times and hours worked';

  @override
  String get exportFormat => 'Export Format';

  @override
  String get csvLabel => 'CSV';

  @override
  String get excelCompatible => 'Excel compatible';

  @override
  String get pdfLabel => 'PDF';

  @override
  String get printReady => 'Print ready';

  @override
  String exportFormatButton(String format) {
    return 'Export $format';
  }

  @override
  String get lastSevenDays => 'Last 7 days';

  @override
  String get thisMonth => 'This month';

  @override
  String get thisYear => 'This year';

  @override
  String get customRange => 'Custom range';

  @override
  String get createInviteLinkTitle => 'Create Invite Link';

  @override
  String get shareableLinkDescription =>
      'Create a shareable link that anyone can use to join your team.';

  @override
  String get linkExpiresIn => 'Link expires in:';

  @override
  String get maxUsesOptional => 'Max uses (optional):';

  @override
  String get leaveEmptyUnlimited => 'Leave empty for unlimited';

  @override
  String get requireApprovalTitle => 'Require approval';

  @override
  String get requireApprovalSubtitle =>
      'You must approve members after they join';

  @override
  String get passwordOptionalLabel => 'Password (optional):';

  @override
  String get leaveEmptyNoPassword => 'Leave empty for no password';

  @override
  String get createLinkButton => 'Create Link';

  @override
  String get inviteLinkCreatedTitle => 'Invite Link Created!';

  @override
  String get inviteCodeLabel => 'Invite Code:';

  @override
  String get deepLinkLabel => 'Deep Link:';

  @override
  String get shareDeepLinkHint =>
      'Share this link - it will open the app automatically';

  @override
  String expiresDate(String date) {
    return 'Expires: $date';
  }

  @override
  String get shareViaApps => 'Share via WhatsApp, SMS, etc.';

  @override
  String get showQrCode => 'Show QR Code';

  @override
  String get joinTeamSubject => 'Join my team on FlowShift';

  @override
  String get unknownApplicant => 'Unknown applicant';

  @override
  String appliedDate(String date) {
    return 'Applied $date';
  }

  @override
  String get errorLoadingEvents => 'Error loading events';

  @override
  String get noEventsFoundTitle => 'No events found';

  @override
  String get notLinkedToEventsYet =>
      'This user is not linked to any events yet';

  @override
  String upcomingEventsCount(int count) {
    return 'Upcoming Events ($count)';
  }

  @override
  String get dateUnknownLabel => 'Date Unknown';

  @override
  String get editEventTitle => 'Edit Event';

  @override
  String get eventUpdatedSuccessfully => 'Event has been updated successfully!';

  @override
  String get failedToUpdateEvent => 'Failed to update event';

  @override
  String get selectDateHint => 'Select date';

  @override
  String get dateLabel => 'Date';

  @override
  String clockOutConfirmation(String name) {
    return 'Are you sure you want to clock out $name?';
  }

  @override
  String get removeStaffConfirmation =>
      'Are you sure you want to remove this staff member from the event?';

  @override
  String openToAllStaffConfirmation(String name) {
    return 'Make \"$name\" visible to all staff members?\n\nThis will change the job from private (invited only) to public, allowing all team members to see and accept it.';
  }

  @override
  String clockInConfirmation(String name) {
    return 'Clock in $name for this event?';
  }

  @override
  String get workingHoursSheetTooltip => 'Working Hours Sheet';

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get privateLabel => 'Private';

  @override
  String get publicLabel => 'Public';

  @override
  String get privatePlusPublic => 'Private+Public';

  @override
  String get setUpStaffingCompany =>
      'Set up your staffing company (e.g., \"MES - Minneapolis Event Staffing\")';

  @override
  String get descriptionOptionalLabel => 'Description (optional)';

  @override
  String get briefDescriptionHint =>
      'Brief description of your staffing company';

  @override
  String get createTeamButton => 'Create team';

  @override
  String clientsConfiguredCount(int count) {
    return 'Clients configured: $count';
  }

  @override
  String get needAtLeastOneClientDesc =>
      'You need at least one client before you can staff events.';

  @override
  String get clientNameLabel => 'Client name';

  @override
  String get completeProfileAndTeam => 'Complete profile and team first';

  @override
  String get createClientButton => 'Create client';

  @override
  String rolesConfiguredCount(int count) {
    return 'Roles configured: $count';
  }

  @override
  String get rolesHelpMatchStaffDesc =>
      'Roles help match staff to the right job (waiter, chef, bartender...).';

  @override
  String get roleNameLabel => 'Role name';

  @override
  String get finishPreviousSteps => 'Finish previous steps first';

  @override
  String get createRoleButton => 'Create role';

  @override
  String tariffsConfiguredCount(int count) {
    return 'Tariffs configured: $count';
  }

  @override
  String get setRateDescription =>
      'Set a rate so staffing assignments know what to bill.';

  @override
  String get clientLabel => 'Client';

  @override
  String get roleLabel => 'Role';

  @override
  String get adjustLaterHint =>
      'You can adjust this later in Catalog > Tariffs';

  @override
  String get pleaseEnterTimesForAllStaff =>
      'Please enter sign-in and sign-out times for all selected staff';

  @override
  String get hoursSubmittedAndApproved =>
      'Hours submitted and approved successfully';

  @override
  String submitHoursButton(int count) {
    return 'Submit Hours ($count)';
  }

  @override
  String get bartenderHint => 'Bartender';

  @override
  String get notesLabel => 'Notes';

  @override
  String get roleHint => 'Role';

  @override
  String get noEventsNeedApprovalDescription =>
      'No events need hours approval at the moment.';

  @override
  String get pendingReviewLabel => 'Pending Review';

  @override
  String get needsSheetLabel => 'Needs Sheet';

  @override
  String get purchaseCancelledMessage =>
      'Purchase cancelled or failed. Please try again.';

  @override
  String get upgradeToProTitle => 'Upgrade to Pro';

  @override
  String get flowShiftPro => 'FlowShift Pro';

  @override
  String get createAsManyEvents => 'Create as many events as you need';

  @override
  String get noLimitsDescription => 'No limits on staff size';

  @override
  String get earlyAccessDescription => 'Early access to new capabilities';

  @override
  String get subscriptionTerms =>
      'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.';

  @override
  String get staffWillAppearOnClockIn =>
      'Staff will appear here when they clock in';

  @override
  String get cancelInvite => 'Cancel invite';

  @override
  String usedCount(int used, int max) {
    return 'Used: $used / $max';
  }

  @override
  String usedCountUnlimited(int used) {
    return 'Used: $used (unlimited)';
  }

  @override
  String codePrefix(String code) {
    return 'Code: $code';
  }

  @override
  String get addVenuesDescription =>
      'Add venues manually or discover them from Settings > Manage Cities';

  @override
  String get searchVenuesHint => 'Search venues...';

  @override
  String get invalidPhoneFormat => 'Invalid phone number format';

  @override
  String get tooManyAttemptsMessage => 'Too many attempts. Try later.';

  @override
  String get invalidCodeMessage => 'Invalid code. Check and try again.';

  @override
  String get codeExpiredMessage => 'Code expired. Request a new one.';

  @override
  String get addPhoneDescription =>
      'Add a phone number as an alternative sign-in method';

  @override
  String get phoneNumberHint => 'Phone number';

  @override
  String get untitled => 'Untitled';

  @override
  String get message => 'Message';

  @override
  String get eventInformation => 'Event Information';

  @override
  String get venueInformation => 'Venue Information';

  @override
  String get staffRolesRequired => 'Staff Roles Required';

  @override
  String get successTitle => 'Success';

  @override
  String get selectTimeHint => 'Select time';

  @override
  String clockingInStaff(String staffName) {
    return 'Clocking in $staffName...';
  }

  @override
  String roleVacancies(
    String roleName,
    int accepted,
    int total,
    int vacancies,
  ) {
    return '$roleName ($accepted/$total, $vacancies left)';
  }

  @override
  String get phoneLinkedSuccessfully => 'Phone number linked successfully!';

  @override
  String teamReady(String name) {
    return 'Team ready: $name';
  }

  @override
  String get proWelcomeMessage =>
      'Welcome to FlowShift Pro! All business features unlocked.';

  @override
  String get dateTbd => 'Date TBD';

  @override
  String get freeTierLimitsDetails =>
      '• 25 team members max\n• 10 events per month\n• No analytics access';

  @override
  String get errorPrefix => 'Error';

  @override
  String moveToDraftsConfirmation(String name) {
    return 'Move \"$name\" back to drafts?';
  }

  @override
  String get memberRemovedSuccess => 'Member removed';

  @override
  String get failedToRemoveMember => 'Failed to remove member';

  @override
  String get staffHoursLabel => 'Staff Hours';

  @override
  String get eventsCompletedLabel => 'Events Completed';

  @override
  String get fulfillmentRateLabel => 'Fulfillment Rate';

  @override
  String get scanLabel => 'Scan';

  @override
  String get aiChatLabel => 'AI Chat';

  @override
  String get uploadLabel => 'Upload';
}
