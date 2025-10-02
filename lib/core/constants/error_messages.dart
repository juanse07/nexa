/// User-friendly error messages
class ErrorMessages {
  ErrorMessages._();

  // Network Errors
  static const String noInternetConnection =
      'No internet connection. Please check your network settings.';
  static const String connectionTimeout =
      'Connection timeout. Please try again later.';
  static const String serverNotResponding =
      'Server is not responding. Please try again later.';
  static const String requestCancelled = 'Request was cancelled.';
  static const String unexpectedError =
      'An unexpected error occurred. Please try again.';

  // Authentication Errors
  static const String invalidCredentials =
      'Invalid email or password. Please try again.';
  static const String unauthorized =
      'You are not authorized to perform this action.';
  static const String sessionExpired =
      'Your session has expired. Please login again.';
  static const String accountDisabled =
      'Your account has been disabled. Please contact support.';
  static const String emailAlreadyExists =
      'An account with this email already exists.';
  static const String weakPassword =
      'Password is too weak. Please use a stronger password.';
  static const String invalidToken = 'Invalid or expired token.';

  // Validation Errors
  static const String requiredField = 'This field is required.';
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String invalidPhone = 'Please enter a valid phone number.';
  static const String invalidUrl = 'Please enter a valid URL.';
  static const String passwordTooShort =
      'Password must be at least 8 characters long.';
  static const String passwordsDoNotMatch = 'Passwords do not match.';
  static const String invalidFormat = 'Invalid format.';
  static const String valueTooShort = 'Value is too short.';
  static const String valueTooLong = 'Value is too long.';

  // Data Errors
  static const String notFound = 'The requested resource was not found.';
  static const String dataNotFound = 'No data found.';
  static const String invalidData = 'Invalid data received from server.';
  static const String duplicateEntry = 'This entry already exists.';
  static const String conflictError =
      'Conflict detected. Please refresh and try again.';

  // Cache Errors
  static const String cacheError =
      'Failed to load cached data. Please try again.';
  static const String cacheSaveError = 'Failed to save data to cache.';
  static const String cacheRetrieveError = 'Failed to retrieve cached data.';
  static const String cacheClearError = 'Failed to clear cache.';

  // File Errors
  static const String fileNotFound = 'File not found.';
  static const String fileTooLarge = 'File size exceeds the maximum limit.';
  static const String invalidFileType =
      'Invalid file type. Please select a valid file.';
  static const String fileUploadFailed = 'Failed to upload file.';
  static const String fileDownloadFailed = 'Failed to download file.';
  static const String fileReadError = 'Failed to read file.';
  static const String fileWriteError = 'Failed to write file.';

  // Permission Errors
  static const String permissionDenied =
      'Permission denied. Please grant the required permissions.';
  static const String locationPermissionDenied =
      'Location permission denied. Please enable location services.';
  static const String cameraPermissionDenied =
      'Camera permission denied. Please enable camera access.';
  static const String storagePermissionDenied =
      'Storage permission denied. Please enable storage access.';

  // Operation Errors
  static const String operationFailed = 'Operation failed. Please try again.';
  static const String saveFailed = 'Failed to save. Please try again.';
  static const String deleteFailed = 'Failed to delete. Please try again.';
  static const String updateFailed = 'Failed to update. Please try again.';
  static const String loadFailed = 'Failed to load data. Please try again.';

  // Client Errors
  static const String clientNotFound = 'Client not found.';
  static const String clientCreateFailed = 'Failed to create client.';
  static const String clientUpdateFailed = 'Failed to update client.';
  static const String clientDeleteFailed = 'Failed to delete client.';

  // Event Errors
  static const String eventNotFound = 'Event not found.';
  static const String eventCreateFailed = 'Failed to create event.';
  static const String eventUpdateFailed = 'Failed to update event.';
  static const String eventDeleteFailed = 'Failed to delete event.';

  // Draft Errors
  static const String draftNotFound = 'Draft not found.';
  static const String draftSaveFailed = 'Failed to save draft.';
  static const String draftPublishFailed = 'Failed to publish draft.';
  static const String draftDeleteFailed = 'Failed to delete draft.';

  // Generic Messages
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';
  static const String pleaseWait = 'Please wait...';
  static const String loading = 'Loading...';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
}
