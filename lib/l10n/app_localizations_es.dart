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
  String get shift => 'Turno';

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
  String get jobPosted => 'Turno publicado';

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
  String get postJob => 'Publicar Turno';

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
  String get navSchedule => 'Horario';

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
  String get server => 'Mesero';

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
  String get addToServer => 'Agregar a Mesero';

  @override
  String addToRole(String role) {
    return 'Agregar a $role';
  }

  @override
  String get typeMessage => 'Escribe un mensaje...';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get retry => 'Reintentar';

  @override
  String get ok => 'Aceptar';

  @override
  String get done => 'Listo';

  @override
  String get close => 'Cerrar';

  @override
  String get remove => 'Eliminar';

  @override
  String get add => 'Agregar';

  @override
  String get share => 'Compartir';

  @override
  String get refresh => 'Actualizar';

  @override
  String get create => 'Crear';

  @override
  String get unknown => 'Desconocido';

  @override
  String get selectAll => 'Seleccionar Todo';

  @override
  String get deselectAll => 'Deseleccionar Todo';

  @override
  String get clearAll => 'Limpiar Todo';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get or => 'o';

  @override
  String get cancel => 'Cancelar';

  @override
  String get approve => 'Aprobar';

  @override
  String get dismiss => 'Descartar';

  @override
  String get apply => 'Aplicar';

  @override
  String get skip => 'Saltar';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String get account => 'Cuenta';

  @override
  String get role => 'Rol';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get signInToContinue => 'Inicia sesión para continuar';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get password => 'Contraseña';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get continueWithPhone => 'Continuar con Teléfono';

  @override
  String get appRoleManager => 'Gerente';

  @override
  String get termsAndPrivacyDisclaimer =>
      'Al continuar, aceptas nuestros\nTérminos de Servicio y Política de Privacidad';

  @override
  String get pleaseEnterEmailAndPassword =>
      'Por favor, ingresa correo y contraseña';

  @override
  String get googleSignInFailed => 'Error al iniciar sesión con Google';

  @override
  String get appleSignInFailed => 'Error al iniciar sesión con Apple';

  @override
  String get emailSignInFailed => 'Error al iniciar sesión con correo';

  @override
  String get phoneSignIn => 'Inicio de Sesión por Teléfono';

  @override
  String get enterVerificationCode => 'Ingresa el código de verificación';

  @override
  String get weWillSendVerificationCode =>
      'Te enviaremos un código de verificación';

  @override
  String get sendVerificationCode => 'Enviar Código de Verificación';

  @override
  String get verifyCode => 'Verificar Código';

  @override
  String get change => 'Cambiar';

  @override
  String get pleaseEnterPhoneNumber =>
      'Por favor, ingresa tu número de teléfono';

  @override
  String get pleaseEnterValidPhoneNumber =>
      'Por favor, ingresa un número de teléfono válido';

  @override
  String get pleaseEnterVerificationCode =>
      'Por favor, ingresa el código de verificación';

  @override
  String get verificationCodeMustBe6Digits =>
      'El código de verificación debe ser de 6 dígitos';

  @override
  String get didntReceiveCodeResend => '¿No recibiste el código? Reenviar';

  @override
  String get welcomeToFlowShift => '¡Bienvenido a FlowShift!';

  @override
  String get personalizeExperienceWithVenues =>
      'Personalicemos tu experiencia buscando lugares populares para eventos en tu área.';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get skipForNow => 'Saltar por ahora';

  @override
  String get whereAreYouLocated => '¿Dónde estás\nubicado?';

  @override
  String get addCitiesWhereYouOperate =>
      'Añade una o más ciudades donde operas. Puedes descubrir lugares para cada ciudad después.';

  @override
  String get settingUpYourCity => 'Configurando tu ciudad...';

  @override
  String settingUpYourCities(int cityCount) {
    return 'Configurando tus $cityCount ciudades...';
  }

  @override
  String get thisWillOnlyTakeAMoment => 'Esto solo tomará un momento...';

  @override
  String get allSet => '¡Todo listo!';

  @override
  String get yourCityConfiguredSuccessfully =>
      '¡Tu ciudad ha sido configurada exitosamente!';

  @override
  String yourCitiesConfiguredSuccessfully(int count) {
    return '¡Tus $count ciudades han sido configuradas exitosamente!';
  }

  @override
  String get discoverVenuesFromSettings =>
      'Puedes descubrir lugares para cada ciudad desde Configuración > Administrar Ciudades.';

  @override
  String get startUsingFlowShift => 'Comenzar a usar FlowShift';

  @override
  String get couldNotDetectLocationEnterManually =>
      'No pudimos detectar tu ubicación. Por favor, ingresa tu ciudad manualmente.';

  @override
  String get locationDetectionFailed =>
      'La detección de ubicación falló. Por favor, ingresa tu ciudad manualmente.';

  @override
  String get pleaseAddAtLeastOneCity => 'Por favor, añade al menos una ciudad';

  @override
  String get anErrorOccurredTryAgain =>
      'Ocurrió un error. Por favor, intenta de nuevo.';

  @override
  String get letsGetYouSetUp => 'Vamos a prepararte';

  @override
  String stepsComplete(int completedCount, int totalSteps) {
    return '$completedCount de $totalSteps pasos completados';
  }

  @override
  String get finishStepsToActivateWorkspace =>
      'Completa estos pasos para activar tu espacio de trabajo FlowShift:';

  @override
  String get statusChipProfile => 'Perfil';

  @override
  String get statusChipTeam => 'Equipo';

  @override
  String get statusChipClient => 'Cliente';

  @override
  String get statusChipRole => 'Rol';

  @override
  String get statusChipTariff => 'Tarifa';

  @override
  String nextUp(String step) {
    return 'Siguiente: $step';
  }

  @override
  String get completeAllStepsForDashboard =>
      'Completa todos los pasos anteriores para acceder al panel completo.';

  @override
  String get addFirstLastNameForStaff =>
      'Añade tu nombre y apellido para que el personal sepa quién eres.';

  @override
  String get reviewProfile => 'Revisar perfil';

  @override
  String get updateProfile => 'Actualizar perfil';

  @override
  String get updateYourProfile => '1. Actualiza tu perfil';

  @override
  String get profileDetailsUpdated => 'Detalles del perfil actualizados.';

  @override
  String get createYourTeamCompany => '2. Crea tu equipo/empresa';

  @override
  String get setupStaffingCompanyExample =>
      'Configura tu empresa de personal (por ejemplo, \"MES - Minneapolis Event Staffing\")';

  @override
  String get teamCompanyName => 'Nombre del equipo/empresa';

  @override
  String get exampleTeamName => 'ej. MES - Minneapolis Event Staffing';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get briefDescriptionStaffingCompany =>
      'Breve descripción de tu empresa de personal';

  @override
  String get completeProfileFirst => 'Completa tu perfil primero';

  @override
  String get createTeam => 'Crear equipo';

  @override
  String get addAnotherTeam => 'Añadir otro equipo';

  @override
  String get createYourFirstClient => '3. Crea tu primer cliente';

  @override
  String get needAtLeastOneClient =>
      'Necesitas al menos un cliente antes de poder asignar personal a eventos.';

  @override
  String get exampleClientName => 'ej. Bluebird Catering';

  @override
  String get completeProfileAndTeamFirst =>
      'Completa tu perfil y equipo primero';

  @override
  String get createClient => 'Crear cliente';

  @override
  String get addAnotherClient => 'Agregar otro cliente';

  @override
  String get addAtLeastOneRole => '4. Añade al menos un rol';

  @override
  String get rolesHelpMatchStaff =>
      'Los roles ayudan a asignar personal al trabajo correcto (mesero, chef, bartender...).';

  @override
  String get roleName => 'Nombre del rol';

  @override
  String get exampleRoleName => 'ej. Mesero Principal';

  @override
  String get finishPreviousStepsFirst =>
      'Completa los pasos anteriores primero';

  @override
  String get createRole => 'Crear rol';

  @override
  String get addAnotherRole => 'Añadir otro rol';

  @override
  String get setYourFirstTariff => '5. Establece tu primera tarifa';

  @override
  String get setRateForBilling =>
      'Establece una tarifa para que las asignaciones de personal sepan qué cobrar.';

  @override
  String get createClientFirst => 'Crea un cliente primero';

  @override
  String get createRoleFirst => 'Crea un rol primero';

  @override
  String get hourlyRateUsd => 'Tarifa por hora (USD)';

  @override
  String get exampleHourlyRate => 'ej. 24.00';

  @override
  String get adjustTariffsInCatalog =>
      'Puedes ajustar esto después en Catálogo > Tarifas';

  @override
  String get saveTariff => 'Guardar tarifa';

  @override
  String get addAnotherTariff => 'Añadir otra tarifa';

  @override
  String get enterTeamNameToContinue =>
      'Ingresa un nombre de equipo/empresa para continuar';

  @override
  String get teamCreatedSuccessfully => '¡Equipo creado exitosamente!';

  @override
  String get failedToCreateTeam => 'Error al crear equipo';

  @override
  String get enterClientNameToContinue =>
      'Ingresa un nombre de cliente para continuar';

  @override
  String get clientCreated => 'Cliente creado';

  @override
  String get failedToCreateClient => 'Error al crear cliente';

  @override
  String get enterRoleNameToContinue =>
      'Ingresa un nombre de rol para continuar';

  @override
  String get roleCreated => 'Rol creado';

  @override
  String get failedToCreateRole => 'Error al crear rol';

  @override
  String get createClientAndRoleBeforeTariff =>
      'Crea un cliente y un rol antes de añadir una tarifa';

  @override
  String get selectClientAndRole => 'Selecciona un cliente y un rol';

  @override
  String get enterValidHourlyRate =>
      'Ingresa una tarifa por hora válida (ej. 22.50)';

  @override
  String get tariffSaved => 'Tarifa guardada';

  @override
  String get failedToSaveTariff => 'Error al guardar tarifa';

  @override
  String get failedToOpenProfile => 'Error al abrir perfil';

  @override
  String get navAttendance => 'Asistencia';

  @override
  String get navStats => 'Estadísticas';

  @override
  String get welcomeBack => '¡Bienvenido de nuevo!';

  @override
  String get manageYourEvents => 'Administra tus eventos';

  @override
  String get featureChatDesc => 'enviar trabajos a través del chat';

  @override
  String get featureAIChatDesc => 'crear, actualizar, hacer preguntas';

  @override
  String get featureJobsDesc => 'Administra tus tarjetas creadas';

  @override
  String get featureTeamsDesc => 'invita personas a unirse';

  @override
  String get featureHoursDesc => 'Rastrear horas de trabajo del equipo';

  @override
  String get featureCatalogDesc => 'crear clientes, roles y tarifas';

  @override
  String get quickActionUpload => 'Subir';

  @override
  String get quickActionTimesheet => 'Hoja de Tiempo';

  @override
  String get teamMembers => 'Miembros del Equipo';

  @override
  String get hours => 'Horas';

  @override
  String get recentActivity => 'Actividad Reciente';

  @override
  String get confirmLogoutMessage =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get attendanceTitle => 'Asistencia';

  @override
  String get forceClockOut => 'Forzar Salida';

  @override
  String confirmClockOutMessage(String staffName) {
    return '¿Estás seguro de que quieres marcar salida de $staffName?';
  }

  @override
  String get clockOut => 'Marcar Salida';

  @override
  String staffClockedOutSuccessfully(String staffName) {
    return '$staffName marcó salida exitosamente';
  }

  @override
  String get failedToClockOutStaff => 'Error al marcar salida del personal';

  @override
  String viewingHistoryFor(String staffName) {
    return 'Viendo historial de $staffName';
  }

  @override
  String viewingDetailsFor(String staffName) {
    return 'Viendo detalles de $staffName';
  }

  @override
  String get noAttendanceRecords => 'Sin registros de asistencia';

  @override
  String get tryAdjustingFilters => 'Intenta ajustar tus filtros';

  @override
  String get recordsAppearWhenStaffClockIn =>
      'Los registros aparecerán aquí cuando el personal marque entrada';

  @override
  String get clearFilters => 'Limpiar Filtros';

  @override
  String get analyzing => 'Analizando...';

  @override
  String get aiAnalysis => 'Análisis con IA';

  @override
  String get failedToLoadData => 'Error al cargar datos';

  @override
  String get bulkClockIn => 'Entrada Masiva';

  @override
  String get pleaseSelectAtLeastOneStaff =>
      'Por favor selecciona al menos un miembro del personal';

  @override
  String successfullyClockedIn(int successful, int total) {
    return 'Entrada exitosa de $successful de $total personal';
  }

  @override
  String get failedBulkClockIn => 'Error al realizar la entrada masiva';

  @override
  String get noAcceptedStaffForEvent =>
      'Sin personal aceptado para este evento';

  @override
  String get overrideNoteOptional => 'Nota de anulación (opcional)';

  @override
  String get groupCheckInHint => 'ej., Entrada grupal en la entrada';

  @override
  String clockInStaffCount(int count) {
    return 'Marcar Entrada de $count Personal';
  }

  @override
  String get bulkClockInResults => 'Resultados de Entrada Masiva';

  @override
  String get alreadyClockedIn => 'Ya marcó entrada';

  @override
  String get flaggedAttendance => 'Asistencia Marcada';

  @override
  String get approved => 'Aprobado';

  @override
  String get dismissed => 'Descartado';

  @override
  String get noPendingFlags => '¡Sin banderas pendientes!';

  @override
  String get noFlaggedEntriesFound => 'Sin entradas marcadas encontradas';

  @override
  String get allEntriesLookNormal =>
      'Todas las entradas de asistencia se ven normales';

  @override
  String get reviewFlag => 'Revisar Bandera';

  @override
  String get reviewNotesOptional => 'Notas de Revisión (opcional)';

  @override
  String get addNotesAboutReview =>
      'Añade cualquier nota sobre esta revisión...';

  @override
  String get unknownStaff => 'Personal Desconocido';

  @override
  String get unknownEvent => 'Evento Desconocido';

  @override
  String get clockInTime => 'Entrada';

  @override
  String get clockOutTime => 'Salida';

  @override
  String get durationLabel => 'Duración';

  @override
  String get expectedDuration => 'Esperado';

  @override
  String get unusualHours => 'Horas Inusuales';

  @override
  String get excessiveDuration => 'Duración Excesiva';

  @override
  String get lateClockOut => 'Salida Tardía';

  @override
  String get locationMismatch => 'Discrepancia de Ubicación';

  @override
  String get filterAttendance => 'Filtrar Asistencia';

  @override
  String get dateRange => 'Rango de Fechas';

  @override
  String get last7Days => 'Últimos 7 Días';

  @override
  String get custom => 'Personalizado';

  @override
  String get event => 'Evento';

  @override
  String get allEvents => 'Todos los Eventos';

  @override
  String get status => 'Estado';

  @override
  String get applyFilters => 'Aplicar Filtros';

  @override
  String get working => 'Trabajando';

  @override
  String get flags => 'Banderas';

  @override
  String get currentlyWorking => 'Actualmente Trabajando';

  @override
  String get noStaffWorking => 'Sin personal trabajando';

  @override
  String get staffAppearsWhenClockIn =>
      'El personal aparecerá aquí cuando marquen entrada';

  @override
  String get history => 'Historial';

  @override
  String get onSite => 'En el sitio';

  @override
  String get autoClockOut => 'Salida automática';

  @override
  String get completed => 'Completado';

  @override
  String get calendarToday => 'Hoy';

  @override
  String get calendarTomorrow => 'Mañana';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarViewTwoWeeks => '2 Sem';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get noUpcomingEvents => 'Sin eventos próximos';

  @override
  String get scheduleIsClear => 'Tu horario está libre hacia adelante';

  @override
  String get hidePastEvents => 'Ocultar eventos pasados';

  @override
  String showPastDaysWithEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $countString días pasados con eventos',
      one: 'Mostrar 1 día pasado con eventos',
    );
    return '$_temp0';
  }

  @override
  String get noEventsThisDay => 'Sin eventos este día';

  @override
  String get freeDayLabel => 'Día libre';

  @override
  String get nothingWasScheduled => 'Nada fue programado';

  @override
  String get nothingScheduledYet => 'Nada programado aún';

  @override
  String get couldNotLoadEvents => 'No se pudieron cargar los eventos';

  @override
  String noFullTerminology(String terminology) {
    return 'Sin $terminology completos aún';
  }

  @override
  String get whenPositionsFilled =>
      'Cuando todos los puestos estén llenos, aparecerán aquí';

  @override
  String expiredUnfulfilledEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString eventos vencidos sin cubrir',
      one: '1 evento vencido sin cubrir',
    );
    return '$_temp0';
  }

  @override
  String get pastEventsNeverFullyStaffed =>
      'Eventos pasados que nunca fueron completamente cubiertos';

  @override
  String expiredUnfulfilledTitle(int count) {
    return 'Vencidos sin Cubrir ($count)';
  }

  @override
  String noCompletedTerminology(String terminology) {
    return 'Sin $terminology completados aún';
  }

  @override
  String completedTerminologyAppear(String terminology) {
    return 'Los $terminology completados aparecerán aquí';
  }

  @override
  String noPendingTerminology(String terminology) {
    return 'Sin $terminology pendientes';
  }

  @override
  String draftTerminologyWaiting(String terminology) {
    return 'Los $terminology en borrador esperando ser publicados aparecerán aquí';
  }

  @override
  String noPostedTerminology(String terminology) {
    return 'Sin $terminology publicados';
  }

  @override
  String postedTerminologyWaiting(String terminology) {
    return 'Los $terminology publicados esperando personal aparecerán aquí';
  }

  @override
  String get flagged => 'Marcado';

  @override
  String get noShow => 'No se presentó';

  @override
  String get notSpecified => 'No especificado';

  @override
  String get clockIn => 'Marcar Entrada';

  @override
  String get verifiedOnSite => 'Verificado en el sitio';

  @override
  String get weeklyHours => 'Horas Semanales';

  @override
  String get noDataForPeriod => 'Sin datos para este período';

  @override
  String get failedToLoadFlaggedAttendance =>
      'Error al cargar asistencia marcada';

  @override
  String get failedToUpdateFlag => 'Error al actualizar la bandera';

  @override
  String get stats => 'Estadísticas';

  @override
  String get failedToLoadStatistics => 'Error al cargar estadísticas';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mes';

  @override
  String get year => 'Año';

  @override
  String get allTime => 'Todo el Tiempo';

  @override
  String get downloadReport => 'Descargar reporte';

  @override
  String get downloadPdf => 'Descargar PDF';

  @override
  String get downloadWord => 'Descargar Word';

  @override
  String get analyzingYourData => 'Analizando tus datos...';

  @override
  String get failedToGenerate => 'Error al generar';

  @override
  String get payrollSummary => 'Resumen de Nómina';

  @override
  String staffMembersCount(int count) {
    return '$count miembros del personal';
  }

  @override
  String get viewAll => 'Ver Todo';

  @override
  String get totalHours => 'Horas Totales';

  @override
  String get totalPayroll => 'Nómina Total';

  @override
  String get averagePerStaff => 'Promedio/Personal';

  @override
  String get topEarners => 'Mayores Ingresos';

  @override
  String get noPayrollDataForPeriod => 'Sin datos de nómina para este período';

  @override
  String shiftsAndHours(int shifts, String hours) {
    return '$shifts turnos • ${hours}h';
  }

  @override
  String get topPerformers => 'Mejores Desempeños';

  @override
  String get basedOnShiftsCompleted => 'Basado en turnos completados';

  @override
  String get approveHours => 'Aprobar Horas';

  @override
  String get uploadSignInSheet => 'Subir Hoja de Asistencia';

  @override
  String get takePhotoOrUploadSheet =>
      'Toma una foto o sube la hoja de entrada/salida del cliente';

  @override
  String get camera => 'Cámara';

  @override
  String get gallery => 'Galería';

  @override
  String get analyzeWithAi => 'Analizar con IA';

  @override
  String get analyzingSignInSheetWithAi =>
      'Analizando hoja de asistencia con IA...';

  @override
  String get extractedStaffHours => 'Horas de Personal Extraídas';

  @override
  String get reviewAndEditBeforeSubmitting => 'Revisa y edita antes de enviar';

  @override
  String get signInLabel => 'Entrada';

  @override
  String get signOutLabel => 'Salida';

  @override
  String get notAvailable => 'N/D';

  @override
  String hoursCount(String hours) {
    return '$hours horas';
  }

  @override
  String get bulkApprove => 'Aprobar en Lote';

  @override
  String approveHoursForAllStaff(int count) {
    return '¿Aprobar horas para los $count miembros del personal?';
  }

  @override
  String get approveAll => 'Aprobar Todo';

  @override
  String get nameMatchingResults => 'Resultados de Coincidencia de Nombres';

  @override
  String staffMembersMatched(int processed, int total) {
    return '$processed/$total miembros del personal coinciden';
  }

  @override
  String editHoursFor(String name) {
    return 'Editar Horas - $name';
  }

  @override
  String get signInTime => 'Hora de Entrada';

  @override
  String get signOutTime => 'Hora de Salida';

  @override
  String get approvedHours => 'Horas Aprobadas';

  @override
  String get optionalNotes => 'Notas opcionales';

  @override
  String get noHoursMatched =>
      'No se encontraron coincidencias de horas. Verifica los nombres en la hoja.';

  @override
  String get noHoursApproved =>
      'No se aprobaron horas. Revisa los resultados de coincidencia arriba.';

  @override
  String get failedToBulkApprove => 'Error al aprobar en lote';

  @override
  String get analysisFailed => 'Error en el análisis';

  @override
  String get failedToPickImage => 'Error al seleccionar imagen';

  @override
  String get failedToLoadEvents => 'Error al cargar eventos';

  @override
  String get unknownError => 'Error desconocido';

  @override
  String get allCaughtUp => '¡Todo al Día!';

  @override
  String get noEventsNeedApproval =>
      'No hay eventos que necesiten aprobación de horas en este momento.';

  @override
  String pendingReviewCount(int count) {
    return '$count Pendientes de Revisión';
  }

  @override
  String get pendingReview => 'Pendiente de Revisión';

  @override
  String get dateUnknown => 'Fecha desconocida';

  @override
  String get manualHoursEntry => 'Entrada Manual de Horas';

  @override
  String selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get searchStaffByNameEmail => 'Buscar personal por nombre o correo';

  @override
  String get failedToLoadUsers => 'Error al cargar usuarios';

  @override
  String get failedToSearchUsers => 'Error al buscar usuarios';

  @override
  String get noUsersFound => 'Sin usuarios encontrados';

  @override
  String submitHoursCount(int count) {
    return 'Enviar Horas ($count)';
  }

  @override
  String hoursForStaff(String name) {
    return 'Horas para $name';
  }

  @override
  String get signInTimeRequired => 'Hora de Entrada *';

  @override
  String get notSet => 'No configurado';

  @override
  String get signOutTimeRequired => 'Hora de Salida *';

  @override
  String totalHoursFormat(String hours) {
    return 'Total: $hours horas';
  }

  @override
  String get hoursSubmittedApprovedSuccess =>
      'Horas enviadas y aprobadas exitosamente';

  @override
  String get failedToSubmitHours => 'Error al enviar horas';

  @override
  String get pleaseEnterSignInSignOut =>
      'Por favor, ingresa hora de entrada y salida para todo el personal seleccionado';

  @override
  String get createTeamTitle => 'Crear Equipo';

  @override
  String get teamNameLabel => 'Nombre del equipo';

  @override
  String get enterTeamNameError => 'Ingresa un nombre de equipo';

  @override
  String get deleteTeamConfirmation => '¿Eliminar equipo?';

  @override
  String get deleteTeamWarning =>
      'Eliminar este equipo lo eliminará permanentemente. Los eventos que lo referencien bloquearán la eliminación.';

  @override
  String get teamDeleted => 'Equipo eliminado';

  @override
  String get failedToDeleteTeam => 'Error al eliminar equipo';

  @override
  String get noTeamsYet =>
      'Sin equipos aún. Toca \"Nuevo equipo\" para crear uno.';

  @override
  String get untitledTeam => 'Equipo sin título';

  @override
  String get coManager => 'Co-Gerente';

  @override
  String get inviteByEmail => 'Invitar por correo';

  @override
  String get messageOptional => 'Mensaje (opcional)';

  @override
  String get sendInvite => 'Enviar invitación';

  @override
  String get failedToSendInvite => 'Error al enviar invitación';

  @override
  String inviteSentTo(String email) {
    return 'Invitación enviada a $email';
  }

  @override
  String get revokeInviteLink => 'Revocar Enlace de Invitación';

  @override
  String get revokeInviteLinkConfirmation =>
      'Esto impedirá que alguien use este enlace para unirse. ¿Continuar?';

  @override
  String get revoke => 'Revocar';

  @override
  String get inviteLinkRevoked => 'Enlace de invitación revocado';

  @override
  String get usageLog => 'Registro de Uso';

  @override
  String get noUsageRecorded => 'Sin uso registrado aún.';

  @override
  String get errorLoadingUsage => 'Error al cargar uso';

  @override
  String get publicLinkCreated => '¡Enlace Público Creado!';

  @override
  String get publicLinkDescription =>
      'Comparte este enlace en redes sociales para reclutar nuevos miembros del equipo. Todos los solicitantes requerirán tu aprobación.';

  @override
  String get linkCopied => '¡Enlace copiado!';

  @override
  String get codeLabel => 'Código:';

  @override
  String get codeCopied => '¡Código copiado!';

  @override
  String get shareJoinTeam => 'Únete a nuestro equipo en FlowShift';

  @override
  String get addCoManager => 'Agregar Co-Gerente';

  @override
  String get addCoManagerInstructions =>
      'Ingresa el correo de un gerente para agregarlo como co-gerente. Deben tener ya una cuenta de FlowShift Manager.';

  @override
  String get managerEmailLabel => 'Correo del gerente';

  @override
  String get enterEmailError => 'Ingresa un correo';

  @override
  String get enterValidEmailError => 'Ingresa un correo válido';

  @override
  String get coManagerAdded => 'Co-gerente agregado';

  @override
  String get removeCoManager => 'Eliminar co-gerente';

  @override
  String removeCoManagerConfirmation(String name) {
    return '¿Eliminar a $name como co-gerente?';
  }

  @override
  String get coManagerRemoved => 'Co-gerente eliminado';

  @override
  String get userMissingProviderError =>
      'El usuario no tiene información de proveedor/sujeto';

  @override
  String get addTeamMember => 'Agregar miembro del equipo';

  @override
  String get searchByNameOrEmail => 'Buscar por nombre o correo';

  @override
  String get noUsersFoundTryAnother =>
      'Sin usuarios encontrados. Intenta otra búsqueda.';

  @override
  String get memberChip => 'Miembro';

  @override
  String addedToTeam(String name) {
    return '$name agregado al equipo';
  }

  @override
  String get failedToAddMember => 'Error al agregar miembro';

  @override
  String get inviteCancelled => 'Invitación cancelada';

  @override
  String get failedToCancelInvite => 'Error al cancelar invitación';

  @override
  String get failedToLoadTeamData =>
      'No se pudieron cargar los datos del equipo';

  @override
  String get membersSection => 'Miembros';

  @override
  String get noActiveMembersYet => 'Sin miembros activos aún.';

  @override
  String get pendingMember => 'Miembro pendiente';

  @override
  String get coManagersSection => 'Co-Gerentes';

  @override
  String get noCoManagersYet => 'Aún no hay co-gerentes.';

  @override
  String get removeCoManagerTooltip => 'Eliminar co-gerente';

  @override
  String get invitesSection => 'Invitaciones';

  @override
  String get inviteLinkButton => 'Enlace de Invitación';

  @override
  String get publicLinkButton => 'Enlace Público';

  @override
  String get emailInviteButton => 'Correo';

  @override
  String get noInvitesYet => 'Aún no hay invitaciones.';

  @override
  String get pendingApplicants => 'Solicitantes Pendientes';

  @override
  String get activeInviteLinks => 'Enlaces de Invitación Activos';

  @override
  String get publicBadge => 'PÚBLICO';

  @override
  String get usedLabel => 'Usado:';

  @override
  String get unlimitedUses => '(ilimitado)';

  @override
  String get joinsLabel => 'uniones';

  @override
  String get denyApplicant => 'Rechazar Solicitante';

  @override
  String get denyApplicantConfirmation =>
      '¿Estás seguro de que quieres rechazar a este solicitante?';

  @override
  String get deny => 'Rechazar';

  @override
  String get applicantApproved => '¡Solicitante aprobado!';

  @override
  String get applicantDenied => 'Solicitante rechazado';

  @override
  String get chatTitle => 'Chats';

  @override
  String get searchConversations => 'Buscar conversaciones...';

  @override
  String get failedToLoadConversations => 'Error al cargar conversaciones';

  @override
  String get noConversationsYet => 'Sin conversaciones aún';

  @override
  String get startChattingWithTeam =>
      'Comienza a chatear con tu equipo para ver tus mensajes aquí';

  @override
  String get managerBadge => 'Gerente';

  @override
  String get noMessagesYet => 'Sin mensajes aún';

  @override
  String get addMembersToStartChatting =>
      'Agrega miembros a tu equipo para comenzar a chatear';

  @override
  String get newChat => 'Nuevo Chat';

  @override
  String get searchContacts => 'Buscar contactos...';

  @override
  String get failedToLoadContacts => 'Error al cargar contactos';

  @override
  String get noContactsMatch => 'Ningún contacto coincide con tu búsqueda';

  @override
  String get noTeamMembersYet => 'Sin miembros del equipo aún';

  @override
  String get active => 'Activo';

  @override
  String get valerioAssistant => 'Asistente Valerio';

  @override
  String get valerioAssistantDesc =>
      'Crea eventos, gestiona trabajos y obtén ayuda instantánea';

  @override
  String get typing => 'escribiendo...';

  @override
  String get failedToSendMessage => 'Error al enviar mensaje';

  @override
  String get sendMessageToStartConversation =>
      'Envía un mensaje para comenzar la conversación';

  @override
  String get failedToLoadMessages => 'Error al cargar mensajes';

  @override
  String staffAcceptedInvitation(String name) {
    return '¡$name aceptó la invitación!';
  }

  @override
  String staffDeclinedInvitation(String name) {
    return '$name rechazó la invitación';
  }

  @override
  String get failedToSendInvitation => 'Error al enviar invitación';

  @override
  String get noUpcomingJobs => 'Sin trabajos próximos';

  @override
  String get noJobsMatch => 'Ningún trabajo coincide con tu búsqueda';

  @override
  String get unknownClient => 'Cliente Desconocido';

  @override
  String get noVenueSpecified => 'Sin lugar especificado';

  @override
  String get noDateSpecified => 'Sin fecha especificada';

  @override
  String get selectRoleForStaffMember =>
      'Selecciona un rol para el miembro del personal:';

  @override
  String get noRolesAvailable => 'Sin roles disponibles para este trabajo';

  @override
  String get sending => 'Enviando...';

  @override
  String get sendInvitation => 'Enviar Invitación';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get waitingForResponse => 'Esperando respuesta...';

  @override
  String callTime(String time) {
    return 'Hora de llegada: $time';
  }

  @override
  String acceptedStaffCount(int count) {
    return 'Personal Aceptado ($count)';
  }

  @override
  String get workingHoursSheet => 'Hoja de Horas de Trabajo';

  @override
  String get hoursSheetPdf => 'Hoja de Horas (PDF)';

  @override
  String get hoursSheetWord => 'Hoja de Horas (Word)';

  @override
  String get member => 'Miembro';

  @override
  String staffIdDisplay(String id) {
    return 'ID: $id';
  }

  @override
  String get removeStaffMember => 'Eliminar Miembro del Personal';

  @override
  String get confirmRemoveStaff =>
      '¿Estás seguro de que deseas eliminar a este miembro del personal del evento?';

  @override
  String get staffRemovedSuccess =>
      'Miembro del personal eliminado exitosamente';

  @override
  String get failedToRemoveStaff => 'Error al eliminar miembro del personal';

  @override
  String confirmClockIn(String staffName) {
    return '¿Marcar entrada de $staffName para este evento?';
  }

  @override
  String alreadyClockedInName(String staffName) {
    return '$staffName ya marcó entrada';
  }

  @override
  String clockedInSuccess(String staffName) {
    return '$staffName marcó entrada exitosamente';
  }

  @override
  String get clockInFailed => 'Error al marcar entrada. Intenta de nuevo.';

  @override
  String get publish => 'Publicar';

  @override
  String get editDetails => 'Editar Detalles';

  @override
  String get keepOpenAfterEvent => 'Mantener Abierto Después del Evento';

  @override
  String get preventAutoCompletion =>
      'Prevenir finalización automática cuando pase la fecha del evento';

  @override
  String get moveToDrafts => 'Mover a Borradores';

  @override
  String get clockInStaff => 'Marcar Entrada del Personal';

  @override
  String get openToAllStaff => 'Abierto para Todo el Personal';

  @override
  String moveToDraftsWithStaff(int count) {
    return 'Esto hará:\n• Eliminar a los $count miembros del personal aceptados\n• Enviarles una notificación\n• Ocultar el trabajo de la vista del personal\n\nPuedes republicarlo después.';
  }

  @override
  String get moveToDraftsNoStaff =>
      'Esto ocultará el trabajo de la vista del personal. Puedes republicarlo después.';

  @override
  String eventMovedToDrafts(String name) {
    return '¡$name movido a borradores!';
  }

  @override
  String get failedToMoveToDrafts => 'Error al mover a borradores';

  @override
  String get eventStaysOpen =>
      'El evento permanecerá abierto después de la finalización';

  @override
  String get eventAutoCompletes =>
      'El evento se completará automáticamente cuando haya pasado';

  @override
  String get failedToUpdate => 'Error al actualizar';

  @override
  String get failedToGenerateSheet => 'Error al generar hoja';

  @override
  String confirmOpenToAll(String name) {
    return '¿Hacer que \"$name\" sea visible para todos los miembros del personal?\n\nEsto cambiará el trabajo de privado (solo invitado) a público, permitiendo que todos los miembros del equipo lo vean y acepten.';
  }

  @override
  String get openToAll => 'Abrir a Todos';

  @override
  String eventNowOpenToAll(String name) {
    return '¡$name ahora está abierto para todo el personal!';
  }

  @override
  String get failedToMakePublic => 'Error al hacer público';

  @override
  String get vacanciesLeft => 'disponibles';

  @override
  String get manageYourPreferences => 'Administra tus preferencias';

  @override
  String get workTerminology => 'Terminología del Trabajo';

  @override
  String get howPreferWorkAssignments =>
      '¿Cómo prefieres llamar a tus asignaciones de trabajo?';

  @override
  String get jobs => 'Empleos';

  @override
  String get jobsExample => 'ej., \"Mis Empleos\", \"Crear Empleo\"';

  @override
  String get shifts => 'Turnos';

  @override
  String get shiftsExample => 'ej., \"Mis Turnos\", \"Crear Turno\"';

  @override
  String get events => 'Eventos';

  @override
  String get eventsExample => 'ej., \"Mis Eventos\", \"Crear Evento\"';

  @override
  String get saveTerminology => 'Guardar Terminología';

  @override
  String get terminologyUpdateInfo =>
      'Esto actualizará cómo aparecen las asignaciones de trabajo en toda la aplicación';

  @override
  String get venuesUpdatedSuccess => '¡Lugares actualizados exitosamente!';

  @override
  String get terminologyUpdatedSuccess =>
      '¡Terminología actualizada exitosamente!';

  @override
  String get locationVenues => 'Ubicación y Lugares';

  @override
  String get cities => 'Ciudades';

  @override
  String get citiesConfigured => 'ciudades configuradas';

  @override
  String get venues => 'Lugares';

  @override
  String get discovered => 'descubiertos';

  @override
  String get lastUpdated => 'Última Actualización';

  @override
  String get noCitiesConfiguredDescription =>
      'No hay ciudades configuradas aún. Agrega ciudades para descubrir lugares y ayudar a la IA a sugerir ubicaciones precisas de eventos en tu área.';

  @override
  String get manageCities => 'Administrar Ciudades';

  @override
  String get addCities => 'Agregar Ciudades';

  @override
  String viewAllVenues(int count) {
    return 'Ver los $count Lugares';
  }

  @override
  String get addNewVenue => 'Agregar Nuevo Lugar';

  @override
  String get venueAddedSuccess => '¡Lugar agregado exitosamente!';

  @override
  String daysAgo(int days) {
    return 'hace $days días';
  }

  @override
  String get failedToLoadProfile =>
      'Error al cargar el perfil. Por favor, intenta de nuevo en unos minutos.';

  @override
  String get failedToUploadImage => 'Error al cargar la imagen';

  @override
  String get newLookSaved => '¡Nuevo aspecto guardado!';

  @override
  String get failedToSave => 'Error al guardar';

  @override
  String get profilePictureUpdated => '¡Foto de perfil actualizada!';

  @override
  String get deleteCreationConfirm => '¿Eliminar creación?';

  @override
  String get deleteCreationMessage => 'Esto la eliminará de tu galería.';

  @override
  String get creationDeleted => 'Creación eliminada';

  @override
  String get failedToDelete => 'Error al eliminar';

  @override
  String get revertedToOriginal => 'Se restauró a la foto original';

  @override
  String get failedToRevert => 'Error al restaurar';

  @override
  String get profileUpdated => 'Perfil actualizado';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get appIdOptional => 'ID de aplicación (9 dígitos, opcional)';

  @override
  String get linkedAccounts => 'Cuentas Vinculadas';

  @override
  String get primary => 'Primaria';

  @override
  String get linkAccount => 'Vincular';

  @override
  String get phoneNumberLinkedSuccess =>
      '¡Número de teléfono vinculado exitosamente!';

  @override
  String get upload => 'Subir';

  @override
  String get glowUp => 'Transformar';

  @override
  String get originalPhoto => 'Foto Original';

  @override
  String get myCreations => 'Mis Creaciones';

  @override
  String get viewFullSize => 'Ver Tamaño Completo';

  @override
  String get useThisPhoto => 'Usar Esta Foto';

  @override
  String get linkPhoneNumber => 'Vincular Número de Teléfono';

  @override
  String get addPhoneSigninMethod =>
      'Agrega un número de teléfono como método de inicio de sesión alternativo';

  @override
  String get sixDigitCode => 'Código de 6 dígitos';

  @override
  String get verifyAndLink => 'Verificar y Vincular';

  @override
  String get verificationFailed => 'Verificación fallida';

  @override
  String get invalidPhoneNumberFormat =>
      'Formato de número de teléfono inválido';

  @override
  String get tooManyAttempts => 'Demasiados intentos. Intenta más tarde.';

  @override
  String get enterSixDigitCode => 'Por favor, ingresa el código de 6 dígitos';

  @override
  String get noVerificationInProgress => 'No hay verificación en progreso';

  @override
  String get invalidCode => 'Código inválido. Verifica e intenta de nuevo.';

  @override
  String get codeExpired => 'El código expiró. Solicita uno nuevo.';

  @override
  String get firebaseAuthFailed => 'La autenticación de Firebase falló';

  @override
  String get failedToGetAuthToken =>
      'Error al obtener el token de autenticación';

  @override
  String get failedToLinkPhoneNumber =>
      'Error al vincular el número de teléfono';

  @override
  String get failedToLink => 'Error al vincular';

  @override
  String get failedToSendCode => 'Error al enviar código';

  @override
  String get welcomeFlowShiftPro =>
      '¡Bienvenido a FlowShift Pro! Todas las funciones comerciales desbloqueadas.';

  @override
  String get purchaseCancelledFailed =>
      'La compra fue cancelada o falló. Por favor, intenta de nuevo.';

  @override
  String get subscriptionRestoredSuccess =>
      '¡Suscripción restaurada exitosamente!';

  @override
  String get noActiveSubscription =>
      'No se encontró ninguna suscripción activa para restaurar.';

  @override
  String get restoreError => 'Error de restauración';

  @override
  String get upgradeToPro => 'Actualizar a Pro';

  @override
  String get scaleYourBusiness => 'Escala tu Negocio';

  @override
  String get unlimitedTeamMembers => 'Miembros del equipo ilimitados';

  @override
  String get noLimitsStaffSize => 'Sin límites en el tamaño del personal';

  @override
  String get unlimitedEvents => 'Eventos ilimitados';

  @override
  String get createManyEvents => 'Crea tantos eventos como necesites';

  @override
  String get advancedAnalytics => 'Análisis avanzados';

  @override
  String get insightsReports => 'Información y reportes para tu negocio';

  @override
  String get prioritySupport => 'Soporte prioritario';

  @override
  String get getHelpWhenNeeded => 'Obtén ayuda cuando la necesites';

  @override
  String get allFutureProFeatures => 'Todas las futuras funciones Pro';

  @override
  String get earlyAccessCapabilities =>
      'Acceso anticipado a nuevas capacidades';

  @override
  String get perMonth => 'por mes';

  @override
  String get cancelAnytimeNoCommitments =>
      'Cancela en cualquier momento • Sin compromisos';

  @override
  String get restorePurchase => 'Restaurar Compra';

  @override
  String get freeTierLimits => 'Límites del Nivel Gratuito';

  @override
  String get freeTierLimitsList =>
      '• Máximo 25 miembros del equipo\n• 10 eventos por mes\n• Sin acceso a análisis';

  @override
  String get subscriptionTermsDisclaimer =>
      'Al suscribirte, aceptas nuestros Términos de Servicio y Política de Privacidad. La suscripción se renueva automáticamente a menos que se cancele al menos 24 horas antes del final del período actual.';

  @override
  String get notAuthenticated => 'No autenticado';

  @override
  String get failedToLoadVenues => 'Error al cargar lugares';

  @override
  String get venueAddedSuccessfully => '¡Lugar agregado exitosamente!';

  @override
  String get venueUpdatedSuccessfully => '¡Lugar actualizado exitosamente!';

  @override
  String get venueRemovedSuccessfully => '¡Lugar eliminado exitosamente!';

  @override
  String get failedToDeleteVenue => 'Error al eliminar lugar';

  @override
  String get removeVenueConfirmation => '¿Eliminar Lugar?';

  @override
  String confirmRemoveVenue(String name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get myVenues => 'Mis Lugares';

  @override
  String get addVenue => 'Agregar Lugar';

  @override
  String get noVenuesYet => 'Sin lugares aún';

  @override
  String get addFirstVenueOrDiscover =>
      'Agrega tu primer lugar o ejecuta el descubrimiento de lugares';

  @override
  String get addFirstVenue => 'Agregar Primer Lugar';

  @override
  String get yourArea => 'Tu Área';

  @override
  String get placesSource => 'Places';

  @override
  String get manualSource => 'Manual';

  @override
  String get aiSource => 'IA';

  @override
  String get searchVenues => 'Buscar lugares...';

  @override
  String noVenuesInCity(String cityName) {
    return 'Sin lugares en $cityName aún';
  }

  @override
  String get addVenuesManuallyOrDiscover =>
      'Agrega lugares manualmente o descúbrelos en Configuración > Administrar Ciudades';

  @override
  String get addCitiesFromSettings =>
      'Agrega ciudades desde Configuración > Administrar Ciudades';

  @override
  String get noVenuesMatch => 'Ningún lugar coincide con tu búsqueda';

  @override
  String get tryDifferentFilterOrTerm =>
      'Intenta con un filtro o término de búsqueda diferente';

  @override
  String get tryDifferentSearchTerm =>
      'Intenta con un término de búsqueda diferente';

  @override
  String get failedToGetPlaceDetails => 'Error al obtener detalles del lugar';

  @override
  String get editVenue => 'Editar Lugar';

  @override
  String get editVenueDetailsBelow =>
      'Edita los detalles del lugar a continuación';

  @override
  String get searchVenueAutoFill =>
      'Busca un lugar y rellenaremos los detalles automáticamente';

  @override
  String get searchVenue => 'Buscar lugar';

  @override
  String get venueSearchExample => 'ej., Ball Arena Denver';

  @override
  String get enterManuallyInstead => 'Escribir manualmente';

  @override
  String get venueFoundGooglePlaces =>
      'Lugar encontrado a través de Google Places';

  @override
  String get clear => 'Limpiar';

  @override
  String get venueName => 'Nombre del Lugar *';

  @override
  String get venueNameExample => 'ej., Ball Arena';

  @override
  String get pleaseEnterVenueName => 'Ingresa el nombre del lugar';

  @override
  String get addressRequired => 'Dirección *';

  @override
  String get addressExample => 'ej., 1000 Chopper Cir, Denver, CO 80204';

  @override
  String get pleaseEnterAddress => 'Ingresa una dirección';

  @override
  String get required => 'Requerido';

  @override
  String get venueAddedCityTabCreated =>
      '¡Lugar agregado y nueva pestaña de ciudad creada!';

  @override
  String get venueUpdatedCityTabAdded =>
      '¡Lugar actualizado y pestaña de ciudad agregada!';

  @override
  String get failedToSaveVenue => 'Error al guardar lugar';

  @override
  String get saving => 'Guardando...';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get failedToLoadCities => 'Error al cargar ciudades';

  @override
  String get cityAlreadyInList => 'Esta ciudad ya está en tu lista';

  @override
  String addedCity(String city) {
    return '$city agregada';
  }

  @override
  String get failedToAddCity => 'Error al agregar ciudad';

  @override
  String get failedToUpdateCity => 'Error al actualizar ciudad';

  @override
  String get deleteCity => 'Eliminar Ciudad';

  @override
  String confirmDeleteCity(String cityName) {
    return '¿Eliminar $cityName?\n\nEsto también eliminará todos los lugares asociados con esta ciudad.';
  }

  @override
  String deletedCity(String cityName) {
    return '$cityName eliminada';
  }

  @override
  String get failedToDeleteCity => 'Error al eliminar ciudad';

  @override
  String get discoverVenues => 'Descubrir Lugares';

  @override
  String discoverVenuesWarning(String cityName) {
    return 'La IA buscará lugares de eventos en la web en $cityName. Esto puede tomar de 2 a 3 minutos según el tamaño de la ciudad.\n\nMantén la aplicación abierta durante la búsqueda.';
  }

  @override
  String get startSearch => 'Iniciar Búsqueda';

  @override
  String discoveredVenuesCount(int count, String cityName) {
    return 'Descubiertos $count lugares para $cityName';
  }

  @override
  String get failedToDiscoverVenues => 'Error al descubrir lugares';

  @override
  String get noCitiesAddedYet => 'Sin ciudades agregadas aún';

  @override
  String get addFirstCityDiscover =>
      'Agrega tu primera ciudad para descubrir lugares';

  @override
  String get touristCityStrictSearch => 'Ciudad Turística (búsqueda estricta)';

  @override
  String get metroAreaBroadSearch => 'Área Metropolitana (búsqueda amplia)';

  @override
  String get searchingWeb => 'Buscando en la web... (hasta 3 min)';

  @override
  String get addCity => 'Agregar Ciudad';

  @override
  String get selectOrTypeCity => 'Selecciona o Escribe Ciudad';

  @override
  String get country => 'País';

  @override
  String get allCountries => 'Todos los Países';

  @override
  String get stateProvince => 'Estado/Provincia';

  @override
  String get allStates => 'Todos los Estados';

  @override
  String get typeOrSearchCity => 'Escribe o Busca Ciudad';

  @override
  String get enterAnyCityName => 'Ingresa cualquier nombre de ciudad...';

  @override
  String get useCustomCity => 'Usar ciudad personalizada:';

  @override
  String get noMatchingCitiesSuggestions =>
      'Sin ciudades coincidentes en sugerencias';

  @override
  String get canTypeAnyCityAbove =>
      'Puedes escribir cualquier nombre de ciudad arriba';

  @override
  String get tourist => 'Turística';

  @override
  String get metro => 'Metro';

  @override
  String get suggestedCities => 'ciudades sugeridas';

  @override
  String get addYourFirstCity => 'Agregar Tu Primera Ciudad';

  @override
  String get addAnotherCity => 'Agregar Otra Ciudad';

  @override
  String get logoUploadedColorsExtracted =>
      '¡Logo cargado y colores extraídos!';

  @override
  String get failedToUploadLogo => 'Error al cargar el logo';

  @override
  String get removeBrandingConfirmation => '¿Eliminar Marca?';

  @override
  String get removeBrandingWarning =>
      'Esto eliminará tu logo y colores personalizados. Los documentos exportados volverán al estilo FlowShift predeterminado.';

  @override
  String get brandCustomization => 'Personalización de Marca';

  @override
  String get pro => 'PRO';

  @override
  String get upgradeToProCustomization =>
      'Actualiza a Pro para personalizar tus documentos exportados con tu propio logo y colores de marca.';

  @override
  String get uploadYourLogo => 'Sube Tu Logo';

  @override
  String get logoFormats => 'JPEG, PNG o WebP (máx. 5MB)';

  @override
  String get replaceLogo => 'Reemplazar Logo';

  @override
  String get documentStyle => 'Estilo de Documento';

  @override
  String get chooseDocumentStyle =>
      'Elige cómo se ven los documentos exportados';

  @override
  String get extractingColors => 'Extrayendo colores de marca con IA...';

  @override
  String get uploadingLogo => 'Cargando logo...';

  @override
  String get brandingRemoved => 'Marca eliminada';

  @override
  String get colorsSaved => '¡Colores guardados!';

  @override
  String get saveColors => 'Guardar Colores';

  @override
  String get aiExtracted => 'Extraído por IA';

  @override
  String get hexColor => 'Color Hexadecimal';

  @override
  String get presets => 'Presets';

  @override
  String get mergeDuplicateClients => 'Fusionar Clientes Duplicados';

  @override
  String get mergingClients => 'Fusionando clientes...';

  @override
  String get confirmMerge => 'Confirmar Fusión';

  @override
  String keepPrimary(String name) {
    return 'Mantener: \"$name\"';
  }

  @override
  String mergeDuplicatesCount(int count) {
    return 'Fusionar y eliminar $count duplicado(s):';
  }

  @override
  String transferEventsAndTariffs(String name) {
    return 'Todos los eventos y tarifas se transferirán a \"$name\".';
  }

  @override
  String get merge => 'Fusionar';

  @override
  String get failedToMerge => 'Error al fusionar';

  @override
  String mergedClients(int count, String name) {
    return '$count cliente(s) fusionados en \"$name\"';
  }

  @override
  String sensitivityLabel(int percent) {
    return 'Sensibilidad: $percent%';
  }

  @override
  String get noDuplicatesFound => 'No se encontraron duplicados';

  @override
  String get lowerSensitivity =>
      'Intenta bajar la sensibilidad para encontrar coincidencias más amplias.';

  @override
  String groupNumber(int number) {
    return 'Grupo $number';
  }

  @override
  String get similarPercent => '% similar';

  @override
  String clientsCountLabel(int count) {
    return '$count clientes';
  }

  @override
  String get tapClientSetPrimary =>
      'Toca un cliente para establecerlo como primario (mantenido):';

  @override
  String get willBeMerged => 'se fusionará';

  @override
  String get keep => 'MANTENER';

  @override
  String mergeInto(int count, String name) {
    return 'Fusionar $count en \"$name\"';
  }

  @override
  String get profileGlowUp => 'Cambio de Imagen';

  @override
  String get whoAreYouToday => '¿Quién eres hoy?';

  @override
  String seeMore(int count) {
    return 'Ver $count más';
  }

  @override
  String get seeLess => 'Menos';

  @override
  String get pickYourVibe => 'Elige tu vibra';

  @override
  String get quality => 'Calidad';

  @override
  String get standard => 'Estándar';

  @override
  String get hd => 'HD';

  @override
  String get higherDetailFacialPreservation =>
      'Mayor detalle y mejor preservación facial';

  @override
  String get textInImage => 'Texto en imagen';

  @override
  String get optional => 'Opcional';

  @override
  String get none => 'Ninguno';

  @override
  String get readyForNewLook => '¿Listo para un nuevo aspecto?';

  @override
  String get hitButtonSeeMagic => 'Presiona el botón y ve la magia';

  @override
  String get lookingGood => '¡Se ve bien!';

  @override
  String get fromYourHistory => 'De tu historial';

  @override
  String get before => 'Antes';

  @override
  String get after => 'Después';

  @override
  String get usuallyTakes15Seconds =>
      'Esto usualmente toma alrededor de 15 segundos';

  @override
  String get failedToLoadStyles => 'Error al cargar estilos';

  @override
  String get aiGeneratedMayNotBeAccurate =>
      'Las imágenes generadas por IA pueden no ser precisas';

  @override
  String get tryAgain => 'Intentar de Nuevo';

  @override
  String get generateNew => 'Generar Nuevo';

  @override
  String get getMyNewLook => 'Obtener Mi Nuevo Aspecto';

  @override
  String get sendEventInvitationTooltip => 'Enviar Invitación de Evento';

  @override
  String get exportReport => 'Exportar Reporte';

  @override
  String get chooseFormatAndReportType => 'Elige formato y tipo de reporte';

  @override
  String get reportType => 'Tipo de Reporte';

  @override
  String get payrollReportLabel => 'Reporte de Nómina';

  @override
  String get payrollReportDescription =>
      'Desglose de ganancias del personal por horas y tarifa';

  @override
  String get attendanceReportLabel => 'Reporte de Asistencia';

  @override
  String get attendanceReportDescription =>
      'Horarios de entrada/salida y horas trabajadas';

  @override
  String get exportFormat => 'Formato de Exportación';

  @override
  String get csvLabel => 'CSV';

  @override
  String get excelCompatible => 'Compatible con Excel';

  @override
  String get pdfLabel => 'PDF';

  @override
  String get printReady => 'Listo para imprimir';

  @override
  String exportFormatButton(String format) {
    return 'Exportar $format';
  }

  @override
  String get lastSevenDays => 'Últimos 7 días';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get thisYear => 'Este año';

  @override
  String get customRange => 'Rango personalizado';

  @override
  String get createInviteLinkTitle => 'Crear Enlace de Invitación';

  @override
  String get shareableLinkDescription =>
      'Crea un enlace compartible que cualquiera puede usar para unirse a tu equipo.';

  @override
  String get linkExpiresIn => 'El enlace expira en:';

  @override
  String get maxUsesOptional => 'Usos máximos (opcional):';

  @override
  String get leaveEmptyUnlimited => 'Dejar vacío para ilimitado';

  @override
  String get requireApprovalTitle => 'Requerir aprobación';

  @override
  String get requireApprovalSubtitle =>
      'Debes aprobar a los miembros después de que se unan';

  @override
  String get passwordOptionalLabel => 'Contraseña (opcional):';

  @override
  String get leaveEmptyNoPassword => 'Dejar vacío para sin contraseña';

  @override
  String get createLinkButton => 'Crear Enlace';

  @override
  String get inviteLinkCreatedTitle => 'Enlace de Invitación Creado!';

  @override
  String get inviteCodeLabel => 'Código de Invitación:';

  @override
  String get deepLinkLabel => 'Enlace Directo:';

  @override
  String get shareDeepLinkHint =>
      'Comparte este enlace - abrirá la app automáticamente';

  @override
  String expiresDate(String date) {
    return 'Expira: $date';
  }

  @override
  String get shareViaApps => 'Compartir por WhatsApp, SMS, etc.';

  @override
  String get showQrCode => 'Mostrar Código QR';

  @override
  String get joinTeamSubject => 'Únete a mi equipo en FlowShift';

  @override
  String get unknownApplicant => 'Solicitante desconocido';

  @override
  String appliedDate(String date) {
    return 'Solicitó $date';
  }

  @override
  String get errorLoadingEvents => 'Error al cargar eventos';

  @override
  String get noEventsFoundTitle => 'No se encontraron eventos';

  @override
  String get notLinkedToEventsYet =>
      'Este usuario aún no está vinculado a ningún evento';

  @override
  String upcomingEventsCount(int count) {
    return 'Próximos Eventos ($count)';
  }

  @override
  String get dateUnknownLabel => 'Fecha Desconocida';

  @override
  String get editEventTitle => 'Editar Evento';

  @override
  String get eventUpdatedSuccessfully => 'El evento se actualizó exitosamente!';

  @override
  String get failedToUpdateEvent => 'Error al actualizar evento';

  @override
  String get selectDateHint => 'Seleccionar fecha';

  @override
  String get dateLabel => 'Fecha';

  @override
  String clockOutConfirmation(String name) {
    return '¿Estás seguro de que quieres registrar la salida de $name?';
  }

  @override
  String get removeStaffConfirmation =>
      '¿Estás seguro de que quieres eliminar a este miembro del personal del evento?';

  @override
  String openToAllStaffConfirmation(String name) {
    return '¿Hacer \"$name\" visible para todo el personal?\n\nEsto cambiará el trabajo de privado (solo invitados) a público, permitiendo que todos los miembros del equipo lo vean y acepten.';
  }

  @override
  String clockInConfirmation(String name) {
    return '¿Registrar entrada de $name para este evento?';
  }

  @override
  String get workingHoursSheetTooltip => 'Hoja de Horas Trabajadas';

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get privateLabel => 'Privado';

  @override
  String get publicLabel => 'Público';

  @override
  String get privatePlusPublic => 'Privado+Público';

  @override
  String get setUpStaffingCompany =>
      'Configura tu empresa de personal (ej., \"MES - Minneapolis Event Staffing\")';

  @override
  String get descriptionOptionalLabel => 'Descripción (opcional)';

  @override
  String get briefDescriptionHint =>
      'Breve descripción de tu empresa de personal';

  @override
  String get createTeamButton => 'Crear equipo';

  @override
  String clientsConfiguredCount(int count) {
    return 'Clientes configurados: $count';
  }

  @override
  String get needAtLeastOneClientDesc =>
      'Necesitas al menos un cliente antes de poder programar eventos.';

  @override
  String get clientNameLabel => 'Nombre del cliente';

  @override
  String get completeProfileAndTeam => 'Completa perfil y equipo primero';

  @override
  String get createClientButton => 'Crear cliente';

  @override
  String rolesConfiguredCount(int count) {
    return 'Roles configurados: $count';
  }

  @override
  String get rolesHelpMatchStaffDesc =>
      'Los roles ayudan a asignar al personal correcto (mesero, chef, bartender...).';

  @override
  String get roleNameLabel => 'Nombre del rol';

  @override
  String get finishPreviousSteps => 'Termina los pasos anteriores primero';

  @override
  String get createRoleButton => 'Crear rol';

  @override
  String tariffsConfiguredCount(int count) {
    return 'Tarifas configuradas: $count';
  }

  @override
  String get setRateDescription =>
      'Establece una tarifa para que las asignaciones sepan cuánto cobrar.';

  @override
  String get clientLabel => 'Cliente';

  @override
  String get roleLabel => 'Rol';

  @override
  String get adjustLaterHint =>
      'Puedes ajustar esto después en Catálogo > Tarifas';

  @override
  String get pleaseEnterTimesForAllStaff =>
      'Por favor ingresa los horarios de entrada y salida para todo el personal seleccionado';

  @override
  String get hoursSubmittedAndApproved =>
      'Horas enviadas y aprobadas exitosamente';

  @override
  String submitHoursButton(int count) {
    return 'Enviar Horas ($count)';
  }

  @override
  String get bartenderHint => 'Bartender';

  @override
  String get notesLabel => 'Notas';

  @override
  String get roleHint => 'Rol';

  @override
  String get noEventsNeedApprovalDescription =>
      'No hay eventos que necesiten aprobación de horas en este momento.';

  @override
  String get pendingReviewLabel => 'Revisión Pendiente';

  @override
  String get needsSheetLabel => 'Necesita Hoja';

  @override
  String get purchaseCancelledMessage =>
      'Compra cancelada o fallida. Por favor inténtalo de nuevo.';

  @override
  String get upgradeToProTitle => 'Mejorar a Pro';

  @override
  String get flowShiftPro => 'FlowShift Pro';

  @override
  String get createAsManyEvents => 'Crea tantos eventos como necesites';

  @override
  String get noLimitsDescription => 'Sin límites en el tamaño del personal';

  @override
  String get earlyAccessDescription => 'Acceso anticipado a nuevas funciones';

  @override
  String get subscriptionTerms =>
      'Al suscribirte, aceptas nuestros Términos de Servicio y Política de Privacidad. La suscripción se renueva automáticamente a menos que se cancele al menos 24 horas antes del final del período actual.';

  @override
  String get staffWillAppearOnClockIn =>
      'El personal aparecerá aquí cuando registren su entrada';

  @override
  String get cancelInvite => 'Cancelar invitación';

  @override
  String usedCount(int used, int max) {
    return 'Usado: $used / $max';
  }

  @override
  String usedCountUnlimited(int used) {
    return 'Usado: $used (ilimitado)';
  }

  @override
  String codePrefix(String code) {
    return 'Código: $code';
  }

  @override
  String get addVenuesDescription =>
      'Agrega locales manualmente o descúbrelos desde Configuración > Gestionar Ciudades';

  @override
  String get searchVenuesHint => 'Buscar locales...';

  @override
  String get invalidPhoneFormat => 'Formato de número de teléfono inválido';

  @override
  String get tooManyAttemptsMessage =>
      'Demasiados intentos. Inténtalo más tarde.';

  @override
  String get invalidCodeMessage =>
      'Código inválido. Verifica e inténtalo de nuevo.';

  @override
  String get codeExpiredMessage => 'Código expirado. Solicita uno nuevo.';

  @override
  String get addPhoneDescription =>
      'Agrega un número de teléfono como método alternativo de inicio de sesión';

  @override
  String get phoneNumberHint => 'Número de teléfono';

  @override
  String get untitled => 'Sin título';

  @override
  String get message => 'Mensaje';

  @override
  String get eventInformation => 'Información del Evento';

  @override
  String get venueInformation => 'Información del Lugar';

  @override
  String get staffRolesRequired => 'Roles de Personal Requeridos';

  @override
  String get successTitle => 'Éxito';

  @override
  String get selectTimeHint => 'Seleccionar hora';

  @override
  String clockingInStaff(String staffName) {
    return 'Registrando entrada de $staffName...';
  }

  @override
  String roleVacancies(
    String roleName,
    int accepted,
    int total,
    int vacancies,
  ) {
    return '$roleName ($accepted/$total, $vacancies restantes)';
  }

  @override
  String get phoneLinkedSuccessfully =>
      '¡Número de teléfono vinculado exitosamente!';

  @override
  String teamReady(String name) {
    return 'Equipo listo: $name';
  }

  @override
  String get proWelcomeMessage =>
      '¡Bienvenido a FlowShift Pro! Todas las funciones empresariales desbloqueadas.';

  @override
  String get dateTbd => 'Fecha por definir';

  @override
  String get freeTierLimitsDetails =>
      '• Máximo 25 miembros del equipo\n• 10 eventos por mes\n• Sin acceso a analíticas';

  @override
  String get errorPrefix => 'Error';

  @override
  String moveToDraftsConfirmation(String name) {
    return '¿Mover \"$name\" a borradores?';
  }

  @override
  String get memberRemovedSuccess => 'Miembro eliminado';

  @override
  String get failedToRemoveMember => 'Error al eliminar miembro';

  @override
  String get staffHoursLabel => 'Horas del Personal';

  @override
  String get eventsCompletedLabel => 'Eventos Completados';

  @override
  String get fulfillmentRateLabel => 'Tasa de Cumplimiento';

  @override
  String get scanLabel => 'Escanear';

  @override
  String get aiChatLabel => 'Chat IA';

  @override
  String get uploadLabel => 'Subir';
}
