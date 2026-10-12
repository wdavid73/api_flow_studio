// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'API Flow Studio';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonAdd => 'Agregar';

  @override
  String get commonImport => 'Importar';

  @override
  String get commonExport => 'Exportar';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSend => 'Enviar';

  @override
  String get commonNone => 'Ninguno';

  @override
  String get commonError => 'Error';

  @override
  String get commonAll => 'Todos';

  @override
  String get commonKey => 'Clave';

  @override
  String get commonValue => 'Valor';

  @override
  String get commonHeaders => 'Cabeceras';

  @override
  String get commonNoHeaders => 'Sin cabeceras';

  @override
  String get commonOk => 'Aceptar';

  @override
  String commonTimeMs(int ms) {
    return '$ms ms';
  }

  @override
  String commonSizeBytes(int bytes) {
    return '$bytes B';
  }

  @override
  String get commonNothingMatches => 'Ninguna coincidencia con esa búsqueda.';

  @override
  String commonFailedToLoad(String what, Object error) {
    return 'No se pudo cargar $what: $error';
  }

  @override
  String get languageTooltip => 'Cambiar idioma';

  @override
  String get languageSystemDefault => 'Idioma del sistema';

  @override
  String get navWorkspace => 'Espacio de trabajo';

  @override
  String get navEnvironments => 'Entornos';

  @override
  String get navFlows => 'Flujos';

  @override
  String get navHistory => 'Historial';

  @override
  String get headerTagline => 'Laboratorio de APIs';

  @override
  String get headerMoreEnvironments => 'Más entornos';

  @override
  String get hostsButton => 'Hosts y notas';

  @override
  String get hostsDialogTitle => 'Hosts por entorno';

  @override
  String get hostsAddHost => 'Agregar host';

  @override
  String get hostsHelp =>
      'Los hosts son variables de entorno cuyo valor es una URL. Edita una celda para cambiarla en ese entorno; bórrala para quitar la variable allí.';

  @override
  String get hostsEnterName => 'Escribe un nombre.';

  @override
  String get hostsNameChars => 'Usa solo letras, dígitos y guiones bajos.';

  @override
  String get hostsNameUsedBySecret => 'Una variable secreta ya usa ese nombre.';

  @override
  String get hostsAlreadyExists => 'Ese host ya existe.';

  @override
  String get hostsEmpty =>
      'Aún no hay hosts: agrega una variable de entorno cuyo valor sea una URL, o usa Agregar host.';

  @override
  String get hostsColumnHost => 'HOST';

  @override
  String get hostsColumnNote => 'NOTA';

  @override
  String get hostsNoteHint => 'Nota…';

  @override
  String hostsUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peticiones',
      one: '1 petición',
    );
    return 'Usado por $_temp0';
  }

  @override
  String get hostsAllDefined =>
      'Todos los hosts están definidos en todos los entornos.';

  @override
  String get hostsActiveTag => 'ACTIVO';

  @override
  String hostsWarningNotDefinedIn(String environments) {
    return ' no está definido en $environments. Las peticiones que usan ';
  }

  @override
  String get hostsWarningUnresolved =>
      ' se enviarán allí con ese texto sin resolver.';

  @override
  String get sessionNoToken => 'Sin token';

  @override
  String get sessionKeptInMemory => 'solo en memoria';

  @override
  String get sessionTokenSaved => 'Token guardado';

  @override
  String get sessionTokenExpired => 'Token vencido';

  @override
  String sessionExpiresInMinutes(int minutes) {
    return 'Vence en $minutes min';
  }

  @override
  String sessionExpiresInHours(int hours) {
    return 'Vence en $hours h';
  }

  @override
  String get sessionNoEnvironment => 'Sin entorno';

  @override
  String sessionTitle(String environment) {
    return 'Sesión · $environment';
  }

  @override
  String get sessionNotJwt =>
      'No parece un JWT. Se envía igualmente como Bearer.';

  @override
  String sessionSubject(String subject) {
    return 'sub $subject';
  }

  @override
  String get sessionAccessToken => 'Token de acceso';

  @override
  String get sessionRefreshToken => 'Token de refresco';

  @override
  String get sessionShow => 'Mostrar';

  @override
  String get sessionSendAuthorization => 'Enviar Authorization';

  @override
  String get sessionCaptureTokens => 'Capturar tokens de respuestas 2xx';

  @override
  String get sessionClearTokens => 'Borrar tokens';

  @override
  String sessionTokensCaptured(String environment) {
    return 'Tokens capturados para $environment';
  }

  @override
  String workspaceExported(String name) {
    return 'Espacio de trabajo \"$name\" exportado — no incluye secretos';
  }

  @override
  String workspaceCouldNotSave(Object error) {
    return 'No se pudo guardar el espacio de trabajo: $error';
  }

  @override
  String workspaceCouldNotReadFile(Object error) {
    return 'No se pudo leer el archivo: $error';
  }

  @override
  String workspaceImported(String name) {
    return 'Se importó \"$name\"';
  }

  @override
  String workspaceImportedToFill(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores',
      one: '1 valor',
    );
    return 'Se importó \"$name\" — $_temp0 por completar';
  }

  @override
  String get workspaceCouldNotImportTitle =>
      'No se pudo importar el espacio de trabajo';

  @override
  String workspaceCouldNotImport(Object error) {
    return 'No se pudo importar el espacio de trabajo: $error';
  }

  @override
  String get projectNew => 'Nuevo proyecto';

  @override
  String get projectNewEllipsis => 'Nuevo proyecto…';

  @override
  String get projectRename => 'Renombrar proyecto';

  @override
  String get projectRenameEllipsis => 'Renombrar proyecto…';

  @override
  String get projectSwitch => 'Cambiar de proyecto';

  @override
  String get projectExportWorkspace => 'Exportar espacio de trabajo…';

  @override
  String get projectImportWorkspace => 'Importar espacio de trabajo…';

  @override
  String get projectDeleteEllipsis => 'Eliminar proyecto…';

  @override
  String projectCreatedToast(String name) {
    return 'Proyecto \"$name\" creado';
  }

  @override
  String projectRenamedToast(String name) {
    return 'Proyecto renombrado a \"$name\"';
  }

  @override
  String projectDeletedToast(String name) {
    return 'Proyecto \"$name\" eliminado';
  }

  @override
  String projectDeleteTitle(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get projectDeleteBody =>
      'Esto elimina de forma permanente sus entornos, colecciones, flujos e historial. No se puede deshacer.';

  @override
  String get projectNameEmpty => 'Ponle un nombre al proyecto.';

  @override
  String projectNameTooLong(int max) {
    return 'Los nombres están limitados a $max caracteres.';
  }

  @override
  String get projectNameDuplicate => 'Ya existe un proyecto con ese nombre.';

  @override
  String get projectNameHint => 'Nombre del proyecto';

  @override
  String get projectColor => 'Color';

  @override
  String importDescribe(String source, String parts, String fill) {
    return 'Se importó $source: $parts$fill';
  }

  @override
  String importPartsRequestsInFolders(int requests, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      requests,
      locale: localeName,
      other: '$requests peticiones',
      one: '1 petición',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders carpetas',
      one: '1 carpeta',
    );
    return '$_temp0 en $_temp1';
  }

  @override
  String importPartsEnvironments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entornos',
      one: '1 entorno',
    );
    return '$_temp0';
  }

  @override
  String get importPartsNothing => 'nada';

  @override
  String importValuesToFill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores',
      one: '1 valor',
    );
    return ' — $_temp0 por completar';
  }

  @override
  String get importSummaryTitle => 'Resumen de la importación';

  @override
  String importWarningsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron o cambiaron $count cosas',
      one: 'Se omitió o cambió 1 cosa',
    );
    return '$_temp0:';
  }

  @override
  String importWarningsMore(int count) {
    return '…y $count más sin mostrar';
  }

  @override
  String get importErrorTitle => 'No se pudo importar';

  @override
  String get importCouldNotRead => 'No se pudo leer ese archivo.';

  @override
  String importCouldNotImportFile(Object error) {
    return 'No se pudo importar ese archivo: $error';
  }

  @override
  String get historyKicker => 'HISTORIAL';

  @override
  String get historyTitle => 'Historial de peticiones';

  @override
  String get historyFilterHint => 'Filtrar historial…';

  @override
  String get historyClear => 'Borrar historial';

  @override
  String get historyEmpty =>
      'Aún no hay historial: envía una petición guardada.';

  @override
  String historyClearTitle(String project) {
    return '¿Borrar el historial de \"$project\"?';
  }

  @override
  String get historyClearBody =>
      'Esto elimina todas las respuestas guardadas de este proyecto. Tus peticiones, entornos y flujos no se tocan.';

  @override
  String get historyClearConfirm => 'Borrar';

  @override
  String get historyCleared => 'Historial borrado';

  @override
  String get historyDeletedRequest => 'Petición eliminada';

  @override
  String get historyToday => 'HOY';

  @override
  String get historyYesterday => 'AYER';

  @override
  String get historySaveToRecord =>
      'Guarda esta petición para empezar a registrar su historial';

  @override
  String get historyTabEmpty => 'Aún no hay historial: envía una petición';

  @override
  String get historyHistoricalLabel => 'Respuesta histórica — no es en vivo';

  @override
  String get historyTruncated => 'Cuerpo recortado a 100 KB';

  @override
  String historyErrorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get collectionsKicker => 'EXPLORADOR';

  @override
  String get collectionsNewFolder => 'Nueva carpeta';

  @override
  String get collectionsPasteCurl => 'Pegar curl';

  @override
  String get collectionsImportEllipsis => 'Importar…';

  @override
  String get collectionsExportTooltip => 'Exportar endpoints (JSON)';

  @override
  String get collectionsFilterHint => 'Filtrar peticiones…';

  @override
  String get collectionsEmpty =>
      'Aún no hay endpoints: crea una carpeta para empezar.';

  @override
  String collectionsVersion(String version) {
    return 'API Flow Studio $version';
  }

  @override
  String get collectionsExportTitle => 'Exportar endpoints';

  @override
  String collectionsExportedTo(String path) {
    return 'Exportado a $path';
  }

  @override
  String get collectionsFolderName => 'Nombre de la carpeta';

  @override
  String get collectionsAddRequest => 'Agregar petición';

  @override
  String get collectionsNewRequestName => 'Nueva petición';

  @override
  String get collectionsDeleteFolder => 'Eliminar carpeta';

  @override
  String get collectionsDeleteFolderFirst =>
      'Primero elimina el contenido de esta carpeta.';

  @override
  String get collectionsEmptyFolder =>
      'Aún no hay endpoints — + Agregar petición';

  @override
  String get collectionsDeleteRequest => 'Eliminar petición';

  @override
  String get collectionsLoadWhat => 'colecciones';

  @override
  String get curlPasteTitle => 'Pegar curl';

  @override
  String curlCouldNotParse(String message) {
    return 'No se pudo interpretar este comando curl: $message';
  }

  @override
  String get requestUnsaved => 'SIN GUARDAR';

  @override
  String get requestNoFolder => 'SIN CARPETA';

  @override
  String get requestTabDocs => 'Docs';

  @override
  String get requestTabParams => 'Parámetros';

  @override
  String get requestTabHeaders => 'Cabeceras';

  @override
  String get requestTabBody => 'Cuerpo';

  @override
  String get requestTabAuth => 'Auth';

  @override
  String get requestTabTests => 'Tests';

  @override
  String get requestTabSettings => 'Ajustes';

  @override
  String get requestTestsOutOfScope =>
      'Los tests están fuera del alcance del MVP';

  @override
  String get requestSettingsOutOfScope =>
      'Los ajustes están fuera del alcance del MVP';

  @override
  String get requestDocsHint =>
      'Describe para qué sirve este endpoint, cuándo usarlo, requisitos previos, etc.';

  @override
  String get authBasic => 'Basic';

  @override
  String get authBearer => 'Bearer';

  @override
  String get authUsername => 'Usuario';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authToken => 'Token';

  @override
  String get bodyJson => 'JSON';

  @override
  String get bodyFormUrlEncoded => 'Form URL-Encoded';

  @override
  String get bodyFormData => 'Form Data';

  @override
  String get bodyNone => 'Esta petición no tiene cuerpo';

  @override
  String get bodyFormatJson => 'Formatear JSON';

  @override
  String get bodyInvalidJson => 'JSON inválido';

  @override
  String get tableAddRow => 'Agregar fila';

  @override
  String get multipartAddField => 'Agregar campo';

  @override
  String get multipartText => 'Texto';

  @override
  String get multipartFile => 'Archivo';

  @override
  String get multipartPathHint => 'ruta del archivo';

  @override
  String get multipartChoose => 'Elegir…';

  @override
  String get multipartNoFile => 'Ningún archivo elegido';

  @override
  String get responseCopy => 'Copiar';

  @override
  String get responseNothingToCopy => 'Nada que copiar';

  @override
  String get responseCopied => 'Respuesta copiada';

  @override
  String get responseCurlCopied => 'curl copiado';

  @override
  String get responseTabResponse => 'Respuesta';

  @override
  String get responseTabHistory => 'Historial';

  @override
  String get responseNone => 'Aún no hay respuesta';

  @override
  String get responseNoneHint =>
      'Elige una petición y envía. Cmd/Ctrl + Enter también envía.';

  @override
  String responseErrorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get responseTabBody => 'Cuerpo';

  @override
  String get responseTabHeaders => 'Cabeceras';

  @override
  String get responseTabCookies => 'Cookies';

  @override
  String get responseTabTimeline => 'Línea de tiempo';

  @override
  String get responseViewFormat => 'Formato';

  @override
  String get responseViewRaw => 'Crudo';

  @override
  String get responseViewPreview => 'Vista previa';

  @override
  String get responseNoCookies => 'Sin cookies';

  @override
  String responseTimeline(int ms) {
    return 'Petición enviada → respuesta recibida, ${ms}ms';
  }

  @override
  String get commonActiveTag => 'ACTIVO';

  @override
  String get envKicker => 'ENTORNOS';

  @override
  String get envNew => 'Nuevo entorno';

  @override
  String get envCreateFirst => 'Crea tu primer entorno para empezar';

  @override
  String get envEmptyList => 'Aún no hay entornos: crea el primero arriba.';

  @override
  String envVariableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variables',
      one: '1 variable',
    );
    return '$_temp0';
  }

  @override
  String get envColumnName => 'NOMBRE';

  @override
  String get envColumnValue => 'VALOR';

  @override
  String get envColumnSecret => 'SECRETO';

  @override
  String get envAddVariable => 'Agregar variable';

  @override
  String get envProTip => 'Consejo: sintaxis y resolución';

  @override
  String get envTipReference =>
      'Referencia variables en cualquier URL, cabecera o cuerpo usando la sintaxis ';

  @override
  String get envTipSyntaxSuffix => '.';

  @override
  String get envTipGenerated => 'En cada envío se genera un valor nuevo: ';

  @override
  String get envVariableHint => 'Variable';

  @override
  String get envLoadWhat => 'entornos';

  @override
  String get flowsKicker => 'FLUJOS';

  @override
  String get flowsNew => 'Nuevo flujo';

  @override
  String get flowsNewName => 'Nuevo flujo';

  @override
  String get flowsImportTooltip => 'Importar flujos';

  @override
  String get flowsExportTooltip => 'Exportar flujos';

  @override
  String get flowsSelectOrCreate => 'Selecciona o crea un flujo para empezar';

  @override
  String get flowsEmptyList =>
      'Aún no hay flujos: crea uno para encadenar peticiones.';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos',
      one: '1 paso',
    );
    return '$_temp0';
  }

  @override
  String get flowsDelete => 'Eliminar flujo';

  @override
  String get flowsSave => 'Guardar flujo';

  @override
  String get flowsRun => 'Ejecutar flujo';

  @override
  String get flowsNoSteps =>
      'Aún no hay pasos: agrega un endpoint guardado para empezar';

  @override
  String get flowsAddNextStep => 'Agregar siguiente paso al pipeline';

  @override
  String get flowsLoadWhat => 'flujos';

  @override
  String get flowsSelectAll => 'Todos los flujos';

  @override
  String get flowsNothingToExport => 'Aún no hay flujos para exportar';

  @override
  String get flowsExportTitle => 'Exportar flujos';

  @override
  String get flowsImportTitle => 'Importar flujos';

  @override
  String flowsExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'exportaron $count flujos',
      one: 'exportó 1 flujo',
    );
    return 'Se $_temp0 — no incluye credenciales';
  }

  @override
  String flowsExportFailed(Object error) {
    return 'No se pudieron exportar los flujos: $error';
  }

  @override
  String get flowsFileEmpty => 'Ese archivo no tiene flujos.';

  @override
  String flowsImportFailed(Object error) {
    return 'No se pudieron importar los flujos: $error';
  }

  @override
  String get flowsImportErrorTitle => 'No se pudieron importar los flujos';

  @override
  String flowsImported(String flows, String details) {
    return 'Se importó $flows$details';
  }

  @override
  String flowsImportedFlowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flujos',
      one: '1 flujo',
    );
    return '$_temp0';
  }

  @override
  String flowsImportedDetails(String parts) {
    return ' — $parts';
  }

  @override
  String flowsPartRequestsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peticiones agregadas',
      one: '1 petición agregada',
    );
    return '$_temp0';
  }

  @override
  String flowsPartRequestsReused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peticiones ya existían',
      one: '1 petición ya existía',
    );
    return '$_temp0';
  }

  @override
  String flowsPartStepsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos sin petición',
      one: '1 paso sin petición',
    );
    return '$_temp0';
  }

  @override
  String flowsPartFilesToChoose(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos por elegir',
      one: '1 archivo por elegir',
    );
    return '$_temp0';
  }

  @override
  String get flowsFileTooLarge =>
      'Ese archivo es demasiado grande para ser un archivo de flujos (el límite es 10 MB).';

  @override
  String get flowsFileNotJson => 'Ese archivo no es un JSON válido.';

  @override
  String get flowsFileNotFlows =>
      'Ese archivo no es un archivo de flujos de API Flow Studio.';

  @override
  String get flowsFileNewer =>
      'Ese archivo lo creó una versión más nueva de API Flow Studio. Actualiza la app para abrirlo.';

  @override
  String get flowsFileInvalid =>
      'Ese archivo de flujos está dañado o incompleto.';

  @override
  String get pickerAddStep => 'Agregar paso';

  @override
  String get pickerUncategorized => 'Sin categoría';

  @override
  String get pickerNoSaved =>
      'Aún no hay endpoints guardados: guarda una petición primero.';

  @override
  String get pickerAllEndpoints => 'Todos los endpoints';

  @override
  String get pickerSearchHint => 'Buscar endpoints…';

  @override
  String get pickerNoMatch => 'Ningún endpoint coincide con tu búsqueda.';

  @override
  String get assertionsTitle => 'Aserciones';

  @override
  String get assertionsAdd => 'Agregar aserción';

  @override
  String assertionsGot(String value) {
    return 'obtuvo \"$value\"';
  }

  @override
  String assertionsSummary(int passed, int total) {
    return '$passed/$total aserciones';
  }

  @override
  String get errorUnknown => 'Error desconocido';

  @override
  String get errorAssertionFailure => 'Aserción fallida';

  @override
  String get errorConfiguration => 'Error de configuración';

  @override
  String get errorNetwork => 'Error de red';

  @override
  String get runReRunFlow => 'Volver a ejecutar flujo';

  @override
  String runPassed(int count) {
    return '$count correctos';
  }

  @override
  String runFailed(int count) {
    return '$count fallidos';
  }

  @override
  String runSkipped(int count) {
    return '$count omitidos';
  }

  @override
  String get runSelectStep => 'Selecciona un paso para ver sus detalles';

  @override
  String get runMissingEndpoint => 'Endpoint no encontrado';

  @override
  String get runSkippedStep => 'Omitido';

  @override
  String get inspectorErrorDetails => 'Detalles del error';

  @override
  String get inspectorRequestSent => 'Petición enviada';

  @override
  String get inspectorResponseBody => 'Cuerpo de la respuesta';

  @override
  String get inspectorNoRequest => 'No se envió ninguna petición';

  @override
  String get inspectorNoResponse => 'No se recibió respuesta';

  @override
  String inspectorRerunFrom(int step) {
    return 'Volver a ejecutar desde el paso $step';
  }

  @override
  String stepMissingEndpoint(String id) {
    return 'Endpoint no encontrado ($id)';
  }

  @override
  String get stepTerminal => 'TERMINAL';

  @override
  String get stepPayloadTemplate => 'PLANTILLA DEL CUERPO';

  @override
  String get stepExtractTitle => 'Extraer variables de salida';

  @override
  String get stepAddExtracted => 'Agregar variable extraída';

  @override
  String get stepStopOnFailure => 'Detener si falla';

  @override
  String get multipartNameHint => 'nombre';

  @override
  String get multipartAutoHint => 'auto';

  @override
  String get multipartValueHint => 'valor';

  @override
  String get assertionExpectedHint => 'esperado';

  @override
  String get stepChangeRequest => 'Cambiar petición';
}
