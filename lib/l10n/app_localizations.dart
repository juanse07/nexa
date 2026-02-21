import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Title for the shift data extraction feature
  ///
  /// In en, this message translates to:
  /// **'Shift Data Extractor'**
  String get jobDataExtractor;

  /// Subtitle explaining PDF upload feature
  ///
  /// In en, this message translates to:
  /// **'Upload a PDF or image to extract catering shift details'**
  String get uploadPdfToExtract;

  /// Subtitle for manual entry option
  ///
  /// In en, this message translates to:
  /// **'Enter shift details manually for precise control'**
  String get enterJobDetailsManually;

  /// Subtitle for AI chat feature
  ///
  /// In en, this message translates to:
  /// **'Create jobs through natural conversation with AI'**
  String get createJobsThroughAI;

  /// No description provided for @jobDetails.
  ///
  /// In en, this message translates to:
  /// **'Shift Details'**
  String get jobDetails;

  /// No description provided for @jobInformation.
  ///
  /// In en, this message translates to:
  /// **'Shift Information'**
  String get jobInformation;

  /// No description provided for @jobTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Title'**
  String get jobTitle;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Client Name'**
  String get clientName;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @headcount.
  ///
  /// In en, this message translates to:
  /// **'Headcount'**
  String get headcount;

  /// No description provided for @locationInformation.
  ///
  /// In en, this message translates to:
  /// **'Location Information'**
  String get locationInformation;

  /// No description provided for @locationName.
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get locationName;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get contactName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @shift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shift;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Tab label showing shift counts
  ///
  /// In en, this message translates to:
  /// **'Jobs • {pendingCount} pending, {upcomingCount} upcoming, {pastCount} past'**
  String jobsTabLabel(int pendingCount, int upcomingCount, int pastCount);

  /// No description provided for @pendingUpcomingStatus.
  ///
  /// In en, this message translates to:
  /// **'{pendingCount} pending • {upcomingCount} upcoming • {baseTime}'**
  String pendingUpcomingStatus(
    int pendingCount,
    int upcomingCount,
    String baseTime,
  );

  /// No description provided for @upcomingPastStatus.
  ///
  /// In en, this message translates to:
  /// **'{upcomingCount} upcoming • {pastCount} past • {baseTime}'**
  String upcomingPastStatus(int upcomingCount, int pastCount, String baseTime);

  /// No description provided for @pleaseSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date for the shift'**
  String get pleaseSelectDate;

  /// No description provided for @jobSavedToPending.
  ///
  /// In en, this message translates to:
  /// **'Shift saved to pending. Go to Jobs tab to review.'**
  String get jobSavedToPending;

  /// No description provided for @jobDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Shift details copied to clipboard'**
  String get jobDetailsCopied;

  /// No description provided for @jobPosted.
  ///
  /// In en, this message translates to:
  /// **'Shift posted'**
  String get jobPosted;

  /// No description provided for @sendJobInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send Shift Invitation'**
  String get sendJobInvitation;

  /// No description provided for @inviteToJob.
  ///
  /// In en, this message translates to:
  /// **'Invite {name} to a shift'**
  String inviteToJob(String name);

  /// No description provided for @jobInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Shift invitation sent!'**
  String get jobInvitationSent;

  /// No description provided for @jobNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shift not found'**
  String get jobNotFound;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'{count} guests'**
  String guests(int count);

  /// No description provided for @rolesNeeded.
  ///
  /// In en, this message translates to:
  /// **'Roles Needed'**
  String get rolesNeeded;

  /// No description provided for @untitledJob.
  ///
  /// In en, this message translates to:
  /// **'Untitled Shift'**
  String get untitledJob;

  /// No description provided for @expectedHeadcount.
  ///
  /// In en, this message translates to:
  /// **'Expected Headcount'**
  String get expectedHeadcount;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get contactPhone;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact Email'**
  String get contactEmail;

  /// No description provided for @errorJobIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Error: Shift ID is missing...'**
  String get errorJobIdMissing;

  /// No description provided for @postJob.
  ///
  /// In en, this message translates to:
  /// **'Post Shift'**
  String get postJob;

  /// No description provided for @setRolesForJob.
  ///
  /// In en, this message translates to:
  /// **'Set roles for this shift'**
  String get setRolesForJob;

  /// No description provided for @searchJobs.
  ///
  /// In en, this message translates to:
  /// **'Search jobs...'**
  String get searchJobs;

  /// No description provided for @locationTbd.
  ///
  /// In en, this message translates to:
  /// **'Location TBD'**
  String get locationTbd;

  /// No description provided for @shareJobPrefix.
  ///
  /// In en, this message translates to:
  /// **'Shift: {clientName}'**
  String shareJobPrefix(String clientName);

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get navHours;

  /// No description provided for @navCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get navCatalog;

  /// No description provided for @uploadData.
  ///
  /// In en, this message translates to:
  /// **'Upload Data'**
  String get uploadData;

  /// No description provided for @manualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// No description provided for @multiUpload.
  ///
  /// In en, this message translates to:
  /// **'Multi-Upload'**
  String get multiUpload;

  /// No description provided for @aiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// No description provided for @detailedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Detailed Explanation'**
  String get detailedExplanation;

  /// No description provided for @messagesAndTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'Messages and team members'**
  String get messagesAndTeamMembers;

  /// No description provided for @searchNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search name or email'**
  String get searchNameOrEmail;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @bartender.
  ///
  /// In en, this message translates to:
  /// **'Bartender'**
  String get bartender;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages ({count})'**
  String messages(int count);

  /// No description provided for @youveBeenInvitedTo.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to {jobName}'**
  String youveBeenInvitedTo(String jobName);

  /// No description provided for @hoursApproval.
  ///
  /// In en, this message translates to:
  /// **'Hours Approval'**
  String get hoursApproval;

  /// No description provided for @needsSheet.
  ///
  /// In en, this message translates to:
  /// **'Needs Sheet'**
  String get needsSheet;

  /// No description provided for @needsSheetCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Needs Sheet'**
  String needsSheetCount(int count);

  /// No description provided for @staffCount.
  ///
  /// In en, this message translates to:
  /// **'{count} staff'**
  String staffCount(int count);

  /// No description provided for @catalogClientsRoles.
  ///
  /// In en, this message translates to:
  /// **'Catalog • {clientCount} clients, {roleCount} roles'**
  String catalogClientsRoles(int clientCount, int roleCount);

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @tariffs.
  ///
  /// In en, this message translates to:
  /// **'Tariffs'**
  String get tariffs;

  /// No description provided for @addClient.
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get addClient;

  /// No description provided for @teams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teams;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String members(int count);

  /// No description provided for @pendingInvites.
  ///
  /// In en, this message translates to:
  /// **'{count} pending invites'**
  String pendingInvites(int count);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @newTeam.
  ///
  /// In en, this message translates to:
  /// **'New team'**
  String get newTeam;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @manageTeams.
  ///
  /// In en, this message translates to:
  /// **'Manage Teams'**
  String get manageTeams;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// No description provided for @multiSelectTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Long-press to multi-select in the picker. Or use Add More to append.'**
  String get multiSelectTip;

  /// No description provided for @contactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformation;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get additionalNotes;

  /// No description provided for @saveJobDetails.
  ///
  /// In en, this message translates to:
  /// **'Save Shift Details'**
  String get saveJobDetails;

  /// No description provided for @saveToPending.
  ///
  /// In en, this message translates to:
  /// **'Save to Pending'**
  String get saveToPending;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a Conversation'**
  String get startConversation;

  /// No description provided for @aiWillGuideYou.
  ///
  /// In en, this message translates to:
  /// **'The AI will guide you through creating a shift'**
  String get aiWillGuideYou;

  /// No description provided for @startNewConversation.
  ///
  /// In en, this message translates to:
  /// **'Start New Conversation'**
  String get startNewConversation;

  /// No description provided for @fecha.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fecha;

  /// No description provided for @hora.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get hora;

  /// No description provided for @ubicacion.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get ubicacion;

  /// No description provided for @direccion.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get direccion;

  /// No description provided for @jobFor.
  ///
  /// In en, this message translates to:
  /// **'Shift for: {clientName}'**
  String jobFor(String clientName);

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @invitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get invitation;

  /// No description provided for @viewJobs.
  ///
  /// In en, this message translates to:
  /// **'View Jobs'**
  String get viewJobs;

  /// No description provided for @addToBartender.
  ///
  /// In en, this message translates to:
  /// **'Add to Bartender'**
  String get addToBartender;

  /// No description provided for @addToServer.
  ///
  /// In en, this message translates to:
  /// **'Add to Server'**
  String get addToServer;

  /// No description provided for @addToRole.
  ///
  /// In en, this message translates to:
  /// **'Add to {role}'**
  String addToRole(String role);

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get continueWithPhone;

  /// No description provided for @appRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get appRoleManager;

  /// No description provided for @termsAndPrivacyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our\nTerms of Service and Privacy Policy'**
  String get termsAndPrivacyDisclaimer;

  /// No description provided for @pleaseEnterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter email and password'**
  String get pleaseEnterEmailAndPassword;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get googleSignInFailed;

  /// No description provided for @appleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed'**
  String get appleSignInFailed;

  /// No description provided for @emailSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in failed'**
  String get emailSignInFailed;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Phone Sign In'**
  String get phoneSignIn;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get enterVerificationCode;

  /// No description provided for @weWillSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification code'**
  String get weWillSendVerificationCode;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get sendVerificationCode;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCode;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @pleaseEnterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterPhoneNumber;

  /// No description provided for @pleaseEnterValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterValidPhoneNumber;

  /// No description provided for @pleaseEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get pleaseEnterVerificationCode;

  /// No description provided for @verificationCodeMustBe6Digits.
  ///
  /// In en, this message translates to:
  /// **'Verification code must be 6 digits'**
  String get verificationCodeMustBe6Digits;

  /// No description provided for @didntReceiveCodeResend.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Resend'**
  String get didntReceiveCodeResend;

  /// No description provided for @welcomeToFlowShift.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FlowShift!'**
  String get welcomeToFlowShift;

  /// No description provided for @personalizeExperienceWithVenues.
  ///
  /// In en, this message translates to:
  /// **'Let\'s personalize your experience by finding popular event venues in your area.'**
  String get personalizeExperienceWithVenues;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @whereAreYouLocated.
  ///
  /// In en, this message translates to:
  /// **'Where are you\nlocated?'**
  String get whereAreYouLocated;

  /// No description provided for @addCitiesWhereYouOperate.
  ///
  /// In en, this message translates to:
  /// **'Add one or more cities where you operate. You can discover venues for each city later.'**
  String get addCitiesWhereYouOperate;

  /// No description provided for @settingUpYourCity.
  ///
  /// In en, this message translates to:
  /// **'Setting up your city...'**
  String get settingUpYourCity;

  /// No description provided for @settingUpYourCities.
  ///
  /// In en, this message translates to:
  /// **'Setting up your {cityCount} cities...'**
  String settingUpYourCities(int cityCount);

  /// No description provided for @thisWillOnlyTakeAMoment.
  ///
  /// In en, this message translates to:
  /// **'This will only take a moment...'**
  String get thisWillOnlyTakeAMoment;

  /// No description provided for @allSet.
  ///
  /// In en, this message translates to:
  /// **'All Set!'**
  String get allSet;

  /// No description provided for @yourCityConfiguredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your city has been configured successfully!'**
  String get yourCityConfiguredSuccessfully;

  /// No description provided for @yourCitiesConfiguredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your {count} cities have been configured successfully!'**
  String yourCitiesConfiguredSuccessfully(int count);

  /// No description provided for @discoverVenuesFromSettings.
  ///
  /// In en, this message translates to:
  /// **'You can discover venues for each city from Settings > Manage Cities.'**
  String get discoverVenuesFromSettings;

  /// No description provided for @startUsingFlowShift.
  ///
  /// In en, this message translates to:
  /// **'Start Using FlowShift'**
  String get startUsingFlowShift;

  /// No description provided for @couldNotDetectLocationEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Could not detect your location. Please enter your city manually.'**
  String get couldNotDetectLocationEnterManually;

  /// No description provided for @locationDetectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Location detection failed. Please enter your city manually.'**
  String get locationDetectionFailed;

  /// No description provided for @pleaseAddAtLeastOneCity.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one city'**
  String get pleaseAddAtLeastOneCity;

  /// No description provided for @anErrorOccurredTryAgain.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get anErrorOccurredTryAgain;

  /// No description provided for @letsGetYouSetUp.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get you set up'**
  String get letsGetYouSetUp;

  /// No description provided for @stepsComplete.
  ///
  /// In en, this message translates to:
  /// **'{completedCount} of {totalSteps} steps complete'**
  String stepsComplete(int completedCount, int totalSteps);

  /// No description provided for @finishStepsToActivateWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Finish these steps to activate your FlowShift workspace:'**
  String get finishStepsToActivateWorkspace;

  /// No description provided for @statusChipProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get statusChipProfile;

  /// No description provided for @statusChipTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get statusChipTeam;

  /// No description provided for @statusChipClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get statusChipClient;

  /// No description provided for @statusChipRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get statusChipRole;

  /// No description provided for @statusChipTariff.
  ///
  /// In en, this message translates to:
  /// **'Tariff'**
  String get statusChipTariff;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up: {step}'**
  String nextUp(String step);

  /// No description provided for @completeAllStepsForDashboard.
  ///
  /// In en, this message translates to:
  /// **'Complete all steps above to access the full dashboard.'**
  String get completeAllStepsForDashboard;

  /// No description provided for @addFirstLastNameForStaff.
  ///
  /// In en, this message translates to:
  /// **'Add your first and last name so staff know who you are.'**
  String get addFirstLastNameForStaff;

  /// No description provided for @reviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Review profile'**
  String get reviewProfile;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update profile'**
  String get updateProfile;

  /// No description provided for @updateYourProfile.
  ///
  /// In en, this message translates to:
  /// **'1. Update your profile'**
  String get updateYourProfile;

  /// No description provided for @profileDetailsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile details updated.'**
  String get profileDetailsUpdated;

  /// No description provided for @createYourTeamCompany.
  ///
  /// In en, this message translates to:
  /// **'2. Create your team/company'**
  String get createYourTeamCompany;

  /// No description provided for @setupStaffingCompanyExample.
  ///
  /// In en, this message translates to:
  /// **'Set up your staffing company (e.g., \"MES - Minneapolis Event Staffing\")'**
  String get setupStaffingCompanyExample;

  /// No description provided for @teamCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Team/Company name'**
  String get teamCompanyName;

  /// No description provided for @exampleTeamName.
  ///
  /// In en, this message translates to:
  /// **'e.g. MES - Minneapolis Event Staffing'**
  String get exampleTeamName;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @briefDescriptionStaffingCompany.
  ///
  /// In en, this message translates to:
  /// **'Brief description of your staffing company'**
  String get briefDescriptionStaffingCompany;

  /// No description provided for @completeProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile first'**
  String get completeProfileFirst;

  /// No description provided for @createTeam.
  ///
  /// In en, this message translates to:
  /// **'Create team'**
  String get createTeam;

  /// No description provided for @addAnotherTeam.
  ///
  /// In en, this message translates to:
  /// **'Add another team'**
  String get addAnotherTeam;

  /// No description provided for @createYourFirstClient.
  ///
  /// In en, this message translates to:
  /// **'3. Create your first client'**
  String get createYourFirstClient;

  /// No description provided for @needAtLeastOneClient.
  ///
  /// In en, this message translates to:
  /// **'You need at least one client before you can staff events.'**
  String get needAtLeastOneClient;

  /// No description provided for @exampleClientName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bluebird Catering'**
  String get exampleClientName;

  /// No description provided for @completeProfileAndTeamFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete profile and team first'**
  String get completeProfileAndTeamFirst;

  /// No description provided for @createClient.
  ///
  /// In en, this message translates to:
  /// **'Create client'**
  String get createClient;

  /// No description provided for @addAnotherClient.
  ///
  /// In en, this message translates to:
  /// **'Add another client'**
  String get addAnotherClient;

  /// No description provided for @addAtLeastOneRole.
  ///
  /// In en, this message translates to:
  /// **'4. Add at least one role'**
  String get addAtLeastOneRole;

  /// No description provided for @rolesHelpMatchStaff.
  ///
  /// In en, this message translates to:
  /// **'Roles help match staff to the right job (waiter, chef, bartender...).'**
  String get rolesHelpMatchStaff;

  /// No description provided for @roleName.
  ///
  /// In en, this message translates to:
  /// **'Role name'**
  String get roleName;

  /// No description provided for @exampleRoleName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Lead Server'**
  String get exampleRoleName;

  /// No description provided for @finishPreviousStepsFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish previous steps first'**
  String get finishPreviousStepsFirst;

  /// No description provided for @createRole.
  ///
  /// In en, this message translates to:
  /// **'Create role'**
  String get createRole;

  /// No description provided for @addAnotherRole.
  ///
  /// In en, this message translates to:
  /// **'Add another role'**
  String get addAnotherRole;

  /// No description provided for @setYourFirstTariff.
  ///
  /// In en, this message translates to:
  /// **'5. Set your first tariff'**
  String get setYourFirstTariff;

  /// No description provided for @setRateForBilling.
  ///
  /// In en, this message translates to:
  /// **'Set a rate so staffing assignments know what to bill.'**
  String get setRateForBilling;

  /// No description provided for @createClientFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a client first'**
  String get createClientFirst;

  /// No description provided for @createRoleFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a role first'**
  String get createRoleFirst;

  /// No description provided for @hourlyRateUsd.
  ///
  /// In en, this message translates to:
  /// **'Hourly rate (USD)'**
  String get hourlyRateUsd;

  /// No description provided for @exampleHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'e.g. 24.00'**
  String get exampleHourlyRate;

  /// No description provided for @adjustTariffsInCatalog.
  ///
  /// In en, this message translates to:
  /// **'You can adjust this later in Catalog > Tariffs'**
  String get adjustTariffsInCatalog;

  /// No description provided for @saveTariff.
  ///
  /// In en, this message translates to:
  /// **'Save tariff'**
  String get saveTariff;

  /// No description provided for @addAnotherTariff.
  ///
  /// In en, this message translates to:
  /// **'Add another tariff'**
  String get addAnotherTariff;

  /// No description provided for @enterTeamNameToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter a team/company name to continue'**
  String get enterTeamNameToContinue;

  /// No description provided for @teamCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Team created successfully!'**
  String get teamCreatedSuccessfully;

  /// No description provided for @failedToCreateTeam.
  ///
  /// In en, this message translates to:
  /// **'Failed to create team'**
  String get failedToCreateTeam;

  /// No description provided for @enterClientNameToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter a client name to continue'**
  String get enterClientNameToContinue;

  /// No description provided for @clientCreated.
  ///
  /// In en, this message translates to:
  /// **'Client created'**
  String get clientCreated;

  /// No description provided for @failedToCreateClient.
  ///
  /// In en, this message translates to:
  /// **'Failed to create client'**
  String get failedToCreateClient;

  /// No description provided for @enterRoleNameToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter a role name to continue'**
  String get enterRoleNameToContinue;

  /// No description provided for @roleCreated.
  ///
  /// In en, this message translates to:
  /// **'Role created'**
  String get roleCreated;

  /// No description provided for @failedToCreateRole.
  ///
  /// In en, this message translates to:
  /// **'Failed to create role'**
  String get failedToCreateRole;

  /// No description provided for @createClientAndRoleBeforeTariff.
  ///
  /// In en, this message translates to:
  /// **'Create a client and a role before adding a tariff'**
  String get createClientAndRoleBeforeTariff;

  /// No description provided for @selectClientAndRole.
  ///
  /// In en, this message translates to:
  /// **'Select a client and a role'**
  String get selectClientAndRole;

  /// No description provided for @enterValidHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid hourly rate (e.g. 22.50)'**
  String get enterValidHourlyRate;

  /// No description provided for @tariffSaved.
  ///
  /// In en, this message translates to:
  /// **'Tariff saved'**
  String get tariffSaved;

  /// No description provided for @failedToSaveTariff.
  ///
  /// In en, this message translates to:
  /// **'Failed to save tariff'**
  String get failedToSaveTariff;

  /// No description provided for @failedToOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to open profile'**
  String get failedToOpenProfile;

  /// No description provided for @navAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get navAttendance;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @manageYourEvents.
  ///
  /// In en, this message translates to:
  /// **'Manage your events'**
  String get manageYourEvents;

  /// No description provided for @featureChatDesc.
  ///
  /// In en, this message translates to:
  /// **'send jobs through the chat'**
  String get featureChatDesc;

  /// No description provided for @featureAIChatDesc.
  ///
  /// In en, this message translates to:
  /// **'create, update, ask questions'**
  String get featureAIChatDesc;

  /// No description provided for @featureJobsDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your created cards'**
  String get featureJobsDesc;

  /// No description provided for @featureTeamsDesc.
  ///
  /// In en, this message translates to:
  /// **'invite people to Join'**
  String get featureTeamsDesc;

  /// No description provided for @featureHoursDesc.
  ///
  /// In en, this message translates to:
  /// **'Track team work hours'**
  String get featureHoursDesc;

  /// No description provided for @featureCatalogDesc.
  ///
  /// In en, this message translates to:
  /// **'create clients, roles, and tariffs'**
  String get featureCatalogDesc;

  /// No description provided for @quickActionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get quickActionUpload;

  /// No description provided for @quickActionTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Timesheet'**
  String get quickActionTimesheet;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogoutMessage;

  /// No description provided for @attendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendanceTitle;

  /// No description provided for @forceClockOut.
  ///
  /// In en, this message translates to:
  /// **'Force Clock-Out'**
  String get forceClockOut;

  /// No description provided for @confirmClockOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clock out {staffName}?'**
  String confirmClockOutMessage(String staffName);

  /// No description provided for @clockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get clockOut;

  /// No description provided for @staffClockedOutSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{staffName} clocked out successfully'**
  String staffClockedOutSuccessfully(String staffName);

  /// No description provided for @failedToClockOutStaff.
  ///
  /// In en, this message translates to:
  /// **'Failed to clock out staff'**
  String get failedToClockOutStaff;

  /// No description provided for @viewingHistoryFor.
  ///
  /// In en, this message translates to:
  /// **'Viewing history for {staffName}'**
  String viewingHistoryFor(String staffName);

  /// No description provided for @viewingDetailsFor.
  ///
  /// In en, this message translates to:
  /// **'Viewing details for {staffName}'**
  String viewingDetailsFor(String staffName);

  /// No description provided for @noAttendanceRecords.
  ///
  /// In en, this message translates to:
  /// **'No attendance records'**
  String get noAttendanceRecords;

  /// No description provided for @tryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get tryAdjustingFilters;

  /// No description provided for @recordsAppearWhenStaffClockIn.
  ///
  /// In en, this message translates to:
  /// **'Records will appear here when staff clock in'**
  String get recordsAppearWhenStaffClockIn;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @aiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get aiAnalysis;

  /// No description provided for @failedToLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failedToLoadData;

  /// No description provided for @bulkClockIn.
  ///
  /// In en, this message translates to:
  /// **'Bulk Clock-In'**
  String get bulkClockIn;

  /// No description provided for @pleaseSelectAtLeastOneStaff.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one staff member'**
  String get pleaseSelectAtLeastOneStaff;

  /// No description provided for @successfullyClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Successfully clocked in {successful} of {total} staff'**
  String successfullyClockedIn(int successful, int total);

  /// No description provided for @failedBulkClockIn.
  ///
  /// In en, this message translates to:
  /// **'Failed to perform bulk clock-in'**
  String get failedBulkClockIn;

  /// No description provided for @noAcceptedStaffForEvent.
  ///
  /// In en, this message translates to:
  /// **'No accepted staff for this event'**
  String get noAcceptedStaffForEvent;

  /// No description provided for @overrideNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Override Note (optional)'**
  String get overrideNoteOptional;

  /// No description provided for @groupCheckInHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Group check-in at entrance'**
  String get groupCheckInHint;

  /// No description provided for @clockInStaffCount.
  ///
  /// In en, this message translates to:
  /// **'Clock In {count} Staff'**
  String clockInStaffCount(int count);

  /// No description provided for @bulkClockInResults.
  ///
  /// In en, this message translates to:
  /// **'Bulk Clock-In Results'**
  String get bulkClockInResults;

  /// No description provided for @alreadyClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Already clocked in'**
  String get alreadyClockedIn;

  /// No description provided for @flaggedAttendance.
  ///
  /// In en, this message translates to:
  /// **'Flagged Attendance'**
  String get flaggedAttendance;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @dismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get dismissed;

  /// No description provided for @noPendingFlags.
  ///
  /// In en, this message translates to:
  /// **'No pending flags!'**
  String get noPendingFlags;

  /// No description provided for @noFlaggedEntriesFound.
  ///
  /// In en, this message translates to:
  /// **'No flagged entries found'**
  String get noFlaggedEntriesFound;

  /// No description provided for @allEntriesLookNormal.
  ///
  /// In en, this message translates to:
  /// **'All attendance entries look normal'**
  String get allEntriesLookNormal;

  /// No description provided for @reviewFlag.
  ///
  /// In en, this message translates to:
  /// **'Review Flag'**
  String get reviewFlag;

  /// No description provided for @reviewNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Review Notes (optional)'**
  String get reviewNotesOptional;

  /// No description provided for @addNotesAboutReview.
  ///
  /// In en, this message translates to:
  /// **'Add any notes about this review...'**
  String get addNotesAboutReview;

  /// No description provided for @unknownStaff.
  ///
  /// In en, this message translates to:
  /// **'Unknown Staff'**
  String get unknownStaff;

  /// No description provided for @unknownEvent.
  ///
  /// In en, this message translates to:
  /// **'Unknown Event'**
  String get unknownEvent;

  /// No description provided for @clockInTime.
  ///
  /// In en, this message translates to:
  /// **'Clock-In'**
  String get clockInTime;

  /// No description provided for @clockOutTime.
  ///
  /// In en, this message translates to:
  /// **'Clock-Out'**
  String get clockOutTime;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @expectedDuration.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expectedDuration;

  /// No description provided for @unusualHours.
  ///
  /// In en, this message translates to:
  /// **'Unusual Hours'**
  String get unusualHours;

  /// No description provided for @excessiveDuration.
  ///
  /// In en, this message translates to:
  /// **'Excessive Duration'**
  String get excessiveDuration;

  /// No description provided for @lateClockOut.
  ///
  /// In en, this message translates to:
  /// **'Late Clock-Out'**
  String get lateClockOut;

  /// No description provided for @locationMismatch.
  ///
  /// In en, this message translates to:
  /// **'Location Mismatch'**
  String get locationMismatch;

  /// No description provided for @filterAttendance.
  ///
  /// In en, this message translates to:
  /// **'Filter Attendance'**
  String get filterAttendance;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get last7Days;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get allEvents;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get working;

  /// No description provided for @flags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get flags;

  /// No description provided for @currentlyWorking.
  ///
  /// In en, this message translates to:
  /// **'Currently Working'**
  String get currentlyWorking;

  /// No description provided for @noStaffWorking.
  ///
  /// In en, this message translates to:
  /// **'No staff working'**
  String get noStaffWorking;

  /// No description provided for @staffAppearsWhenClockIn.
  ///
  /// In en, this message translates to:
  /// **'Staff will appear here when they clock in'**
  String get staffAppearsWhenClockIn;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @onSite.
  ///
  /// In en, this message translates to:
  /// **'On-site'**
  String get onSite;

  /// No description provided for @autoClockOut.
  ///
  /// In en, this message translates to:
  /// **'Auto clocked-out'**
  String get autoClockOut;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get calendarTomorrow;

  /// No description provided for @calendarViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// No description provided for @calendarViewTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'2 Wks'**
  String get calendarViewTwoWeeks;

  /// No description provided for @calendarViewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get calendarViewAgenda;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// No description provided for @scheduleIsClear.
  ///
  /// In en, this message translates to:
  /// **'Your schedule is clear going forward'**
  String get scheduleIsClear;

  /// No description provided for @hidePastEvents.
  ///
  /// In en, this message translates to:
  /// **'Hide past events'**
  String get hidePastEvents;

  /// No description provided for @showPastDaysWithEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 past day with events} other{Show {count} past days with events}}'**
  String showPastDaysWithEvents(int count);

  /// No description provided for @noEventsThisDay.
  ///
  /// In en, this message translates to:
  /// **'No events this day'**
  String get noEventsThisDay;

  /// No description provided for @freeDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Free day'**
  String get freeDayLabel;

  /// No description provided for @nothingWasScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing was scheduled'**
  String get nothingWasScheduled;

  /// No description provided for @nothingScheduledYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled yet'**
  String get nothingScheduledYet;

  /// No description provided for @couldNotLoadEvents.
  ///
  /// In en, this message translates to:
  /// **'Could not load events'**
  String get couldNotLoadEvents;

  /// No description provided for @noFullTerminology.
  ///
  /// In en, this message translates to:
  /// **'No full {terminology} yet'**
  String noFullTerminology(String terminology);

  /// No description provided for @whenPositionsFilled.
  ///
  /// In en, this message translates to:
  /// **'When all positions are filled, they\'ll appear here'**
  String get whenPositionsFilled;

  /// No description provided for @expiredUnfulfilledEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expired unfulfilled event} other{{count} expired unfulfilled events}}'**
  String expiredUnfulfilledEvents(int count);

  /// No description provided for @pastEventsNeverFullyStaffed.
  ///
  /// In en, this message translates to:
  /// **'Past events that were never fully staffed'**
  String get pastEventsNeverFullyStaffed;

  /// No description provided for @expiredUnfulfilledTitle.
  ///
  /// In en, this message translates to:
  /// **'Expired Unfulfilled ({count})'**
  String expiredUnfulfilledTitle(int count);

  /// No description provided for @noCompletedTerminology.
  ///
  /// In en, this message translates to:
  /// **'No completed {terminology} yet'**
  String noCompletedTerminology(String terminology);

  /// No description provided for @completedTerminologyAppear.
  ///
  /// In en, this message translates to:
  /// **'Completed {terminology} will show up here'**
  String completedTerminologyAppear(String terminology);

  /// No description provided for @noPendingTerminology.
  ///
  /// In en, this message translates to:
  /// **'No pending {terminology}'**
  String noPendingTerminology(String terminology);

  /// No description provided for @draftTerminologyWaiting.
  ///
  /// In en, this message translates to:
  /// **'Draft {terminology} waiting to be posted will appear here'**
  String draftTerminologyWaiting(String terminology);

  /// No description provided for @noPostedTerminology.
  ///
  /// In en, this message translates to:
  /// **'No posted {terminology}'**
  String noPostedTerminology(String terminology);

  /// No description provided for @postedTerminologyWaiting.
  ///
  /// In en, this message translates to:
  /// **'Posted {terminology} waiting for staff will appear here'**
  String postedTerminologyWaiting(String terminology);

  /// No description provided for @flagged.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get flagged;

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get noShow;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get clockIn;

  /// No description provided for @verifiedOnSite.
  ///
  /// In en, this message translates to:
  /// **'Verified on-site'**
  String get verifiedOnSite;

  /// No description provided for @weeklyHours.
  ///
  /// In en, this message translates to:
  /// **'Weekly Hours'**
  String get weeklyHours;

  /// No description provided for @noDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noDataForPeriod;

  /// No description provided for @failedToLoadFlaggedAttendance.
  ///
  /// In en, this message translates to:
  /// **'Failed to load flagged attendance'**
  String get failedToLoadFlaggedAttendance;

  /// No description provided for @failedToUpdateFlag.
  ///
  /// In en, this message translates to:
  /// **'Failed to update flag'**
  String get failedToUpdateFlag;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @failedToLoadStatistics.
  ///
  /// In en, this message translates to:
  /// **'Failed to load statistics'**
  String get failedToLoadStatistics;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @downloadReport.
  ///
  /// In en, this message translates to:
  /// **'Download report'**
  String get downloadReport;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @downloadWord.
  ///
  /// In en, this message translates to:
  /// **'Download Word'**
  String get downloadWord;

  /// No description provided for @analyzingYourData.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your data...'**
  String get analyzingYourData;

  /// No description provided for @failedToGenerate.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate'**
  String get failedToGenerate;

  /// No description provided for @payrollSummary.
  ///
  /// In en, this message translates to:
  /// **'Payroll Summary'**
  String get payrollSummary;

  /// No description provided for @staffMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} staff members'**
  String staffMembersCount(int count);

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @totalHours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get totalHours;

  /// No description provided for @totalPayroll.
  ///
  /// In en, this message translates to:
  /// **'Total Payroll'**
  String get totalPayroll;

  /// No description provided for @averagePerStaff.
  ///
  /// In en, this message translates to:
  /// **'Avg/Staff'**
  String get averagePerStaff;

  /// No description provided for @topEarners.
  ///
  /// In en, this message translates to:
  /// **'Top Earners'**
  String get topEarners;

  /// No description provided for @noPayrollDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No payroll data for this period'**
  String get noPayrollDataForPeriod;

  /// No description provided for @shiftsAndHours.
  ///
  /// In en, this message translates to:
  /// **'{shifts} shifts • {hours}h'**
  String shiftsAndHours(int shifts, String hours);

  /// No description provided for @topPerformers.
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get topPerformers;

  /// No description provided for @basedOnShiftsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Based on shifts completed'**
  String get basedOnShiftsCompleted;

  /// No description provided for @approveHours.
  ///
  /// In en, this message translates to:
  /// **'Approve Hours'**
  String get approveHours;

  /// No description provided for @uploadSignInSheet.
  ///
  /// In en, this message translates to:
  /// **'Upload Sign-In Sheet'**
  String get uploadSignInSheet;

  /// No description provided for @takePhotoOrUploadSheet.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or upload the client\'s sign-in/out sheet'**
  String get takePhotoOrUploadSheet;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @analyzeWithAi.
  ///
  /// In en, this message translates to:
  /// **'Analyze with AI'**
  String get analyzeWithAi;

  /// No description provided for @analyzingSignInSheetWithAi.
  ///
  /// In en, this message translates to:
  /// **'Analyzing sign-in sheet with AI...'**
  String get analyzingSignInSheetWithAi;

  /// No description provided for @extractedStaffHours.
  ///
  /// In en, this message translates to:
  /// **'Extracted Staff Hours'**
  String get extractedStaffHours;

  /// No description provided for @reviewAndEditBeforeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Review and edit before submitting'**
  String get reviewAndEditBeforeSubmitting;

  /// No description provided for @signInLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInLabel;

  /// No description provided for @signOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutLabel;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @hoursCount.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String hoursCount(String hours);

  /// No description provided for @bulkApprove.
  ///
  /// In en, this message translates to:
  /// **'Bulk Approve'**
  String get bulkApprove;

  /// No description provided for @approveHoursForAllStaff.
  ///
  /// In en, this message translates to:
  /// **'Approve hours for all {count} staff members?'**
  String approveHoursForAllStaff(int count);

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve All'**
  String get approveAll;

  /// No description provided for @nameMatchingResults.
  ///
  /// In en, this message translates to:
  /// **'Name Matching Results'**
  String get nameMatchingResults;

  /// No description provided for @staffMembersMatched.
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} staff members matched'**
  String staffMembersMatched(int processed, int total);

  /// No description provided for @editHoursFor.
  ///
  /// In en, this message translates to:
  /// **'Edit Hours - {name}'**
  String editHoursFor(String name);

  /// No description provided for @signInTime.
  ///
  /// In en, this message translates to:
  /// **'Sign In Time'**
  String get signInTime;

  /// No description provided for @signOutTime.
  ///
  /// In en, this message translates to:
  /// **'Sign Out Time'**
  String get signOutTime;

  /// No description provided for @approvedHours.
  ///
  /// In en, this message translates to:
  /// **'Approved Hours'**
  String get approvedHours;

  /// No description provided for @optionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Optional notes'**
  String get optionalNotes;

  /// No description provided for @noHoursMatched.
  ///
  /// In en, this message translates to:
  /// **'No hours were matched. Please check the names on the sheet.'**
  String get noHoursMatched;

  /// No description provided for @noHoursApproved.
  ///
  /// In en, this message translates to:
  /// **'No hours were approved. Check match results above.'**
  String get noHoursApproved;

  /// No description provided for @failedToBulkApprove.
  ///
  /// In en, this message translates to:
  /// **'Failed to bulk approve'**
  String get failedToBulkApprove;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get analysisFailed;

  /// No description provided for @failedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image'**
  String get failedToPickImage;

  /// No description provided for @failedToLoadEvents.
  ///
  /// In en, this message translates to:
  /// **'Failed to load events'**
  String get failedToLoadEvents;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All Caught Up!'**
  String get allCaughtUp;

  /// No description provided for @noEventsNeedApproval.
  ///
  /// In en, this message translates to:
  /// **'No events need hours approval at the moment.'**
  String get noEventsNeedApproval;

  /// No description provided for @pendingReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Pending Review'**
  String pendingReviewCount(int count);

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @dateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Date unknown'**
  String get dateUnknown;

  /// No description provided for @manualHoursEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Hours Entry'**
  String get manualHoursEntry;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @searchStaffByNameEmail.
  ///
  /// In en, this message translates to:
  /// **'Search staff by name or email'**
  String get searchStaffByNameEmail;

  /// No description provided for @failedToLoadUsers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load users'**
  String get failedToLoadUsers;

  /// No description provided for @failedToSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Failed to search users'**
  String get failedToSearchUsers;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @submitHoursCount.
  ///
  /// In en, this message translates to:
  /// **'Submit Hours ({count})'**
  String submitHoursCount(int count);

  /// No description provided for @hoursForStaff.
  ///
  /// In en, this message translates to:
  /// **'Hours for {name}'**
  String hoursForStaff(String name);

  /// No description provided for @signInTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-In Time *'**
  String get signInTimeRequired;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @signOutTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-Out Time *'**
  String get signOutTimeRequired;

  /// No description provided for @totalHoursFormat.
  ///
  /// In en, this message translates to:
  /// **'Total: {hours} hours'**
  String totalHoursFormat(String hours);

  /// No description provided for @hoursSubmittedApprovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Hours submitted and approved successfully'**
  String get hoursSubmittedApprovedSuccess;

  /// No description provided for @failedToSubmitHours.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit hours'**
  String get failedToSubmitHours;

  /// No description provided for @pleaseEnterSignInSignOut.
  ///
  /// In en, this message translates to:
  /// **'Please enter sign-in and sign-out times for all selected staff'**
  String get pleaseEnterSignInSignOut;

  /// No description provided for @createTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get createTeamTitle;

  /// No description provided for @teamNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Team name'**
  String get teamNameLabel;

  /// No description provided for @enterTeamNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter a team name'**
  String get enterTeamNameError;

  /// No description provided for @deleteTeamConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete team?'**
  String get deleteTeamConfirmation;

  /// No description provided for @deleteTeamWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting this team will remove it permanently. Events that reference it will block deletion.'**
  String get deleteTeamWarning;

  /// No description provided for @teamDeleted.
  ///
  /// In en, this message translates to:
  /// **'Team deleted'**
  String get teamDeleted;

  /// No description provided for @failedToDeleteTeam.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete team'**
  String get failedToDeleteTeam;

  /// No description provided for @noTeamsYet.
  ///
  /// In en, this message translates to:
  /// **'No teams yet. Tap \"New team\" to create one.'**
  String get noTeamsYet;

  /// No description provided for @untitledTeam.
  ///
  /// In en, this message translates to:
  /// **'Untitled team'**
  String get untitledTeam;

  /// No description provided for @coManager.
  ///
  /// In en, this message translates to:
  /// **'Co-Manager'**
  String get coManager;

  /// No description provided for @inviteByEmail.
  ///
  /// In en, this message translates to:
  /// **'Invite by email'**
  String get inviteByEmail;

  /// No description provided for @messageOptional.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get messageOptional;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite;

  /// No description provided for @failedToSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invite'**
  String get failedToSendInvite;

  /// No description provided for @inviteSentTo.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {email}'**
  String inviteSentTo(String email);

  /// No description provided for @revokeInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Revoke Invite Link'**
  String get revokeInviteLink;

  /// No description provided for @revokeInviteLinkConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This will prevent anyone from using this link to join. Continue?'**
  String get revokeInviteLinkConfirmation;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @inviteLinkRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite link revoked'**
  String get inviteLinkRevoked;

  /// No description provided for @usageLog.
  ///
  /// In en, this message translates to:
  /// **'Usage Log'**
  String get usageLog;

  /// No description provided for @noUsageRecorded.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded yet.'**
  String get noUsageRecorded;

  /// No description provided for @errorLoadingUsage.
  ///
  /// In en, this message translates to:
  /// **'Error loading usage'**
  String get errorLoadingUsage;

  /// No description provided for @publicLinkCreated.
  ///
  /// In en, this message translates to:
  /// **'Public Link Created!'**
  String get publicLinkCreated;

  /// No description provided for @publicLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'Share this link on social media to recruit new team members. All applicants will require your approval.'**
  String get publicLinkDescription;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get linkCopied;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code:'**
  String get codeLabel;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get codeCopied;

  /// No description provided for @shareJoinTeam.
  ///
  /// In en, this message translates to:
  /// **'Join our team on FlowShift'**
  String get shareJoinTeam;

  /// No description provided for @addCoManager.
  ///
  /// In en, this message translates to:
  /// **'Add Co-Manager'**
  String get addCoManager;

  /// No description provided for @addCoManagerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the email of a manager to add them as a co-manager. They must already have a FlowShift Manager account.'**
  String get addCoManagerInstructions;

  /// No description provided for @managerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager email'**
  String get managerEmailLabel;

  /// No description provided for @enterEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get enterEmailError;

  /// No description provided for @enterValidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmailError;

  /// No description provided for @coManagerAdded.
  ///
  /// In en, this message translates to:
  /// **'Co-manager added'**
  String get coManagerAdded;

  /// No description provided for @removeCoManager.
  ///
  /// In en, this message translates to:
  /// **'Remove co-manager'**
  String get removeCoManager;

  /// No description provided for @removeCoManagerConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} as co-manager?'**
  String removeCoManagerConfirmation(String name);

  /// No description provided for @coManagerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Co-manager removed'**
  String get coManagerRemoved;

  /// No description provided for @userMissingProviderError.
  ///
  /// In en, this message translates to:
  /// **'User is missing provider/subject information'**
  String get userMissingProviderError;

  /// No description provided for @addTeamMember.
  ///
  /// In en, this message translates to:
  /// **'Add team member'**
  String get addTeamMember;

  /// No description provided for @searchByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email'**
  String get searchByNameOrEmail;

  /// No description provided for @noUsersFoundTryAnother.
  ///
  /// In en, this message translates to:
  /// **'No users found. Try another search.'**
  String get noUsersFoundTryAnother;

  /// No description provided for @memberChip.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberChip;

  /// No description provided for @addedToTeam.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to the team'**
  String addedToTeam(String name);

  /// No description provided for @failedToAddMember.
  ///
  /// In en, this message translates to:
  /// **'Failed to add member'**
  String get failedToAddMember;

  /// No description provided for @inviteCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invite cancelled'**
  String get inviteCancelled;

  /// No description provided for @failedToCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel invite'**
  String get failedToCancelInvite;

  /// No description provided for @failedToLoadTeamData.
  ///
  /// In en, this message translates to:
  /// **'Could not load team data'**
  String get failedToLoadTeamData;

  /// No description provided for @membersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersSection;

  /// No description provided for @noActiveMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No active members yet.'**
  String get noActiveMembersYet;

  /// No description provided for @pendingMember.
  ///
  /// In en, this message translates to:
  /// **'Pending member'**
  String get pendingMember;

  /// No description provided for @coManagersSection.
  ///
  /// In en, this message translates to:
  /// **'Co-Managers'**
  String get coManagersSection;

  /// No description provided for @noCoManagersYet.
  ///
  /// In en, this message translates to:
  /// **'No co-managers yet.'**
  String get noCoManagersYet;

  /// No description provided for @removeCoManagerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove co-manager'**
  String get removeCoManagerTooltip;

  /// No description provided for @invitesSection.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invitesSection;

  /// No description provided for @inviteLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Invite Link'**
  String get inviteLinkButton;

  /// No description provided for @publicLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Public Link'**
  String get publicLinkButton;

  /// No description provided for @emailInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailInviteButton;

  /// No description provided for @noInvitesYet.
  ///
  /// In en, this message translates to:
  /// **'No invites yet.'**
  String get noInvitesYet;

  /// No description provided for @pendingApplicants.
  ///
  /// In en, this message translates to:
  /// **'Pending Applicants'**
  String get pendingApplicants;

  /// No description provided for @activeInviteLinks.
  ///
  /// In en, this message translates to:
  /// **'Active Invite Links'**
  String get activeInviteLinks;

  /// No description provided for @publicBadge.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC'**
  String get publicBadge;

  /// No description provided for @usedLabel.
  ///
  /// In en, this message translates to:
  /// **'Used:'**
  String get usedLabel;

  /// No description provided for @unlimitedUses.
  ///
  /// In en, this message translates to:
  /// **'(unlimited)'**
  String get unlimitedUses;

  /// No description provided for @joinsLabel.
  ///
  /// In en, this message translates to:
  /// **'joins'**
  String get joinsLabel;

  /// No description provided for @denyApplicant.
  ///
  /// In en, this message translates to:
  /// **'Deny Applicant'**
  String get denyApplicant;

  /// No description provided for @denyApplicantConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deny this applicant?'**
  String get denyApplicantConfirmation;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @applicantApproved.
  ///
  /// In en, this message translates to:
  /// **'Applicant approved!'**
  String get applicantApproved;

  /// No description provided for @applicantDenied.
  ///
  /// In en, this message translates to:
  /// **'Applicant denied'**
  String get applicantDenied;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatTitle;

  /// No description provided for @searchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get searchConversations;

  /// No description provided for @failedToLoadConversations.
  ///
  /// In en, this message translates to:
  /// **'Failed to load conversations'**
  String get failedToLoadConversations;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @startChattingWithTeam.
  ///
  /// In en, this message translates to:
  /// **'Start chatting with your team to see your messages here'**
  String get startChattingWithTeam;

  /// No description provided for @managerBadge.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get managerBadge;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @addMembersToStartChatting.
  ///
  /// In en, this message translates to:
  /// **'Add members to your team to start chatting'**
  String get addMembersToStartChatting;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts...'**
  String get searchContacts;

  /// No description provided for @failedToLoadContacts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contacts'**
  String get failedToLoadContacts;

  /// No description provided for @noContactsMatch.
  ///
  /// In en, this message translates to:
  /// **'No contacts match your search'**
  String get noContactsMatch;

  /// No description provided for @noTeamMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No team members yet'**
  String get noTeamMembersYet;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @valerioAssistant.
  ///
  /// In en, this message translates to:
  /// **'Valerio Assistant'**
  String get valerioAssistant;

  /// No description provided for @valerioAssistantDesc.
  ///
  /// In en, this message translates to:
  /// **'Create events, manage jobs, and get instant help'**
  String get valerioAssistantDesc;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get typing;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get failedToSendMessage;

  /// No description provided for @sendMessageToStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Send a message to start the conversation'**
  String get sendMessageToStartConversation;

  /// No description provided for @failedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get failedToLoadMessages;

  /// No description provided for @staffAcceptedInvitation.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted the invitation!'**
  String staffAcceptedInvitation(String name);

  /// No description provided for @staffDeclinedInvitation.
  ///
  /// In en, this message translates to:
  /// **'{name} declined the invitation'**
  String staffDeclinedInvitation(String name);

  /// No description provided for @failedToSendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invitation'**
  String get failedToSendInvitation;

  /// No description provided for @noUpcomingJobs.
  ///
  /// In en, this message translates to:
  /// **'No upcoming jobs'**
  String get noUpcomingJobs;

  /// No description provided for @noJobsMatch.
  ///
  /// In en, this message translates to:
  /// **'No jobs match your search'**
  String get noJobsMatch;

  /// No description provided for @unknownClient.
  ///
  /// In en, this message translates to:
  /// **'Unknown Client'**
  String get unknownClient;

  /// No description provided for @noVenueSpecified.
  ///
  /// In en, this message translates to:
  /// **'No venue specified'**
  String get noVenueSpecified;

  /// No description provided for @noDateSpecified.
  ///
  /// In en, this message translates to:
  /// **'No date specified'**
  String get noDateSpecified;

  /// No description provided for @selectRoleForStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Select a role for the staff member:'**
  String get selectRoleForStaffMember;

  /// No description provided for @noRolesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No roles available for this job'**
  String get noRolesAvailable;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @sendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get sendInvitation;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @waitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response...'**
  String get waitingForResponse;

  /// No description provided for @callTime.
  ///
  /// In en, this message translates to:
  /// **'Call time: {time}'**
  String callTime(String time);

  /// No description provided for @acceptedStaffCount.
  ///
  /// In en, this message translates to:
  /// **'Accepted Staff ({count})'**
  String acceptedStaffCount(int count);

  /// No description provided for @workingHoursSheet.
  ///
  /// In en, this message translates to:
  /// **'Working Hours Sheet'**
  String get workingHoursSheet;

  /// No description provided for @hoursSheetPdf.
  ///
  /// In en, this message translates to:
  /// **'Hours Sheet (PDF)'**
  String get hoursSheetPdf;

  /// No description provided for @hoursSheetWord.
  ///
  /// In en, this message translates to:
  /// **'Hours Sheet (Word)'**
  String get hoursSheetWord;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @staffIdDisplay.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String staffIdDisplay(String id);

  /// No description provided for @removeStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Staff Member'**
  String get removeStaffMember;

  /// No description provided for @confirmRemoveStaff.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this staff member from the event?'**
  String get confirmRemoveStaff;

  /// No description provided for @staffRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Staff member removed successfully'**
  String get staffRemovedSuccess;

  /// No description provided for @failedToRemoveStaff.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove staff member'**
  String get failedToRemoveStaff;

  /// No description provided for @confirmClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in {staffName} for this event?'**
  String confirmClockIn(String staffName);

  /// No description provided for @alreadyClockedInName.
  ///
  /// In en, this message translates to:
  /// **'{staffName} is already clocked in'**
  String alreadyClockedInName(String staffName);

  /// No description provided for @clockedInSuccess.
  ///
  /// In en, this message translates to:
  /// **'{staffName} clocked in successfully'**
  String clockedInSuccess(String staffName);

  /// No description provided for @clockInFailed.
  ///
  /// In en, this message translates to:
  /// **'Clock-in failed. Please try again.'**
  String get clockInFailed;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @keepOpenAfterEvent.
  ///
  /// In en, this message translates to:
  /// **'Keep Open After Event'**
  String get keepOpenAfterEvent;

  /// No description provided for @preventAutoCompletion.
  ///
  /// In en, this message translates to:
  /// **'Prevent automatic completion when event date passes'**
  String get preventAutoCompletion;

  /// No description provided for @moveToDrafts.
  ///
  /// In en, this message translates to:
  /// **'Move to Drafts'**
  String get moveToDrafts;

  /// No description provided for @clockInStaff.
  ///
  /// In en, this message translates to:
  /// **'Clock In Staff'**
  String get clockInStaff;

  /// No description provided for @openToAllStaff.
  ///
  /// In en, this message translates to:
  /// **'Open to All Staff'**
  String get openToAllStaff;

  /// No description provided for @moveToDraftsWithStaff.
  ///
  /// In en, this message translates to:
  /// **'This will:\n• Remove all {count} accepted staff members\n• Send them a notification\n• Hide the job from staff view\n\nYou can republish it later.'**
  String moveToDraftsWithStaff(int count);

  /// No description provided for @moveToDraftsNoStaff.
  ///
  /// In en, this message translates to:
  /// **'This will hide the job from staff view. You can republish it later.'**
  String get moveToDraftsNoStaff;

  /// No description provided for @eventMovedToDrafts.
  ///
  /// In en, this message translates to:
  /// **'{name} moved to drafts!'**
  String eventMovedToDrafts(String name);

  /// No description provided for @failedToMoveToDrafts.
  ///
  /// In en, this message translates to:
  /// **'Failed to move to drafts'**
  String get failedToMoveToDrafts;

  /// No description provided for @eventStaysOpen.
  ///
  /// In en, this message translates to:
  /// **'Event will stay open after completion'**
  String get eventStaysOpen;

  /// No description provided for @eventAutoCompletes.
  ///
  /// In en, this message translates to:
  /// **'Event will auto-complete when past'**
  String get eventAutoCompletes;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update'**
  String get failedToUpdate;

  /// No description provided for @failedToGenerateSheet.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate sheet'**
  String get failedToGenerateSheet;

  /// No description provided for @confirmOpenToAll.
  ///
  /// In en, this message translates to:
  /// **'Make \"{name}\" visible to all staff members?\n\nThis will change the job from private (invited only) to public, allowing all team members to see and accept it.'**
  String confirmOpenToAll(String name);

  /// No description provided for @openToAll.
  ///
  /// In en, this message translates to:
  /// **'Open to All'**
  String get openToAll;

  /// No description provided for @eventNowOpenToAll.
  ///
  /// In en, this message translates to:
  /// **'{name} is now open to all staff!'**
  String eventNowOpenToAll(String name);

  /// No description provided for @failedToMakePublic.
  ///
  /// In en, this message translates to:
  /// **'Failed to make public'**
  String get failedToMakePublic;

  /// No description provided for @vacanciesLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get vacanciesLeft;

  /// No description provided for @manageYourPreferences.
  ///
  /// In en, this message translates to:
  /// **'Manage your preferences'**
  String get manageYourPreferences;

  /// No description provided for @workTerminology.
  ///
  /// In en, this message translates to:
  /// **'Work Terminology'**
  String get workTerminology;

  /// No description provided for @howPreferWorkAssignments.
  ///
  /// In en, this message translates to:
  /// **'How do you prefer to call your work assignments?'**
  String get howPreferWorkAssignments;

  /// No description provided for @jobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobs;

  /// No description provided for @jobsExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"My Jobs\", \"Create Job\"'**
  String get jobsExample;

  /// No description provided for @shifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shifts;

  /// No description provided for @shiftsExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"My Shifts\", \"Create Shift\"'**
  String get shiftsExample;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @eventsExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"My Events\", \"Create Event\"'**
  String get eventsExample;

  /// No description provided for @saveTerminology.
  ///
  /// In en, this message translates to:
  /// **'Save Terminology'**
  String get saveTerminology;

  /// No description provided for @terminologyUpdateInfo.
  ///
  /// In en, this message translates to:
  /// **'This will update how work assignments appear throughout the app'**
  String get terminologyUpdateInfo;

  /// No description provided for @venuesUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Venues updated successfully!'**
  String get venuesUpdatedSuccess;

  /// No description provided for @terminologyUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Terminology updated successfully!'**
  String get terminologyUpdatedSuccess;

  /// No description provided for @locationVenues.
  ///
  /// In en, this message translates to:
  /// **'Location & Venues'**
  String get locationVenues;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @citiesConfigured.
  ///
  /// In en, this message translates to:
  /// **'cities configured'**
  String get citiesConfigured;

  /// No description provided for @venues.
  ///
  /// In en, this message translates to:
  /// **'Venues'**
  String get venues;

  /// No description provided for @discovered.
  ///
  /// In en, this message translates to:
  /// **'discovered'**
  String get discovered;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get lastUpdated;

  /// No description provided for @noCitiesConfiguredDescription.
  ///
  /// In en, this message translates to:
  /// **'No cities configured yet. Add cities to discover venues and help the AI suggest accurate event locations in your area.'**
  String get noCitiesConfiguredDescription;

  /// No description provided for @manageCities.
  ///
  /// In en, this message translates to:
  /// **'Manage Cities'**
  String get manageCities;

  /// No description provided for @addCities.
  ///
  /// In en, this message translates to:
  /// **'Add Cities'**
  String get addCities;

  /// No description provided for @viewAllVenues.
  ///
  /// In en, this message translates to:
  /// **'View All {count} Venues'**
  String viewAllVenues(int count);

  /// No description provided for @addNewVenue.
  ///
  /// In en, this message translates to:
  /// **'Add New Venue'**
  String get addNewVenue;

  /// No description provided for @venueAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Venue added successfully!'**
  String get venueAddedSuccess;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile. Please try again in a few minutes.'**
  String get failedToLoadProfile;

  /// No description provided for @failedToUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image'**
  String get failedToUploadImage;

  /// No description provided for @newLookSaved.
  ///
  /// In en, this message translates to:
  /// **'New look saved!'**
  String get newLookSaved;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get failedToSave;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @deleteCreationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete creation?'**
  String get deleteCreationConfirm;

  /// No description provided for @deleteCreationMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove it from your gallery.'**
  String get deleteCreationMessage;

  /// No description provided for @creationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Creation deleted'**
  String get creationDeleted;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedToDelete;

  /// No description provided for @revertedToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Reverted to original photo'**
  String get revertedToOriginal;

  /// No description provided for @failedToRevert.
  ///
  /// In en, this message translates to:
  /// **'Failed to revert'**
  String get failedToRevert;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @appIdOptional.
  ///
  /// In en, this message translates to:
  /// **'App ID (9 digits, optional)'**
  String get appIdOptional;

  /// No description provided for @linkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get linkedAccounts;

  /// No description provided for @primary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary;

  /// No description provided for @linkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkAccount;

  /// No description provided for @phoneNumberLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Phone number linked successfully!'**
  String get phoneNumberLinkedSuccess;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @glowUp.
  ///
  /// In en, this message translates to:
  /// **'Glow Up'**
  String get glowUp;

  /// No description provided for @originalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Original Photo'**
  String get originalPhoto;

  /// No description provided for @myCreations.
  ///
  /// In en, this message translates to:
  /// **'My Creations'**
  String get myCreations;

  /// No description provided for @viewFullSize.
  ///
  /// In en, this message translates to:
  /// **'View Full Size'**
  String get viewFullSize;

  /// No description provided for @useThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use This Photo'**
  String get useThisPhoto;

  /// No description provided for @linkPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Link Phone Number'**
  String get linkPhoneNumber;

  /// No description provided for @addPhoneSigninMethod.
  ///
  /// In en, this message translates to:
  /// **'Add a phone number as an alternative sign-in method'**
  String get addPhoneSigninMethod;

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get sixDigitCode;

  /// No description provided for @verifyAndLink.
  ///
  /// In en, this message translates to:
  /// **'Verify & Link'**
  String get verifyAndLink;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// No description provided for @invalidPhoneNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number format'**
  String get invalidPhoneNumberFormat;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try later.'**
  String get tooManyAttempts;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code'**
  String get enterSixDigitCode;

  /// No description provided for @noVerificationInProgress.
  ///
  /// In en, this message translates to:
  /// **'No verification in progress'**
  String get noVerificationInProgress;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Check and try again.'**
  String get invalidCode;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new one.'**
  String get codeExpired;

  /// No description provided for @firebaseAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Firebase authentication failed'**
  String get firebaseAuthFailed;

  /// No description provided for @failedToGetAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Failed to get auth token'**
  String get failedToGetAuthToken;

  /// No description provided for @failedToLinkPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Failed to link phone number'**
  String get failedToLinkPhoneNumber;

  /// No description provided for @failedToLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to link'**
  String get failedToLink;

  /// No description provided for @failedToSendCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code'**
  String get failedToSendCode;

  /// No description provided for @welcomeFlowShiftPro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FlowShift Pro! All business features unlocked.'**
  String get welcomeFlowShiftPro;

  /// No description provided for @purchaseCancelledFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled or failed. Please try again.'**
  String get purchaseCancelledFailed;

  /// No description provided for @subscriptionRestoredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription restored successfully!'**
  String get subscriptionRestoredSuccess;

  /// No description provided for @noActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription found to restore.'**
  String get noActiveSubscription;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Restore error'**
  String get restoreError;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @scaleYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Scale Your Business'**
  String get scaleYourBusiness;

  /// No description provided for @unlimitedTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'Unlimited team members'**
  String get unlimitedTeamMembers;

  /// No description provided for @noLimitsStaffSize.
  ///
  /// In en, this message translates to:
  /// **'No limits on staff size'**
  String get noLimitsStaffSize;

  /// No description provided for @unlimitedEvents.
  ///
  /// In en, this message translates to:
  /// **'Unlimited events'**
  String get unlimitedEvents;

  /// No description provided for @createManyEvents.
  ///
  /// In en, this message translates to:
  /// **'Create as many events as you need'**
  String get createManyEvents;

  /// No description provided for @advancedAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced analytics'**
  String get advancedAnalytics;

  /// No description provided for @insightsReports.
  ///
  /// In en, this message translates to:
  /// **'Insights & reports for your business'**
  String get insightsReports;

  /// No description provided for @prioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get prioritySupport;

  /// No description provided for @getHelpWhenNeeded.
  ///
  /// In en, this message translates to:
  /// **'Get help when you need it'**
  String get getHelpWhenNeeded;

  /// No description provided for @allFutureProFeatures.
  ///
  /// In en, this message translates to:
  /// **'All future Pro features'**
  String get allFutureProFeatures;

  /// No description provided for @earlyAccessCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Early access to new capabilities'**
  String get earlyAccessCapabilities;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get perMonth;

  /// No description provided for @cancelAnytimeNoCommitments.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime • No commitments'**
  String get cancelAnytimeNoCommitments;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// No description provided for @freeTierLimits.
  ///
  /// In en, this message translates to:
  /// **'Free Tier Limits'**
  String get freeTierLimits;

  /// No description provided for @freeTierLimitsList.
  ///
  /// In en, this message translates to:
  /// **'• 25 team members max\n• 10 events per month\n• No analytics access'**
  String get freeTierLimitsList;

  /// No description provided for @subscriptionTermsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.'**
  String get subscriptionTermsDisclaimer;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @failedToLoadVenues.
  ///
  /// In en, this message translates to:
  /// **'Failed to load venues'**
  String get failedToLoadVenues;

  /// No description provided for @venueAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Venue added successfully!'**
  String get venueAddedSuccessfully;

  /// No description provided for @venueUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Venue updated successfully!'**
  String get venueUpdatedSuccessfully;

  /// No description provided for @venueRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Venue removed successfully!'**
  String get venueRemovedSuccessfully;

  /// No description provided for @failedToDeleteVenue.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete venue'**
  String get failedToDeleteVenue;

  /// No description provided for @removeVenueConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove Venue?'**
  String get removeVenueConfirmation;

  /// No description provided for @confirmRemoveVenue.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{name}\"?'**
  String confirmRemoveVenue(String name);

  /// No description provided for @myVenues.
  ///
  /// In en, this message translates to:
  /// **'My Venues'**
  String get myVenues;

  /// No description provided for @addVenue.
  ///
  /// In en, this message translates to:
  /// **'Add Venue'**
  String get addVenue;

  /// No description provided for @noVenuesYet.
  ///
  /// In en, this message translates to:
  /// **'No venues yet'**
  String get noVenuesYet;

  /// No description provided for @addFirstVenueOrDiscover.
  ///
  /// In en, this message translates to:
  /// **'Add your first venue or run venue discovery'**
  String get addFirstVenueOrDiscover;

  /// No description provided for @addFirstVenue.
  ///
  /// In en, this message translates to:
  /// **'Add First Venue'**
  String get addFirstVenue;

  /// No description provided for @yourArea.
  ///
  /// In en, this message translates to:
  /// **'Your Area'**
  String get yourArea;

  /// No description provided for @placesSource.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesSource;

  /// No description provided for @manualSource.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualSource;

  /// No description provided for @aiSource.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiSource;

  /// No description provided for @searchVenues.
  ///
  /// In en, this message translates to:
  /// **'Search venues...'**
  String get searchVenues;

  /// No description provided for @noVenuesInCity.
  ///
  /// In en, this message translates to:
  /// **'No venues in {cityName} yet'**
  String noVenuesInCity(String cityName);

  /// No description provided for @addVenuesManuallyOrDiscover.
  ///
  /// In en, this message translates to:
  /// **'Add venues manually or discover them from Settings > Manage Cities'**
  String get addVenuesManuallyOrDiscover;

  /// No description provided for @addCitiesFromSettings.
  ///
  /// In en, this message translates to:
  /// **'Add cities from Settings > Manage Cities'**
  String get addCitiesFromSettings;

  /// No description provided for @noVenuesMatch.
  ///
  /// In en, this message translates to:
  /// **'No venues match your search'**
  String get noVenuesMatch;

  /// No description provided for @tryDifferentFilterOrTerm.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter or search term'**
  String get tryDifferentFilterOrTerm;

  /// No description provided for @tryDifferentSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearchTerm;

  /// No description provided for @failedToGetPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to get place details'**
  String get failedToGetPlaceDetails;

  /// No description provided for @editVenue.
  ///
  /// In en, this message translates to:
  /// **'Edit Venue'**
  String get editVenue;

  /// No description provided for @editVenueDetailsBelow.
  ///
  /// In en, this message translates to:
  /// **'Edit venue details below'**
  String get editVenueDetailsBelow;

  /// No description provided for @searchVenueAutoFill.
  ///
  /// In en, this message translates to:
  /// **'Search for a venue and we\'ll auto-fill the details'**
  String get searchVenueAutoFill;

  /// No description provided for @searchVenue.
  ///
  /// In en, this message translates to:
  /// **'Search venue'**
  String get searchVenue;

  /// No description provided for @venueSearchExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ball Arena Denver'**
  String get venueSearchExample;

  /// No description provided for @enterManuallyInstead.
  ///
  /// In en, this message translates to:
  /// **'Enter manually instead'**
  String get enterManuallyInstead;

  /// No description provided for @venueFoundGooglePlaces.
  ///
  /// In en, this message translates to:
  /// **'Venue found via Google Places'**
  String get venueFoundGooglePlaces;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @venueName.
  ///
  /// In en, this message translates to:
  /// **'Venue Name *'**
  String get venueName;

  /// No description provided for @venueNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ball Arena'**
  String get venueNameExample;

  /// No description provided for @pleaseEnterVenueName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a venue name'**
  String get pleaseEnterVenueName;

  /// No description provided for @addressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address *'**
  String get addressRequired;

  /// No description provided for @addressExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., 1000 Chopper Cir, Denver, CO 80204'**
  String get addressExample;

  /// No description provided for @pleaseEnterAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter an address'**
  String get pleaseEnterAddress;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @venueAddedCityTabCreated.
  ///
  /// In en, this message translates to:
  /// **'Venue added and new city tab created!'**
  String get venueAddedCityTabCreated;

  /// No description provided for @venueUpdatedCityTabAdded.
  ///
  /// In en, this message translates to:
  /// **'Venue updated and city tab added!'**
  String get venueUpdatedCityTabAdded;

  /// No description provided for @failedToSaveVenue.
  ///
  /// In en, this message translates to:
  /// **'Failed to save venue'**
  String get failedToSaveVenue;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @failedToLoadCities.
  ///
  /// In en, this message translates to:
  /// **'Failed to load cities'**
  String get failedToLoadCities;

  /// No description provided for @cityAlreadyInList.
  ///
  /// In en, this message translates to:
  /// **'This city is already in your list'**
  String get cityAlreadyInList;

  /// No description provided for @addedCity.
  ///
  /// In en, this message translates to:
  /// **'Added {city}'**
  String addedCity(String city);

  /// No description provided for @failedToAddCity.
  ///
  /// In en, this message translates to:
  /// **'Failed to add city'**
  String get failedToAddCity;

  /// No description provided for @failedToUpdateCity.
  ///
  /// In en, this message translates to:
  /// **'Failed to update city'**
  String get failedToUpdateCity;

  /// No description provided for @deleteCity.
  ///
  /// In en, this message translates to:
  /// **'Delete City'**
  String get deleteCity;

  /// No description provided for @confirmDeleteCity.
  ///
  /// In en, this message translates to:
  /// **'Delete {cityName}?\n\nThis will also remove all venues associated with this city.'**
  String confirmDeleteCity(String cityName);

  /// No description provided for @deletedCity.
  ///
  /// In en, this message translates to:
  /// **'Deleted {cityName}'**
  String deletedCity(String cityName);

  /// No description provided for @failedToDeleteCity.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete city'**
  String get failedToDeleteCity;

  /// No description provided for @discoverVenues.
  ///
  /// In en, this message translates to:
  /// **'Discover Venues'**
  String get discoverVenues;

  /// No description provided for @discoverVenuesWarning.
  ///
  /// In en, this message translates to:
  /// **'AI will search the web for event venues in {cityName}. This can take up to 2-3 minutes depending on the city size.\n\nPlease keep the app open during the search.'**
  String discoverVenuesWarning(String cityName);

  /// No description provided for @startSearch.
  ///
  /// In en, this message translates to:
  /// **'Start Search'**
  String get startSearch;

  /// No description provided for @discoveredVenuesCount.
  ///
  /// In en, this message translates to:
  /// **'Discovered {count} venues for {cityName}'**
  String discoveredVenuesCount(int count, String cityName);

  /// No description provided for @failedToDiscoverVenues.
  ///
  /// In en, this message translates to:
  /// **'Failed to discover venues'**
  String get failedToDiscoverVenues;

  /// No description provided for @noCitiesAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No cities added yet'**
  String get noCitiesAddedYet;

  /// No description provided for @addFirstCityDiscover.
  ///
  /// In en, this message translates to:
  /// **'Add your first city to discover venues'**
  String get addFirstCityDiscover;

  /// No description provided for @touristCityStrictSearch.
  ///
  /// In en, this message translates to:
  /// **'Tourist City (strict search)'**
  String get touristCityStrictSearch;

  /// No description provided for @metroAreaBroadSearch.
  ///
  /// In en, this message translates to:
  /// **'Metro Area (broad search)'**
  String get metroAreaBroadSearch;

  /// No description provided for @searchingWeb.
  ///
  /// In en, this message translates to:
  /// **'Searching web... (up to 3 min)'**
  String get searchingWeb;

  /// No description provided for @addCity.
  ///
  /// In en, this message translates to:
  /// **'Add City'**
  String get addCity;

  /// No description provided for @selectOrTypeCity.
  ///
  /// In en, this message translates to:
  /// **'Select or Type City'**
  String get selectOrTypeCity;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @allCountries.
  ///
  /// In en, this message translates to:
  /// **'All Countries'**
  String get allCountries;

  /// No description provided for @stateProvince.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get stateProvince;

  /// No description provided for @allStates.
  ///
  /// In en, this message translates to:
  /// **'All States'**
  String get allStates;

  /// No description provided for @typeOrSearchCity.
  ///
  /// In en, this message translates to:
  /// **'Type or Search City'**
  String get typeOrSearchCity;

  /// No description provided for @enterAnyCityName.
  ///
  /// In en, this message translates to:
  /// **'Enter any city name...'**
  String get enterAnyCityName;

  /// No description provided for @useCustomCity.
  ///
  /// In en, this message translates to:
  /// **'Use custom city:'**
  String get useCustomCity;

  /// No description provided for @noMatchingCitiesSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No matching cities in suggestions'**
  String get noMatchingCitiesSuggestions;

  /// No description provided for @canTypeAnyCityAbove.
  ///
  /// In en, this message translates to:
  /// **'You can type any city name above'**
  String get canTypeAnyCityAbove;

  /// No description provided for @tourist.
  ///
  /// In en, this message translates to:
  /// **'Tourist'**
  String get tourist;

  /// No description provided for @metro.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get metro;

  /// No description provided for @suggestedCities.
  ///
  /// In en, this message translates to:
  /// **'suggested cities'**
  String get suggestedCities;

  /// No description provided for @addYourFirstCity.
  ///
  /// In en, this message translates to:
  /// **'Add Your First City'**
  String get addYourFirstCity;

  /// No description provided for @addAnotherCity.
  ///
  /// In en, this message translates to:
  /// **'Add Another City'**
  String get addAnotherCity;

  /// No description provided for @logoUploadedColorsExtracted.
  ///
  /// In en, this message translates to:
  /// **'Logo uploaded and colors extracted!'**
  String get logoUploadedColorsExtracted;

  /// No description provided for @failedToUploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload logo'**
  String get failedToUploadLogo;

  /// No description provided for @removeBrandingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove Branding?'**
  String get removeBrandingConfirmation;

  /// No description provided for @removeBrandingWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete your logo and custom colors. Exported documents will revert to the default FlowShift styling.'**
  String get removeBrandingWarning;

  /// No description provided for @brandCustomization.
  ///
  /// In en, this message translates to:
  /// **'Brand Customization'**
  String get brandCustomization;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro;

  /// No description provided for @upgradeToProCustomization.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro to personalize your exported documents with your own logo and brand colors.'**
  String get upgradeToProCustomization;

  /// No description provided for @uploadYourLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload Your Logo'**
  String get uploadYourLogo;

  /// No description provided for @logoFormats.
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG, or WebP (max 5MB)'**
  String get logoFormats;

  /// No description provided for @replaceLogo.
  ///
  /// In en, this message translates to:
  /// **'Replace Logo'**
  String get replaceLogo;

  /// No description provided for @documentStyle.
  ///
  /// In en, this message translates to:
  /// **'Document Style'**
  String get documentStyle;

  /// No description provided for @chooseDocumentStyle.
  ///
  /// In en, this message translates to:
  /// **'Choose how exported documents look'**
  String get chooseDocumentStyle;

  /// No description provided for @extractingColors.
  ///
  /// In en, this message translates to:
  /// **'Extracting brand colors with AI...'**
  String get extractingColors;

  /// No description provided for @uploadingLogo.
  ///
  /// In en, this message translates to:
  /// **'Uploading logo...'**
  String get uploadingLogo;

  /// No description provided for @brandingRemoved.
  ///
  /// In en, this message translates to:
  /// **'Branding removed'**
  String get brandingRemoved;

  /// No description provided for @colorsSaved.
  ///
  /// In en, this message translates to:
  /// **'Colors saved!'**
  String get colorsSaved;

  /// No description provided for @saveColors.
  ///
  /// In en, this message translates to:
  /// **'Save Colors'**
  String get saveColors;

  /// No description provided for @aiExtracted.
  ///
  /// In en, this message translates to:
  /// **'AI Extracted'**
  String get aiExtracted;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex Color'**
  String get hexColor;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @mergeDuplicateClients.
  ///
  /// In en, this message translates to:
  /// **'Merge Duplicate Clients'**
  String get mergeDuplicateClients;

  /// No description provided for @mergingClients.
  ///
  /// In en, this message translates to:
  /// **'Merging clients...'**
  String get mergingClients;

  /// No description provided for @confirmMerge.
  ///
  /// In en, this message translates to:
  /// **'Confirm Merge'**
  String get confirmMerge;

  /// No description provided for @keepPrimary.
  ///
  /// In en, this message translates to:
  /// **'Keep: \"{name}\"'**
  String keepPrimary(String name);

  /// No description provided for @mergeDuplicatesCount.
  ///
  /// In en, this message translates to:
  /// **'Merge & delete {count} duplicate(s):'**
  String mergeDuplicatesCount(int count);

  /// No description provided for @transferEventsAndTariffs.
  ///
  /// In en, this message translates to:
  /// **'All events and tariffs will be transferred to \"{name}\".'**
  String transferEventsAndTariffs(String name);

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @failedToMerge.
  ///
  /// In en, this message translates to:
  /// **'Failed to merge'**
  String get failedToMerge;

  /// No description provided for @mergedClients.
  ///
  /// In en, this message translates to:
  /// **'Merged {count} client(s) into \"{name}\"'**
  String mergedClients(int count, String name);

  /// No description provided for @sensitivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity: {percent}%'**
  String sensitivityLabel(int percent);

  /// No description provided for @noDuplicatesFound.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found'**
  String get noDuplicatesFound;

  /// No description provided for @lowerSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Try lowering the sensitivity to find looser matches.'**
  String get lowerSensitivity;

  /// No description provided for @groupNumber.
  ///
  /// In en, this message translates to:
  /// **'Group {number}'**
  String groupNumber(int number);

  /// No description provided for @similarPercent.
  ///
  /// In en, this message translates to:
  /// **'% similar'**
  String get similarPercent;

  /// No description provided for @clientsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} clients'**
  String clientsCountLabel(int count);

  /// No description provided for @tapClientSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Tap a client to set it as primary (kept):'**
  String get tapClientSetPrimary;

  /// No description provided for @willBeMerged.
  ///
  /// In en, this message translates to:
  /// **'will be merged'**
  String get willBeMerged;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'KEEP'**
  String get keep;

  /// No description provided for @mergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} into \"{name}\"'**
  String mergeInto(int count, String name);

  /// No description provided for @profileGlowUp.
  ///
  /// In en, this message translates to:
  /// **'Profile Glow Up'**
  String get profileGlowUp;

  /// No description provided for @whoAreYouToday.
  ///
  /// In en, this message translates to:
  /// **'Who are you today?'**
  String get whoAreYouToday;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See {count} more'**
  String seeMore(int count);

  /// No description provided for @seeLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get seeLess;

  /// No description provided for @pickYourVibe.
  ///
  /// In en, this message translates to:
  /// **'Pick your vibe'**
  String get pickYourVibe;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @hd.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get hd;

  /// No description provided for @higherDetailFacialPreservation.
  ///
  /// In en, this message translates to:
  /// **'Higher detail & better facial preservation'**
  String get higherDetailFacialPreservation;

  /// No description provided for @textInImage.
  ///
  /// In en, this message translates to:
  /// **'Text in image'**
  String get textInImage;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @readyForNewLook.
  ///
  /// In en, this message translates to:
  /// **'Ready for a new look?'**
  String get readyForNewLook;

  /// No description provided for @hitButtonSeeMagic.
  ///
  /// In en, this message translates to:
  /// **'Hit the button and see the magic'**
  String get hitButtonSeeMagic;

  /// No description provided for @lookingGood.
  ///
  /// In en, this message translates to:
  /// **'Looking good!'**
  String get lookingGood;

  /// No description provided for @fromYourHistory.
  ///
  /// In en, this message translates to:
  /// **'From your history'**
  String get fromYourHistory;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get before;

  /// No description provided for @after.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get after;

  /// No description provided for @usuallyTakes15Seconds.
  ///
  /// In en, this message translates to:
  /// **'This usually takes about 15 seconds'**
  String get usuallyTakes15Seconds;

  /// No description provided for @failedToLoadStyles.
  ///
  /// In en, this message translates to:
  /// **'Failed to load styles'**
  String get failedToLoadStyles;

  /// No description provided for @aiGeneratedMayNotBeAccurate.
  ///
  /// In en, this message translates to:
  /// **'AI-generated images may not be accurate'**
  String get aiGeneratedMayNotBeAccurate;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @generateNew.
  ///
  /// In en, this message translates to:
  /// **'Generate New'**
  String get generateNew;

  /// No description provided for @getMyNewLook.
  ///
  /// In en, this message translates to:
  /// **'Get My New Look'**
  String get getMyNewLook;

  /// No description provided for @sendEventInvitationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send Event Invitation'**
  String get sendEventInvitationTooltip;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get exportReport;

  /// No description provided for @chooseFormatAndReportType.
  ///
  /// In en, this message translates to:
  /// **'Choose format and report type'**
  String get chooseFormatAndReportType;

  /// No description provided for @reportType.
  ///
  /// In en, this message translates to:
  /// **'Report Type'**
  String get reportType;

  /// No description provided for @payrollReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Payroll Report'**
  String get payrollReportLabel;

  /// No description provided for @payrollReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Staff earnings breakdown by hours and pay rate'**
  String get payrollReportDescription;

  /// No description provided for @attendanceReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance Report'**
  String get attendanceReportLabel;

  /// No description provided for @attendanceReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Clock-in/out times and hours worked'**
  String get attendanceReportDescription;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get exportFormat;

  /// No description provided for @csvLabel.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csvLabel;

  /// No description provided for @excelCompatible.
  ///
  /// In en, this message translates to:
  /// **'Excel compatible'**
  String get excelCompatible;

  /// No description provided for @pdfLabel.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdfLabel;

  /// No description provided for @printReady.
  ///
  /// In en, this message translates to:
  /// **'Print ready'**
  String get printReady;

  /// No description provided for @exportFormatButton.
  ///
  /// In en, this message translates to:
  /// **'Export {format}'**
  String exportFormatButton(String format);

  /// No description provided for @lastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get lastSevenDays;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get customRange;

  /// No description provided for @createInviteLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Invite Link'**
  String get createInviteLinkTitle;

  /// No description provided for @shareableLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a shareable link that anyone can use to join your team.'**
  String get shareableLinkDescription;

  /// No description provided for @linkExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Link expires in:'**
  String get linkExpiresIn;

  /// No description provided for @maxUsesOptional.
  ///
  /// In en, this message translates to:
  /// **'Max uses (optional):'**
  String get maxUsesOptional;

  /// No description provided for @leaveEmptyUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get leaveEmptyUnlimited;

  /// No description provided for @requireApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Require approval'**
  String get requireApprovalTitle;

  /// No description provided for @requireApprovalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You must approve members after they join'**
  String get requireApprovalSubtitle;

  /// No description provided for @passwordOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (optional):'**
  String get passwordOptionalLabel;

  /// No description provided for @leaveEmptyNoPassword.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no password'**
  String get leaveEmptyNoPassword;

  /// No description provided for @createLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Create Link'**
  String get createLinkButton;

  /// No description provided for @inviteLinkCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Link Created!'**
  String get inviteLinkCreatedTitle;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code:'**
  String get inviteCodeLabel;

  /// No description provided for @deepLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Deep Link:'**
  String get deepLinkLabel;

  /// No description provided for @shareDeepLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Share this link - it will open the app automatically'**
  String get shareDeepLinkHint;

  /// No description provided for @expiresDate.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String expiresDate(String date);

  /// No description provided for @shareViaApps.
  ///
  /// In en, this message translates to:
  /// **'Share via WhatsApp, SMS, etc.'**
  String get shareViaApps;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get showQrCode;

  /// No description provided for @joinTeamSubject.
  ///
  /// In en, this message translates to:
  /// **'Join my team on FlowShift'**
  String get joinTeamSubject;

  /// No description provided for @unknownApplicant.
  ///
  /// In en, this message translates to:
  /// **'Unknown applicant'**
  String get unknownApplicant;

  /// No description provided for @appliedDate.
  ///
  /// In en, this message translates to:
  /// **'Applied {date}'**
  String appliedDate(String date);

  /// No description provided for @errorLoadingEvents.
  ///
  /// In en, this message translates to:
  /// **'Error loading events'**
  String get errorLoadingEvents;

  /// No description provided for @noEventsFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFoundTitle;

  /// No description provided for @notLinkedToEventsYet.
  ///
  /// In en, this message translates to:
  /// **'This user is not linked to any events yet'**
  String get notLinkedToEventsYet;

  /// No description provided for @upcomingEventsCount.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events ({count})'**
  String upcomingEventsCount(int count);

  /// No description provided for @dateUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Unknown'**
  String get dateUnknownLabel;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventTitle;

  /// No description provided for @eventUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event has been updated successfully!'**
  String get eventUpdatedSuccessfully;

  /// No description provided for @failedToUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to update event'**
  String get failedToUpdateEvent;

  /// No description provided for @selectDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDateHint;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @clockOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clock out {name}?'**
  String clockOutConfirmation(String name);

  /// No description provided for @removeStaffConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this staff member from the event?'**
  String get removeStaffConfirmation;

  /// No description provided for @openToAllStaffConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Make \"{name}\" visible to all staff members?\n\nThis will change the job from private (invited only) to public, allowing all team members to see and accept it.'**
  String openToAllStaffConfirmation(String name);

  /// No description provided for @clockInConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clock in {name} for this event?'**
  String clockInConfirmation(String name);

  /// No description provided for @workingHoursSheetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Working Hours Sheet'**
  String get workingHoursSheetTooltip;

  /// No description provided for @idLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String idLabel(String id);

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @publicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicLabel;

  /// No description provided for @privatePlusPublic.
  ///
  /// In en, this message translates to:
  /// **'Private+Public'**
  String get privatePlusPublic;

  /// No description provided for @setUpStaffingCompany.
  ///
  /// In en, this message translates to:
  /// **'Set up your staffing company (e.g., \"MES - Minneapolis Event Staffing\")'**
  String get setUpStaffingCompany;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptionalLabel;

  /// No description provided for @briefDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of your staffing company'**
  String get briefDescriptionHint;

  /// No description provided for @createTeamButton.
  ///
  /// In en, this message translates to:
  /// **'Create team'**
  String get createTeamButton;

  /// No description provided for @clientsConfiguredCount.
  ///
  /// In en, this message translates to:
  /// **'Clients configured: {count}'**
  String clientsConfiguredCount(int count);

  /// No description provided for @needAtLeastOneClientDesc.
  ///
  /// In en, this message translates to:
  /// **'You need at least one client before you can staff events.'**
  String get needAtLeastOneClientDesc;

  /// No description provided for @clientNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Client name'**
  String get clientNameLabel;

  /// No description provided for @completeProfileAndTeam.
  ///
  /// In en, this message translates to:
  /// **'Complete profile and team first'**
  String get completeProfileAndTeam;

  /// No description provided for @createClientButton.
  ///
  /// In en, this message translates to:
  /// **'Create client'**
  String get createClientButton;

  /// No description provided for @rolesConfiguredCount.
  ///
  /// In en, this message translates to:
  /// **'Roles configured: {count}'**
  String rolesConfiguredCount(int count);

  /// No description provided for @rolesHelpMatchStaffDesc.
  ///
  /// In en, this message translates to:
  /// **'Roles help match staff to the right job (waiter, chef, bartender...).'**
  String get rolesHelpMatchStaffDesc;

  /// No description provided for @roleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Role name'**
  String get roleNameLabel;

  /// No description provided for @finishPreviousSteps.
  ///
  /// In en, this message translates to:
  /// **'Finish previous steps first'**
  String get finishPreviousSteps;

  /// No description provided for @createRoleButton.
  ///
  /// In en, this message translates to:
  /// **'Create role'**
  String get createRoleButton;

  /// No description provided for @tariffsConfiguredCount.
  ///
  /// In en, this message translates to:
  /// **'Tariffs configured: {count}'**
  String tariffsConfiguredCount(int count);

  /// No description provided for @setRateDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a rate so staffing assignments know what to bill.'**
  String get setRateDescription;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clientLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @adjustLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can adjust this later in Catalog > Tariffs'**
  String get adjustLaterHint;

  /// No description provided for @pleaseEnterTimesForAllStaff.
  ///
  /// In en, this message translates to:
  /// **'Please enter sign-in and sign-out times for all selected staff'**
  String get pleaseEnterTimesForAllStaff;

  /// No description provided for @hoursSubmittedAndApproved.
  ///
  /// In en, this message translates to:
  /// **'Hours submitted and approved successfully'**
  String get hoursSubmittedAndApproved;

  /// No description provided for @submitHoursButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Hours ({count})'**
  String submitHoursButton(int count);

  /// No description provided for @bartenderHint.
  ///
  /// In en, this message translates to:
  /// **'Bartender'**
  String get bartenderHint;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @roleHint.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleHint;

  /// No description provided for @noEventsNeedApprovalDescription.
  ///
  /// In en, this message translates to:
  /// **'No events need hours approval at the moment.'**
  String get noEventsNeedApprovalDescription;

  /// No description provided for @pendingReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReviewLabel;

  /// No description provided for @needsSheetLabel.
  ///
  /// In en, this message translates to:
  /// **'Needs Sheet'**
  String get needsSheetLabel;

  /// No description provided for @purchaseCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled or failed. Please try again.'**
  String get purchaseCancelledMessage;

  /// No description provided for @upgradeToProTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToProTitle;

  /// No description provided for @flowShiftPro.
  ///
  /// In en, this message translates to:
  /// **'FlowShift Pro'**
  String get flowShiftPro;

  /// No description provided for @createAsManyEvents.
  ///
  /// In en, this message translates to:
  /// **'Create as many events as you need'**
  String get createAsManyEvents;

  /// No description provided for @noLimitsDescription.
  ///
  /// In en, this message translates to:
  /// **'No limits on staff size'**
  String get noLimitsDescription;

  /// No description provided for @earlyAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Early access to new capabilities'**
  String get earlyAccessDescription;

  /// No description provided for @subscriptionTerms.
  ///
  /// In en, this message translates to:
  /// **'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.'**
  String get subscriptionTerms;

  /// No description provided for @staffWillAppearOnClockIn.
  ///
  /// In en, this message translates to:
  /// **'Staff will appear here when they clock in'**
  String get staffWillAppearOnClockIn;

  /// No description provided for @cancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get cancelInvite;

  /// No description provided for @usedCount.
  ///
  /// In en, this message translates to:
  /// **'Used: {used} / {max}'**
  String usedCount(int used, int max);

  /// No description provided for @usedCountUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Used: {used} (unlimited)'**
  String usedCountUnlimited(int used);

  /// No description provided for @codePrefix.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String codePrefix(String code);

  /// No description provided for @addVenuesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add venues manually or discover them from Settings > Manage Cities'**
  String get addVenuesDescription;

  /// No description provided for @searchVenuesHint.
  ///
  /// In en, this message translates to:
  /// **'Search venues...'**
  String get searchVenuesHint;

  /// No description provided for @invalidPhoneFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number format'**
  String get invalidPhoneFormat;

  /// No description provided for @tooManyAttemptsMessage.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try later.'**
  String get tooManyAttemptsMessage;

  /// No description provided for @invalidCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Check and try again.'**
  String get invalidCodeMessage;

  /// No description provided for @codeExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new one.'**
  String get codeExpiredMessage;

  /// No description provided for @addPhoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a phone number as an alternative sign-in method'**
  String get addPhoneDescription;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberHint;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @eventInformation.
  ///
  /// In en, this message translates to:
  /// **'Event Information'**
  String get eventInformation;

  /// No description provided for @venueInformation.
  ///
  /// In en, this message translates to:
  /// **'Venue Information'**
  String get venueInformation;

  /// No description provided for @staffRolesRequired.
  ///
  /// In en, this message translates to:
  /// **'Staff Roles Required'**
  String get staffRolesRequired;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successTitle;

  /// No description provided for @selectTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTimeHint;

  /// No description provided for @clockingInStaff.
  ///
  /// In en, this message translates to:
  /// **'Clocking in {staffName}...'**
  String clockingInStaff(String staffName);

  /// No description provided for @roleVacancies.
  ///
  /// In en, this message translates to:
  /// **'{roleName} ({accepted}/{total}, {vacancies} left)'**
  String roleVacancies(String roleName, int accepted, int total, int vacancies);

  /// No description provided for @phoneLinkedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Phone number linked successfully!'**
  String get phoneLinkedSuccessfully;

  /// No description provided for @teamReady.
  ///
  /// In en, this message translates to:
  /// **'Team ready: {name}'**
  String teamReady(String name);

  /// No description provided for @proWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FlowShift Pro! All business features unlocked.'**
  String get proWelcomeMessage;

  /// No description provided for @dateTbd.
  ///
  /// In en, this message translates to:
  /// **'Date TBD'**
  String get dateTbd;

  /// No description provided for @freeTierLimitsDetails.
  ///
  /// In en, this message translates to:
  /// **'• 25 team members max\n• 10 events per month\n• No analytics access'**
  String get freeTierLimitsDetails;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorPrefix;

  /// No description provided for @moveToDraftsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Move \"{name}\" back to drafts?'**
  String moveToDraftsConfirmation(String name);

  /// No description provided for @memberRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberRemovedSuccess;

  /// No description provided for @failedToRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member'**
  String get failedToRemoveMember;

  /// No description provided for @staffHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff Hours'**
  String get staffHoursLabel;

  /// No description provided for @eventsCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Events Completed'**
  String get eventsCompletedLabel;

  /// No description provided for @fulfillmentRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment Rate'**
  String get fulfillmentRateLabel;

  /// No description provided for @scanLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanLabel;

  /// No description provided for @aiChatLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChatLabel;

  /// No description provided for @uploadLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
