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

  /// Title for the job data extraction feature
  ///
  /// In en, this message translates to:
  /// **'Job Data Extractor'**
  String get jobDataExtractor;

  /// Subtitle explaining PDF upload feature
  ///
  /// In en, this message translates to:
  /// **'Upload a PDF or image to extract catering job details'**
  String get uploadPdfToExtract;

  /// Subtitle for manual entry option
  ///
  /// In en, this message translates to:
  /// **'Enter job details manually for precise control'**
  String get enterJobDetailsManually;

  /// Subtitle for AI chat feature
  ///
  /// In en, this message translates to:
  /// **'Create jobs through natural conversation with AI'**
  String get createJobsThroughAI;

  /// Section header for job details
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get jobDetails;

  /// Section header for job information form
  ///
  /// In en, this message translates to:
  /// **'Job Information'**
  String get jobInformation;

  /// Label for job name/title field
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get jobTitle;

  /// Label for client name field
  ///
  /// In en, this message translates to:
  /// **'Client Name'**
  String get clientName;

  /// Label for start time field
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// Label for end time field
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// Label for headcount/guests field
  ///
  /// In en, this message translates to:
  /// **'Headcount'**
  String get headcount;

  /// Section header for location details
  ///
  /// In en, this message translates to:
  /// **'Location Information'**
  String get locationInformation;

  /// Label for location/venue name field
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get locationName;

  /// Label for address field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Label for city field
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Label for state field
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// Label for contact name field
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get contactName;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for notes field
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Label for job in summary display
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get job;

  /// Label for client in summary display
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// Label for date in summary display
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Label for time in summary display
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Label for location in summary display
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Label for phone in summary display
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Tab label showing job counts
  ///
  /// In en, this message translates to:
  /// **'Jobs • {pendingCount} pending, {upcomingCount} upcoming, {pastCount} past'**
  String jobsTabLabel(int pendingCount, int upcomingCount, int pastCount);

  /// Status text for pending and upcoming jobs
  ///
  /// In en, this message translates to:
  /// **'{pendingCount} pending • {upcomingCount} upcoming • {baseTime}'**
  String pendingUpcomingStatus(
    int pendingCount,
    int upcomingCount,
    String baseTime,
  );

  /// Status text for upcoming and past jobs
  ///
  /// In en, this message translates to:
  /// **'{upcomingCount} upcoming • {pastCount} past • {baseTime}'**
  String upcomingPastStatus(int upcomingCount, int pastCount, String baseTime);

  /// Error message when date is not selected
  ///
  /// In en, this message translates to:
  /// **'Please select a date for the job'**
  String get pleaseSelectDate;

  /// Success message when job is saved to pending
  ///
  /// In en, this message translates to:
  /// **'Job saved to pending. Go to Jobs tab to review.'**
  String get jobSavedToPending;

  /// Success message when job details are copied
  ///
  /// In en, this message translates to:
  /// **'Job details copied to clipboard'**
  String get jobDetailsCopied;

  /// Success message when job is published
  ///
  /// In en, this message translates to:
  /// **'Job published'**
  String get jobPublished;

  /// Success message when job invitation is sent
  ///
  /// In en, this message translates to:
  /// **'Job invitation sent!'**
  String get jobInvitationSent;

  /// Error message when job is not found
  ///
  /// In en, this message translates to:
  /// **'Job not found'**
  String get jobNotFound;

  /// Display text for number of guests
  ///
  /// In en, this message translates to:
  /// **'{count} guests'**
  String guests(int count);

  /// Section header for roles needed
  ///
  /// In en, this message translates to:
  /// **'Roles Needed'**
  String get rolesNeeded;

  /// Fallback text when job has no title
  ///
  /// In en, this message translates to:
  /// **'Untitled Job'**
  String get untitledJob;

  /// Label for expected headcount field
  ///
  /// In en, this message translates to:
  /// **'Expected Headcount'**
  String get expectedHeadcount;

  /// Label for contact phone field
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get contactPhone;

  /// Label for contact email field
  ///
  /// In en, this message translates to:
  /// **'Contact Email'**
  String get contactEmail;

  /// Error message when job ID is missing
  ///
  /// In en, this message translates to:
  /// **'Error: Job ID is missing...'**
  String get errorJobIdMissing;

  /// Title for publish job screen
  ///
  /// In en, this message translates to:
  /// **'Publish Job'**
  String get publishJob;

  /// Dialog title for setting roles
  ///
  /// In en, this message translates to:
  /// **'Set roles for this job'**
  String get setRolesForJob;

  /// Hint text for job search field
  ///
  /// In en, this message translates to:
  /// **'Search jobs...'**
  String get searchJobs;

  /// Placeholder when location is to be determined
  ///
  /// In en, this message translates to:
  /// **'Location TBD'**
  String get locationTbd;

  /// Prefix for sharing job details
  ///
  /// In en, this message translates to:
  /// **'Job: {clientName}'**
  String shareJobPrefix(String clientName);

  /// Bottom navigation bar label for create tab
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// Bottom navigation bar label for jobs/events tab
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// Bottom navigation bar label for chat tab
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// Bottom navigation bar label for hours approval tab
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get navHours;

  /// Bottom navigation bar label for catalog tab
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get navCatalog;

  /// Tab label for upload data option
  ///
  /// In en, this message translates to:
  /// **'Upload Data'**
  String get uploadData;

  /// Tab label for manual entry option
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// Tab label for multi-upload option
  ///
  /// In en, this message translates to:
  /// **'Multi-Upload'**
  String get multiUpload;

  /// Tab label for AI chat option
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// Button text for choosing file to upload
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// Section header for detailed explanation
  ///
  /// In en, this message translates to:
  /// **'Detailed Explanation'**
  String get detailedExplanation;

  /// Subtitle for chat screen
  ///
  /// In en, this message translates to:
  /// **'Messages and team members'**
  String get messagesAndTeamMembers;

  /// Search field placeholder in chat
  ///
  /// In en, this message translates to:
  /// **'Search name or email'**
  String get searchNameOrEmail;

  /// Filter tab for all items
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Role filter for bartender
  ///
  /// In en, this message translates to:
  /// **'Bartender'**
  String get bartender;

  /// Role filter for server
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// Messages section header with count
  ///
  /// In en, this message translates to:
  /// **'Messages ({count})'**
  String messages(int count);

  /// Chat message preview for job invitation
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to {jobName}'**
  String youveBeenInvitedTo(String jobName);

  /// Title for hours approval screen
  ///
  /// In en, this message translates to:
  /// **'Hours Approval'**
  String get hoursApproval;

  /// Badge text when sheet is needed
  ///
  /// In en, this message translates to:
  /// **'Needs Sheet'**
  String get needsSheet;

  /// Badge text with count needing sheets
  ///
  /// In en, this message translates to:
  /// **'{count} Needs Sheet'**
  String needsSheetCount(int count);

  /// Display text for number of staff
  ///
  /// In en, this message translates to:
  /// **'{count} staff'**
  String staffCount(int count);

  /// Catalog header with counts
  ///
  /// In en, this message translates to:
  /// **'Catalog • {clientCount} clients, {roleCount} roles'**
  String catalogClientsRoles(int clientCount, int roleCount);

  /// Tab label for clients
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// Tab label for roles
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// Tab label for tariffs
  ///
  /// In en, this message translates to:
  /// **'Tariffs'**
  String get tariffs;

  /// Button text for adding a client
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get addClient;
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
