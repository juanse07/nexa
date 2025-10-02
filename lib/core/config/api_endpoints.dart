/// API endpoint constants
/// Contains all API endpoint paths and RESTful endpoint builders
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String auth = '/auth';
  static const String users = '/users';
  static const String clients = '/clients';
  static const String events = '/events';
  static const String drafts = '/drafts';
  static const String tariffs = '/tariffs';
  static const String roles = '/roles';
  static const String pendingEvents = '/pending-events';

  // Auth endpoints
  static const String login = '$auth/login';
  static const String logout = '$auth/logout';
  static const String register = '$auth/register';
  static const String refreshToken = '$auth/refresh';
  static const String forgotPassword = '$auth/forgot-password';
  static const String resetPassword = '$auth/reset-password';
  static const String verifyEmail = '$auth/verify-email';
  static const String resendVerification = '$auth/resend-verification';

  // User endpoints
  static const String currentUser = '$users/me';
  static const String updateProfile = '$users/profile';
  static const String changePassword = '$users/change-password';
  static const String deleteAccount = '$users/delete-account';

  /// Get user by ID
  static String userById(String id) => '$users/$id';

  // Client endpoints
  static const String allClients = clients;
  static const String createClient = clients;

  /// Get client by ID
  static String clientById(String id) => '$clients/$id';

  /// Update client by ID
  static String updateClient(String id) => '$clients/$id';

  /// Delete client by ID
  static String deleteClient(String id) => '$clients/$id';

  // Event endpoints
  static const String allEvents = events;
  static const String createEvent = events;

  /// Get event by ID
  static String eventById(String id) => '$events/$id';

  /// Update event by ID
  static String updateEvent(String id) => '$events/$id';

  /// Delete event by ID
  static String deleteEvent(String id) => '$events/$id';

  /// Get events by client ID
  static String eventsByClient(String clientId) => '$events/client/$clientId';

  // Draft endpoints
  static const String allDrafts = drafts;
  static const String createDraft = drafts;

  /// Get draft by ID
  static String draftById(String id) => '$drafts/$id';

  /// Update draft by ID
  static String updateDraft(String id) => '$drafts/$id';

  /// Delete draft by ID
  static String deleteDraft(String id) => '$drafts/$id';

  /// Publish draft by ID
  static String publishDraft(String id) => '$drafts/$id/publish';

  // Tariff endpoints
  static const String allTariffs = tariffs;
  static const String createTariff = tariffs;

  /// Get tariff by ID
  static String tariffById(String id) => '$tariffs/$id';

  /// Update tariff by ID
  static String updateTariff(String id) => '$tariffs/$id';

  /// Delete tariff by ID
  static String deleteTariff(String id) => '$tariffs/$id';

  // Role endpoints
  static const String allRoles = roles;
  static const String createRole = roles;

  /// Get role by ID
  static String roleById(String id) => '$roles/$id';

  /// Update role by ID
  static String updateRole(String id) => '$roles/$id';

  /// Delete role by ID
  static String deleteRole(String id) => '$roles/$id';

  // Pending Events endpoints
  static const String allPendingEvents = pendingEvents;
  static const String createPendingEvent = pendingEvents;

  /// Get pending event by ID
  static String pendingEventById(String id) => '$pendingEvents/$id';

  /// Update pending event by ID
  static String updatePendingEvent(String id) => '$pendingEvents/$id';

  /// Delete pending event by ID
  static String deletePendingEvent(String id) => '$pendingEvents/$id';

  /// Approve pending event by ID
  static String approvePendingEvent(String id) => '$pendingEvents/$id/approve';

  /// Reject pending event by ID
  static String rejectPendingEvent(String id) => '$pendingEvents/$id/reject';
}
