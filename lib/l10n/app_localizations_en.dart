// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get jobDataExtractor => 'Job Data Extractor';

  @override
  String get uploadPdfToExtract =>
      'Upload a PDF or image to extract catering job details';

  @override
  String get enterJobDetailsManually =>
      'Enter job details manually for precise control';

  @override
  String get createJobsThroughAI =>
      'Create jobs through natural conversation with AI';

  @override
  String get jobDetails => 'Job Details';

  @override
  String get jobInformation => 'Job Information';

  @override
  String get jobTitle => 'Job Title';

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
  String get job => 'Job';

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
  String get pleaseSelectDate => 'Please select a date for the job';

  @override
  String get jobSavedToPending =>
      'Job saved to pending. Go to Jobs tab to review.';

  @override
  String get jobDetailsCopied => 'Job details copied to clipboard';

  @override
  String get jobPublished => 'Job published';

  @override
  String get jobInvitationSent => 'Job invitation sent!';

  @override
  String get jobNotFound => 'Job not found';

  @override
  String guests(int count) {
    return '$count guests';
  }

  @override
  String get rolesNeeded => 'Roles Needed';

  @override
  String get untitledJob => 'Untitled Job';

  @override
  String get expectedHeadcount => 'Expected Headcount';

  @override
  String get contactPhone => 'Contact Phone';

  @override
  String get contactEmail => 'Contact Email';

  @override
  String get errorJobIdMissing => 'Error: Job ID is missing...';

  @override
  String get publishJob => 'Publish Job';

  @override
  String get setRolesForJob => 'Set roles for this job';

  @override
  String get searchJobs => 'Search jobs...';

  @override
  String get locationTbd => 'Location TBD';

  @override
  String shareJobPrefix(String clientName) {
    return 'Job: $clientName';
  }

  @override
  String get navCreate => 'Create';

  @override
  String get navJobs => 'Jobs';

  @override
  String get navChat => 'Chat';

  @override
  String get navHours => 'Hours';

  @override
  String get navCatalog => 'Catalog';
}
