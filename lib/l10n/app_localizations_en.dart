// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'API Flow Studio';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonImport => 'Import';

  @override
  String get commonExport => 'Export';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSend => 'Send';

  @override
  String get commonNone => 'None';

  @override
  String get commonError => 'Error';

  @override
  String get commonAll => 'All';

  @override
  String get commonKey => 'Key';

  @override
  String get commonValue => 'Value';

  @override
  String get commonHeaders => 'Headers';

  @override
  String get commonNoHeaders => 'No headers';

  @override
  String get commonOk => 'OK';

  @override
  String commonTimeMs(int ms) {
    return '$ms ms';
  }

  @override
  String commonSizeBytes(int bytes) {
    return '$bytes B';
  }

  @override
  String get commonNothingMatches => 'Nothing matches that search.';

  @override
  String commonFailedToLoad(String what, Object error) {
    return 'Failed to load $what: $error';
  }

  @override
  String get languageTooltip => 'Change language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get navWorkspace => 'Workspace';

  @override
  String get navEnvironments => 'Environments';

  @override
  String get navFlows => 'Flows';

  @override
  String get navHistory => 'History';

  @override
  String get headerTagline => 'API playground';

  @override
  String get headerMoreEnvironments => 'More environments';

  @override
  String get hostsButton => 'Hosts & notes';

  @override
  String get hostsDialogTitle => 'Hosts by environment';

  @override
  String get hostsAddHost => 'Add host';

  @override
  String get hostsHelp =>
      'Hosts are environment variables whose value is a URL. Edit a cell to change it in that environment; clear it to remove the variable there.';

  @override
  String get hostsEnterName => 'Enter a name.';

  @override
  String get hostsNameChars => 'Use letters, digits and underscores only.';

  @override
  String get hostsNameUsedBySecret =>
      'A secret variable already uses that name.';

  @override
  String get hostsAlreadyExists => 'That host already exists.';

  @override
  String get hostsEmpty =>
      'No hosts yet — add an environment variable whose value is a URL, or use Add host.';

  @override
  String get hostsColumnHost => 'HOST';

  @override
  String get hostsColumnNote => 'NOTE';

  @override
  String get hostsNoteHint => 'Note…';

  @override
  String hostsUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
    );
    return 'Used by $_temp0';
  }

  @override
  String get hostsAllDefined => 'Every host is defined in every environment.';

  @override
  String get hostsActiveTag => 'ACTIVE';

  @override
  String hostsWarningNotDefinedIn(String environments) {
    return ' isn\'t defined in $environments. Requests that use ';
  }

  @override
  String get hostsWarningUnresolved =>
      ' will be sent with that text unresolved there.';

  @override
  String get sessionNoToken => 'No token';

  @override
  String get sessionKeptInMemory => 'kept in memory only';

  @override
  String get sessionTokenSaved => 'Token saved';

  @override
  String get sessionTokenExpired => 'Token expired';

  @override
  String sessionExpiresInMinutes(int minutes) {
    return 'Expires in $minutes min';
  }

  @override
  String sessionExpiresInHours(int hours) {
    return 'Expires in $hours h';
  }

  @override
  String get sessionNoEnvironment => 'No environment';

  @override
  String sessionTitle(String environment) {
    return 'Session · $environment';
  }

  @override
  String get sessionNotJwt =>
      'Doesn\'t look like a JWT. It is still sent as a Bearer.';

  @override
  String sessionSubject(String subject) {
    return 'sub $subject';
  }

  @override
  String get sessionAccessToken => 'Access token';

  @override
  String get sessionRefreshToken => 'Refresh token';

  @override
  String get sessionShow => 'Show';

  @override
  String get sessionSendAuthorization => 'Send Authorization';

  @override
  String get sessionCaptureTokens => 'Capture tokens from 2xx';

  @override
  String get sessionClearTokens => 'Clear tokens';

  @override
  String sessionTokensCaptured(String environment) {
    return 'Tokens captured for $environment';
  }

  @override
  String workspaceExported(String name) {
    return 'Workspace \"$name\" exported — secrets are not included';
  }

  @override
  String workspaceCouldNotSave(Object error) {
    return 'Could not save the workspace: $error';
  }

  @override
  String workspaceCouldNotReadFile(Object error) {
    return 'Could not read the file: $error';
  }

  @override
  String workspaceImported(String name) {
    return 'Imported \"$name\"';
  }

  @override
  String workspaceImportedToFill(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count values',
      one: '1 value',
    );
    return 'Imported \"$name\" — $_temp0 to fill in';
  }

  @override
  String get workspaceCouldNotImportTitle => 'Could not import the workspace';

  @override
  String workspaceCouldNotImport(Object error) {
    return 'Could not import the workspace: $error';
  }

  @override
  String get projectNew => 'New project';

  @override
  String get projectNewEllipsis => 'New project…';

  @override
  String get projectRename => 'Rename project';

  @override
  String get projectRenameEllipsis => 'Rename project…';

  @override
  String get projectSwitch => 'Switch project';

  @override
  String get projectExportWorkspace => 'Export workspace…';

  @override
  String get projectImportWorkspace => 'Import workspace…';

  @override
  String get projectDeleteEllipsis => 'Delete project…';

  @override
  String projectCreatedToast(String name) {
    return 'Project \"$name\" created';
  }

  @override
  String projectRenamedToast(String name) {
    return 'Project renamed to \"$name\"';
  }

  @override
  String projectDeletedToast(String name) {
    return 'Project \"$name\" deleted';
  }

  @override
  String projectDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get projectDeleteBody =>
      'This permanently deletes its environments, collections, flows and history. It cannot be undone.';

  @override
  String get projectNameEmpty => 'Give the project a name.';

  @override
  String projectNameTooLong(int max) {
    return 'Names are limited to $max characters.';
  }

  @override
  String get projectNameDuplicate => 'A project with that name already exists.';

  @override
  String get projectNameHint => 'Project name';

  @override
  String get projectColor => 'Color';

  @override
  String importDescribe(String source, String parts, String fill) {
    return 'Imported $source: $parts$fill';
  }

  @override
  String importPartsRequestsInFolders(int requests, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      requests,
      locale: localeName,
      other: '$requests requests',
      one: '1 request',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders folders',
      one: '1 folder',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String importPartsEnvironments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count environments',
      one: '1 environment',
    );
    return '$_temp0';
  }

  @override
  String get importPartsNothing => 'nothing';

  @override
  String importValuesToFill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count values',
      one: '1 value',
    );
    return ' — $_temp0 to fill in';
  }

  @override
  String get importSummaryTitle => 'Import summary';

  @override
  String importWarningsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things were',
      one: '1 thing was',
    );
    return '$_temp0 left out or changed:';
  }

  @override
  String importWarningsMore(int count) {
    return '…and $count more not shown';
  }

  @override
  String get importErrorTitle => 'Could not import';

  @override
  String get importCouldNotRead => 'Could not read that file.';

  @override
  String importCouldNotImportFile(Object error) {
    return 'Could not import that file: $error';
  }

  @override
  String get historyKicker => 'HISTORY';

  @override
  String get historyTitle => 'Request history';

  @override
  String get historyFilterHint => 'Filter history…';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyEmpty => 'No history yet — send a saved request.';

  @override
  String historyClearTitle(String project) {
    return 'Clear the history of \"$project\"?';
  }

  @override
  String get historyClearBody =>
      'This deletes every saved response of this project. Your requests, environments and flows are not touched.';

  @override
  String get historyClearConfirm => 'Clear';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get historyDeletedRequest => 'Deleted request';

  @override
  String get historyToday => 'TODAY';

  @override
  String get historyYesterday => 'YESTERDAY';

  @override
  String get historySaveToRecord =>
      'Save this request to start recording history';

  @override
  String get historyTabEmpty => 'No history yet — send a request';

  @override
  String get historyHistoricalLabel => 'Historical response — not live';

  @override
  String get historyTruncated => 'Body truncated to 100 KB';

  @override
  String historyErrorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get collectionsKicker => 'EXPLORER';

  @override
  String get collectionsNewFolder => 'New folder';

  @override
  String get collectionsPasteCurl => 'Paste curl';

  @override
  String get collectionsImportEllipsis => 'Import…';

  @override
  String get collectionsExportTooltip => 'Export endpoints (JSON)';

  @override
  String get collectionsFilterHint => 'Filter requests…';

  @override
  String get collectionsEmpty =>
      'No endpoints yet — create a folder to get started.';

  @override
  String collectionsVersion(String version) {
    return 'API Flow Studio $version';
  }

  @override
  String get collectionsExportTitle => 'Export endpoints';

  @override
  String collectionsExportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String get collectionsFolderName => 'Folder name';

  @override
  String get collectionsAddRequest => 'Add request';

  @override
  String get collectionsNewRequestName => 'New Request';

  @override
  String get collectionsDeleteFolder => 'Delete folder';

  @override
  String get collectionsDeleteFolderFirst =>
      'Delete this folder\'s contents first.';

  @override
  String get collectionsEmptyFolder => 'No endpoints yet — + Add request';

  @override
  String get collectionsDeleteRequest => 'Delete request';

  @override
  String get collectionsLoadWhat => 'collections';

  @override
  String get curlPasteTitle => 'Paste curl';

  @override
  String curlCouldNotParse(String message) {
    return 'Couldn\'t parse this curl command: $message';
  }

  @override
  String get requestUnsaved => 'UNSAVED';

  @override
  String get requestNoFolder => 'NO FOLDER';

  @override
  String get requestTabDocs => 'Docs';

  @override
  String get requestTabParams => 'Params';

  @override
  String get requestTabHeaders => 'Headers';

  @override
  String get requestTabBody => 'Body';

  @override
  String get requestTabAuth => 'Auth';

  @override
  String get requestTabTests => 'Tests';

  @override
  String get requestTabSettings => 'Settings';

  @override
  String get requestTestsOutOfScope => 'Tests are out of MVP scope';

  @override
  String get requestSettingsOutOfScope => 'Settings are out of MVP scope';

  @override
  String get requestDocsHint =>
      'Describe what this endpoint is for, when to use it, prerequisites, etc.';

  @override
  String get authBasic => 'Basic';

  @override
  String get authBearer => 'Bearer';

  @override
  String get authUsername => 'Username';

  @override
  String get authPassword => 'Password';

  @override
  String get authToken => 'Token';

  @override
  String get bodyJson => 'JSON';

  @override
  String get bodyFormUrlEncoded => 'Form URL-Encoded';

  @override
  String get bodyFormData => 'Form Data';

  @override
  String get bodyNone => 'This request has no body';

  @override
  String get bodyFormatJson => 'Format JSON';

  @override
  String get bodyInvalidJson => 'Invalid JSON';

  @override
  String get tableAddRow => 'Add row';

  @override
  String get multipartAddField => 'Add field';

  @override
  String get multipartText => 'Text';

  @override
  String get multipartFile => 'File';

  @override
  String get multipartPathHint => 'path to the file';

  @override
  String get multipartChoose => 'Choose…';

  @override
  String get multipartNoFile => 'No file chosen';

  @override
  String get responseCopy => 'Copy';

  @override
  String get responseNothingToCopy => 'Nothing to copy';

  @override
  String get responseCopied => 'Response copied';

  @override
  String get responseCurlCopied => 'curl copied';

  @override
  String get responseTabResponse => 'Response';

  @override
  String get responseTabHistory => 'History';

  @override
  String get responseNone => 'No response yet';

  @override
  String get responseNoneHint =>
      'Pick a request and send. Cmd/Ctrl + Enter also sends.';

  @override
  String responseErrorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get responseTabBody => 'Body';

  @override
  String get responseTabHeaders => 'Headers';

  @override
  String get responseTabCookies => 'Cookies';

  @override
  String get responseTabTimeline => 'Timeline';

  @override
  String get responseViewFormat => 'Format';

  @override
  String get responseViewRaw => 'Raw';

  @override
  String get responseViewPreview => 'Preview';

  @override
  String get responseNoCookies => 'No cookies';

  @override
  String responseTimeline(int ms) {
    return 'Request sent → response received, ${ms}ms';
  }

  @override
  String get commonActiveTag => 'ACTIVE';

  @override
  String get envKicker => 'ENVIRONMENTS';

  @override
  String get envNew => 'New Environment';

  @override
  String get envCreateFirst => 'Create your first environment to get started';

  @override
  String get envEmptyList =>
      'No environments yet — create your first one above.';

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
  String get envColumnName => 'NAME';

  @override
  String get envColumnValue => 'VALUE';

  @override
  String get envColumnSecret => 'SECRET';

  @override
  String get envAddVariable => 'Add variable';

  @override
  String get envProTip => 'Pro tip: Syntax & Resolution';

  @override
  String get envTipReference =>
      'Reference variables anywhere across URLs, headers, and payloads using the ';

  @override
  String get envTipSyntaxSuffix => ' syntax.';

  @override
  String get envTipGenerated => 'A fresh value is generated on every send: ';

  @override
  String get envVariableHint => 'Variable';

  @override
  String get envLoadWhat => 'environments';

  @override
  String get flowsKicker => 'FLOWS';

  @override
  String get flowsNew => 'New flow';

  @override
  String get flowsNewName => 'New Flow';

  @override
  String get flowsImportTooltip => 'Import flows';

  @override
  String get flowsExportTooltip => 'Export flows';

  @override
  String get flowsSelectOrCreate => 'Select or create a flow to get started';

  @override
  String get flowsEmptyList =>
      'No flows yet — create one to chain requests together.';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get flowsDelete => 'Delete flow';

  @override
  String get flowsSave => 'Save Flow';

  @override
  String get flowsRun => 'Run Flow';

  @override
  String get flowsNoSteps =>
      'No steps yet — add a saved endpoint to get started';

  @override
  String get flowsAddNextStep => 'Add Next Step to Pipeline';

  @override
  String get flowsLoadWhat => 'flows';

  @override
  String get flowsSelectAll => 'All flows';

  @override
  String get flowsNothingToExport => 'There are no flows to export yet';

  @override
  String get flowsExportTitle => 'Export flows';

  @override
  String get flowsImportTitle => 'Import flows';

  @override
  String flowsExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flows',
      one: '1 flow',
    );
    return 'Exported $_temp0 — credentials are not included';
  }

  @override
  String flowsExportFailed(Object error) {
    return 'Could not export the flows: $error';
  }

  @override
  String get flowsFileEmpty => 'That file has no flows in it.';

  @override
  String flowsImportFailed(Object error) {
    return 'Could not import the flows: $error';
  }

  @override
  String get flowsImportErrorTitle => 'Could not import the flows';

  @override
  String flowsImported(String flows, String details) {
    return 'Imported $flows$details';
  }

  @override
  String flowsImportedFlowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flows',
      one: '1 flow',
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
      other: '$count requests',
      one: '1 request',
    );
    return '$_temp0 added';
  }

  @override
  String flowsPartRequestsReused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
    );
    return '$_temp0 already there';
  }

  @override
  String flowsPartStepsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0 without a request';
  }

  @override
  String flowsPartFilesToChoose(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 to choose';
  }

  @override
  String get flowsFileTooLarge =>
      'That file is too large to be a flows file (the limit is 10 MB).';

  @override
  String get flowsFileNotJson => 'That file is not valid JSON.';

  @override
  String get flowsFileNotFlows =>
      'That file is not an API Flow Studio flows file.';

  @override
  String get flowsFileNewer =>
      'That file was made by a newer version of API Flow Studio. Update the app to open it.';

  @override
  String get flowsFileInvalid => 'That flows file is damaged or incomplete.';

  @override
  String get pickerAddStep => 'Add step';

  @override
  String get pickerUncategorized => 'Uncategorized';

  @override
  String get pickerNoSaved => 'No saved endpoints yet — save a request first.';

  @override
  String get pickerAllEndpoints => 'All endpoints';

  @override
  String get pickerSearchHint => 'Search endpoints…';

  @override
  String get pickerNoMatch => 'No endpoints match your search.';

  @override
  String get assertionsTitle => 'Assertions';

  @override
  String get assertionsAdd => 'Add assertion';

  @override
  String assertionsGot(String value) {
    return 'got \"$value\"';
  }

  @override
  String assertionsSummary(int passed, int total) {
    return '$passed/$total assertions';
  }

  @override
  String get errorUnknown => 'Unknown Error';

  @override
  String get errorAssertionFailure => 'Assertion Failure';

  @override
  String get errorConfiguration => 'Configuration Error';

  @override
  String get errorNetwork => 'Network Error';

  @override
  String get runReRunFlow => 'Re-run Flow';

  @override
  String runPassed(int count) {
    return '$count passed';
  }

  @override
  String runFailed(int count) {
    return '$count failed';
  }

  @override
  String runSkipped(int count) {
    return '$count skipped';
  }

  @override
  String get runSelectStep => 'Select a step to see its details';

  @override
  String get runMissingEndpoint => 'Missing endpoint';

  @override
  String get runSkippedStep => 'Skipped';

  @override
  String get inspectorErrorDetails => 'Error Details';

  @override
  String get inspectorRequestSent => 'Request Sent';

  @override
  String get inspectorResponseBody => 'Response Body';

  @override
  String get inspectorNoRequest => 'No request was sent';

  @override
  String get inspectorNoResponse => 'No response received';

  @override
  String inspectorRerunFrom(int step) {
    return 'Re-run From Step $step';
  }

  @override
  String stepMissingEndpoint(String id) {
    return 'Missing endpoint ($id)';
  }

  @override
  String get stepTerminal => 'TERMINAL';

  @override
  String get stepPayloadTemplate => 'PAYLOAD TEMPLATE';

  @override
  String get stepExtractTitle => 'Extract Output Variables';

  @override
  String get stepAddExtracted => 'Add extracted variable';

  @override
  String get stepStopOnFailure => 'Stop on failure';

  @override
  String get multipartNameHint => 'name';

  @override
  String get multipartAutoHint => 'auto';

  @override
  String get multipartValueHint => 'value';

  @override
  String get assertionExpectedHint => 'expected';

  @override
  String get stepChangeRequest => 'Change request';

  @override
  String get multipartFileNotInBrowser =>
      'File fields can\'t be sent from a web page. Use the desktop app.';

  @override
  String get browserHintCors =>
      'In a web page a network error is often CORS: the API must allow this page\'s origin. The desktop app does not have this limit.';

  @override
  String get browserHintMixedContent =>
      'This page is served over https, so the browser blocks calls to a plain http:// address (except localhost). Use https:// or the desktop app.';

  @override
  String get responseCookiesHiddenInBrowser =>
      'A web page cannot read Set-Cookie: the browser keeps it hidden. Use the desktop app to see cookies.';

  @override
  String get storageFull =>
      'The browser has no room left, so the last change was not saved. Export your workspace and clear some history.';
}
