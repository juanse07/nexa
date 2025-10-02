/// API-related constants
class ApiConstants {
  ApiConstants._();

  // HTTP Headers
  static const String authorization = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String accept = 'Accept';
  static const String acceptLanguage = 'Accept-Language';
  static const String cacheControl = 'Cache-Control';
  static const String userAgent = 'User-Agent';
  static const String xApiKey = 'X-API-Key';
  static const String xRequestId = 'X-Request-ID';

  // Content Types
  static const String applicationJson = 'application/json';
  static const String applicationFormUrlEncoded =
      'application/x-www-form-urlencoded';
  static const String multipartFormData = 'multipart/form-data';
  static const String textPlain = 'text/plain';
  static const String applicationPdf = 'application/pdf';
  static const String imageJpeg = 'image/jpeg';
  static const String imagePng = 'image/png';

  // API Versions
  static const String apiVersion = 'v1';
  static const String apiVersionHeader = 'X-API-Version';

  // Auth Headers
  static const String bearerPrefix = 'Bearer';
  static const String basicPrefix = 'Basic';

  // HTTP Methods
  static const String methodGet = 'GET';
  static const String methodPost = 'POST';
  static const String methodPut = 'PUT';
  static const String methodPatch = 'PATCH';
  static const String methodDelete = 'DELETE';

  // Query Parameters
  static const String pageParam = 'page';
  static const String limitParam = 'limit';
  static const String sortParam = 'sort';
  static const String orderParam = 'order';
  static const String searchParam = 'search';
  static const String filterParam = 'filter';

  // Common Response Keys
  static const String dataKey = 'data';
  static const String messageKey = 'message';
  static const String errorKey = 'error';
  static const String errorsKey = 'errors';
  static const String statusKey = 'status';
  static const String successKey = 'success';
  static const String metaKey = 'meta';
  static const String paginationKey = 'pagination';

  // HTTP Status Codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusAccepted = 202;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusMethodNotAllowed = 405;
  static const int statusConflict = 409;
  static const int statusUnprocessableEntity = 422;
  static const int statusTooManyRequests = 429;
  static const int statusInternalServerError = 500;
  static const int statusBadGateway = 502;
  static const int statusServiceUnavailable = 503;
  static const int statusGatewayTimeout = 504;
}
