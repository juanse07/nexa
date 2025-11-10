// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get jobDataExtractor => 'Extractor de Datos de Turno';

  @override
  String get uploadPdfToExtract =>
      'Sube un PDF o imagen para extraer detalles del turno de catering';

  @override
  String get enterJobDetailsManually =>
      'Ingresa los detalles del turno manualmente para un control preciso';

  @override
  String get createJobsThroughAI =>
      'Crea trabajos mediante conversación natural con IA';

  @override
  String get jobDetails => 'Detalles del Turno';

  @override
  String get jobInformation => 'Información del Turno';

  @override
  String get jobTitle => 'Título del Turno';

  @override
  String get clientName => 'Nombre del Cliente';

  @override
  String get startTime => 'Hora de Inicio';

  @override
  String get endTime => 'Hora de Finalización';

  @override
  String get headcount => 'Cantidad de Personas';

  @override
  String get locationInformation => 'Información de Ubicación';

  @override
  String get locationName => 'Nombre de Ubicación';

  @override
  String get address => 'Dirección';

  @override
  String get city => 'Ciudad';

  @override
  String get state => 'Estado';

  @override
  String get contactName => 'Nombre de Contacto';

  @override
  String get phoneNumber => 'Número de Teléfono';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get notes => 'Notas';

  @override
  String get shift => 'Shift';

  @override
  String get client => 'Cliente';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get location => 'Ubicación';

  @override
  String get phone => 'Teléfono';

  @override
  String jobsTabLabel(int pendingCount, int upcomingCount, int pastCount) {
    return 'Trabajos • $pendingCount pendientes, $upcomingCount próximos, $pastCount pasados';
  }

  @override
  String pendingUpcomingStatus(
    int pendingCount,
    int upcomingCount,
    String baseTime,
  ) {
    return '$pendingCount pendientes • $upcomingCount próximos • $baseTime';
  }

  @override
  String upcomingPastStatus(int upcomingCount, int pastCount, String baseTime) {
    return '$upcomingCount próximos • $pastCount pasados • $baseTime';
  }

  @override
  String get pleaseSelectDate => 'Por favor selecciona una fecha para el turno';

  @override
  String get jobSavedToPending =>
      'Turno guardado como pendiente. Ve a la pestaña Trabajos para revisar.';

  @override
  String get jobDetailsCopied => 'Detalles del turno copiados al portapapeles';

  @override
  String get jobPosted => 'Shift posted';

  @override
  String get sendJobInvitation => 'Enviar Invitación de Turno';

  @override
  String inviteToJob(String name) {
    return 'Invitar a $name a un turno';
  }

  @override
  String get jobInvitationSent => '¡Invitación de turno enviada!';

  @override
  String get jobNotFound => 'Turno no encontrado';

  @override
  String guests(int count) {
    return '$count invitados';
  }

  @override
  String get rolesNeeded => 'Roles Necesarios';

  @override
  String get untitledJob => 'Turno Sin Título';

  @override
  String get expectedHeadcount => 'Cantidad de Personas Esperada';

  @override
  String get contactPhone => 'Teléfono de Contacto';

  @override
  String get contactEmail => 'Correo Electrónico de Contacto';

  @override
  String get errorJobIdMissing => 'Error: Falta el ID del turno...';

  @override
  String get postJob => 'Post Shift';

  @override
  String get setRolesForJob => 'Establecer roles para este turno';

  @override
  String get searchJobs => 'Buscar trabajos...';

  @override
  String get locationTbd => 'Ubicación Por Determinar';

  @override
  String shareJobPrefix(String clientName) {
    return 'Turno: $clientName';
  }

  @override
  String get navCreate => 'Crear';

  @override
  String get navJobs => 'Trabajos';

  @override
  String get navChat => 'Chat';

  @override
  String get navHours => 'Horas';

  @override
  String get navCatalog => 'Catálogo';

  @override
  String get uploadData => 'Subir Datos';

  @override
  String get manualEntry => 'Entrada Manual';

  @override
  String get multiUpload => 'Subida Múltiple';

  @override
  String get aiChat => 'Chat IA';

  @override
  String get chooseFile => 'Elegir Archivo';

  @override
  String get detailedExplanation => 'Explicación Detallada';

  @override
  String get messagesAndTeamMembers => 'Mensajes y miembros del equipo';

  @override
  String get searchNameOrEmail => 'Buscar nombre o correo';

  @override
  String get all => 'Todos';

  @override
  String get bartender => 'Bartender';

  @override
  String get server => 'Servidor';

  @override
  String messages(int count) {
    return 'Mensajes ($count)';
  }

  @override
  String youveBeenInvitedTo(String jobName) {
    return 'Has sido invitado a $jobName';
  }

  @override
  String get hoursApproval => 'Aprobación de Horas';

  @override
  String get needsSheet => 'Necesita Hoja';

  @override
  String needsSheetCount(int count) {
    return '$count Necesita Hoja';
  }

  @override
  String staffCount(int count) {
    return '$count personal';
  }

  @override
  String catalogClientsRoles(int clientCount, int roleCount) {
    return 'Catálogo • $clientCount clientes, $roleCount roles';
  }

  @override
  String get clients => 'Clientes';

  @override
  String get roles => 'Roles';

  @override
  String get tariffs => 'Tarifas';

  @override
  String get addClient => 'Agregar Cliente';

  @override
  String get teams => 'Equipos';

  @override
  String members(int count) {
    return '$count miembros';
  }

  @override
  String pendingInvites(int count) {
    return '$count invitaciones pendientes';
  }

  @override
  String get viewDetails => 'Ver detalles';

  @override
  String get newTeam => 'Nuevo equipo';

  @override
  String get myProfile => 'Mi Perfil';

  @override
  String get settings => 'Configuración';

  @override
  String get manageTeams => 'Gestionar Equipos';

  @override
  String get logout => 'Cerrar Sesión';

  @override
  String get selectFiles => 'Seleccionar Archivos';

  @override
  String get multiSelectTip =>
      'Consejo: Mantén presionado para seleccionar múltiples archivos. O usa Agregar Más para añadir.';

  @override
  String get contactInformation => 'Información de Contacto';

  @override
  String get additionalNotes => 'Notas Adicionales';

  @override
  String get saveJobDetails => 'Guardar Detalles del Turno';

  @override
  String get saveToPending => 'Guardar como Pendiente';

  @override
  String get pending => 'Pendiente';

  @override
  String get upcoming => 'Próximo';

  @override
  String get past => 'Pasado';

  @override
  String get startConversation => 'Iniciar una Conversación';

  @override
  String get aiWillGuideYou => 'La IA te guiará para crear un turno';

  @override
  String get startNewConversation => 'Iniciar Nueva Conversación';

  @override
  String get fecha => 'Fecha';

  @override
  String get hora => 'Hora';

  @override
  String get ubicacion => 'Ubicación';

  @override
  String get direccion => 'Dirección';

  @override
  String jobFor(String clientName) {
    return 'Turno para: $clientName';
  }

  @override
  String get accepted => 'Aceptado';

  @override
  String get invitation => 'Invitación';

  @override
  String get viewJobs => 'Ver Trabajos';

  @override
  String get addToBartender => 'Agregar a Bartender';

  @override
  String get addToServer => 'Agregar a Servidor';

  @override
  String addToRole(String role) {
    return 'Agregar a $role';
  }

  @override
  String get typeMessage => 'Escribe un mensaje...';
}
