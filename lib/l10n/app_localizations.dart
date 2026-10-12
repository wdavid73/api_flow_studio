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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'API Flow Studio'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get commonKey;

  /// No description provided for @commonValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get commonValue;

  /// No description provided for @commonHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get commonHeaders;

  /// No description provided for @commonNoHeaders.
  ///
  /// In en, this message translates to:
  /// **'No headers'**
  String get commonNoHeaders;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonTimeMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String commonTimeMs(int ms);

  /// No description provided for @commonSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{bytes} B'**
  String commonSizeBytes(int bytes);

  /// No description provided for @commonNothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that search.'**
  String get commonNothingMatches;

  /// No description provided for @commonFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load {what}: {error}'**
  String commonFailedToLoad(String what, Object error);

  /// No description provided for @languageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageTooltip;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @navWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get navWorkspace;

  /// No description provided for @navEnvironments.
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get navEnvironments;

  /// No description provided for @navFlows.
  ///
  /// In en, this message translates to:
  /// **'Flows'**
  String get navFlows;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @headerTagline.
  ///
  /// In en, this message translates to:
  /// **'API playground'**
  String get headerTagline;

  /// No description provided for @headerMoreEnvironments.
  ///
  /// In en, this message translates to:
  /// **'More environments'**
  String get headerMoreEnvironments;

  /// No description provided for @hostsButton.
  ///
  /// In en, this message translates to:
  /// **'Hosts & notes'**
  String get hostsButton;

  /// No description provided for @hostsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Hosts by environment'**
  String get hostsDialogTitle;

  /// No description provided for @hostsAddHost.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get hostsAddHost;

  /// No description provided for @hostsHelp.
  ///
  /// In en, this message translates to:
  /// **'Hosts are environment variables whose value is a URL. Edit a cell to change it in that environment; clear it to remove the variable there.'**
  String get hostsHelp;

  /// No description provided for @hostsEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get hostsEnterName;

  /// No description provided for @hostsNameChars.
  ///
  /// In en, this message translates to:
  /// **'Use letters, digits and underscores only.'**
  String get hostsNameChars;

  /// No description provided for @hostsNameUsedBySecret.
  ///
  /// In en, this message translates to:
  /// **'A secret variable already uses that name.'**
  String get hostsNameUsedBySecret;

  /// No description provided for @hostsAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'That host already exists.'**
  String get hostsAlreadyExists;

  /// No description provided for @hostsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No hosts yet — add an environment variable whose value is a URL, or use Add host.'**
  String get hostsEmpty;

  /// No description provided for @hostsColumnHost.
  ///
  /// In en, this message translates to:
  /// **'HOST'**
  String get hostsColumnHost;

  /// No description provided for @hostsColumnNote.
  ///
  /// In en, this message translates to:
  /// **'NOTE'**
  String get hostsColumnNote;

  /// No description provided for @hostsNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note…'**
  String get hostsNoteHint;

  /// No description provided for @hostsUsedBy.
  ///
  /// In en, this message translates to:
  /// **'Used by {count, plural, =1{1 request} other{{count} requests}}'**
  String hostsUsedBy(int count);

  /// No description provided for @hostsAllDefined.
  ///
  /// In en, this message translates to:
  /// **'Every host is defined in every environment.'**
  String get hostsAllDefined;

  /// No description provided for @hostsActiveTag.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get hostsActiveTag;

  /// No description provided for @hostsWarningNotDefinedIn.
  ///
  /// In en, this message translates to:
  /// **' isn\'t defined in {environments}. Requests that use '**
  String hostsWarningNotDefinedIn(String environments);

  /// No description provided for @hostsWarningUnresolved.
  ///
  /// In en, this message translates to:
  /// **' will be sent with that text unresolved there.'**
  String get hostsWarningUnresolved;

  /// No description provided for @sessionNoToken.
  ///
  /// In en, this message translates to:
  /// **'No token'**
  String get sessionNoToken;

  /// No description provided for @sessionKeptInMemory.
  ///
  /// In en, this message translates to:
  /// **'kept in memory only'**
  String get sessionKeptInMemory;

  /// No description provided for @sessionTokenSaved.
  ///
  /// In en, this message translates to:
  /// **'Token saved'**
  String get sessionTokenSaved;

  /// No description provided for @sessionTokenExpired.
  ///
  /// In en, this message translates to:
  /// **'Token expired'**
  String get sessionTokenExpired;

  /// No description provided for @sessionExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {minutes} min'**
  String sessionExpiresInMinutes(int minutes);

  /// No description provided for @sessionExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours} h'**
  String sessionExpiresInHours(int hours);

  /// No description provided for @sessionNoEnvironment.
  ///
  /// In en, this message translates to:
  /// **'No environment'**
  String get sessionNoEnvironment;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session · {environment}'**
  String sessionTitle(String environment);

  /// No description provided for @sessionNotJwt.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t look like a JWT. It is still sent as a Bearer.'**
  String get sessionNotJwt;

  /// No description provided for @sessionSubject.
  ///
  /// In en, this message translates to:
  /// **'sub {subject}'**
  String sessionSubject(String subject);

  /// No description provided for @sessionAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get sessionAccessToken;

  /// No description provided for @sessionRefreshToken.
  ///
  /// In en, this message translates to:
  /// **'Refresh token'**
  String get sessionRefreshToken;

  /// No description provided for @sessionShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get sessionShow;

  /// No description provided for @sessionSendAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Send Authorization'**
  String get sessionSendAuthorization;

  /// No description provided for @sessionCaptureTokens.
  ///
  /// In en, this message translates to:
  /// **'Capture tokens from 2xx'**
  String get sessionCaptureTokens;

  /// No description provided for @sessionClearTokens.
  ///
  /// In en, this message translates to:
  /// **'Clear tokens'**
  String get sessionClearTokens;

  /// No description provided for @sessionTokensCaptured.
  ///
  /// In en, this message translates to:
  /// **'Tokens captured for {environment}'**
  String sessionTokensCaptured(String environment);

  /// No description provided for @workspaceExported.
  ///
  /// In en, this message translates to:
  /// **'Workspace \"{name}\" exported — secrets are not included'**
  String workspaceExported(String name);

  /// No description provided for @workspaceCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save the workspace: {error}'**
  String workspaceCouldNotSave(Object error);

  /// No description provided for @workspaceCouldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file: {error}'**
  String workspaceCouldNotReadFile(Object error);

  /// No description provided for @workspaceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String workspaceImported(String name);

  /// No description provided for @workspaceImportedToFill.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\" — {count, plural, =1{1 value} other{{count} values}} to fill in'**
  String workspaceImportedToFill(String name, int count);

  /// No description provided for @workspaceCouldNotImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not import the workspace'**
  String get workspaceCouldNotImportTitle;

  /// No description provided for @workspaceCouldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Could not import the workspace: {error}'**
  String workspaceCouldNotImport(Object error);

  /// No description provided for @projectNew.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectNew;

  /// No description provided for @projectNewEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New project…'**
  String get projectNewEllipsis;

  /// No description provided for @projectRename.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get projectRename;

  /// No description provided for @projectRenameEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Rename project…'**
  String get projectRenameEllipsis;

  /// No description provided for @projectSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get projectSwitch;

  /// No description provided for @projectExportWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Export workspace…'**
  String get projectExportWorkspace;

  /// No description provided for @projectImportWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Import workspace…'**
  String get projectImportWorkspace;

  /// No description provided for @projectDeleteEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Delete project…'**
  String get projectDeleteEllipsis;

  /// No description provided for @projectCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Project \"{name}\" created'**
  String projectCreatedToast(String name);

  /// No description provided for @projectRenamedToast.
  ///
  /// In en, this message translates to:
  /// **'Project renamed to \"{name}\"'**
  String projectRenamedToast(String name);

  /// No description provided for @projectDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Project \"{name}\" deleted'**
  String projectDeletedToast(String name);

  /// No description provided for @projectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String projectDeleteTitle(String name);

  /// No description provided for @projectDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes its environments, collections, flows and history. It cannot be undone.'**
  String get projectDeleteBody;

  /// No description provided for @projectNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Give the project a name.'**
  String get projectNameEmpty;

  /// No description provided for @projectNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Names are limited to {max} characters.'**
  String projectNameTooLong(int max);

  /// No description provided for @projectNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A project with that name already exists.'**
  String get projectNameDuplicate;

  /// No description provided for @projectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameHint;

  /// No description provided for @projectColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get projectColor;

  /// No description provided for @importDescribe.
  ///
  /// In en, this message translates to:
  /// **'Imported {source}: {parts}{fill}'**
  String importDescribe(String source, String parts, String fill);

  /// No description provided for @importPartsRequestsInFolders.
  ///
  /// In en, this message translates to:
  /// **'{requests, plural, =1{1 request} other{{requests} requests}} in {folders, plural, =1{1 folder} other{{folders} folders}}'**
  String importPartsRequestsInFolders(int requests, int folders);

  /// No description provided for @importPartsEnvironments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 environment} other{{count} environments}}'**
  String importPartsEnvironments(int count);

  /// No description provided for @importPartsNothing.
  ///
  /// In en, this message translates to:
  /// **'nothing'**
  String get importPartsNothing;

  /// No description provided for @importValuesToFill.
  ///
  /// In en, this message translates to:
  /// **' — {count, plural, =1{1 value} other{{count} values}} to fill in'**
  String importValuesToFill(int count);

  /// No description provided for @importSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Import summary'**
  String get importSummaryTitle;

  /// No description provided for @importWarningsHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing was} other{{count} things were}} left out or changed:'**
  String importWarningsHeader(int count);

  /// No description provided for @importWarningsMore.
  ///
  /// In en, this message translates to:
  /// **'…and {count} more not shown'**
  String importWarningsMore(int count);

  /// No description provided for @importErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not import'**
  String get importErrorTitle;

  /// No description provided for @importCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file.'**
  String get importCouldNotRead;

  /// No description provided for @importCouldNotImportFile.
  ///
  /// In en, this message translates to:
  /// **'Could not import that file: {error}'**
  String importCouldNotImportFile(Object error);

  /// No description provided for @historyKicker.
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get historyKicker;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Request history'**
  String get historyTitle;

  /// No description provided for @historyFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter history…'**
  String get historyFilterHint;

  /// No description provided for @historyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClear;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet — send a saved request.'**
  String get historyEmpty;

  /// No description provided for @historyClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the history of \"{project}\"?'**
  String historyClearTitle(String project);

  /// No description provided for @historyClearBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes every saved response of this project. Your requests, environments and flows are not touched.'**
  String get historyClearBody;

  /// No description provided for @historyClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get historyClearConfirm;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// No description provided for @historyDeletedRequest.
  ///
  /// In en, this message translates to:
  /// **'Deleted request'**
  String get historyDeletedRequest;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get historyYesterday;

  /// No description provided for @historySaveToRecord.
  ///
  /// In en, this message translates to:
  /// **'Save this request to start recording history'**
  String get historySaveToRecord;

  /// No description provided for @historyTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet — send a request'**
  String get historyTabEmpty;

  /// No description provided for @historyHistoricalLabel.
  ///
  /// In en, this message translates to:
  /// **'Historical response — not live'**
  String get historyHistoricalLabel;

  /// No description provided for @historyTruncated.
  ///
  /// In en, this message translates to:
  /// **'Body truncated to 100 KB'**
  String get historyTruncated;

  /// No description provided for @historyErrorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String historyErrorWithMessage(String message);

  /// No description provided for @collectionsKicker.
  ///
  /// In en, this message translates to:
  /// **'EXPLORER'**
  String get collectionsKicker;

  /// No description provided for @collectionsNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get collectionsNewFolder;

  /// No description provided for @collectionsPasteCurl.
  ///
  /// In en, this message translates to:
  /// **'Paste curl'**
  String get collectionsPasteCurl;

  /// No description provided for @collectionsImportEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import…'**
  String get collectionsImportEllipsis;

  /// No description provided for @collectionsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export endpoints (JSON)'**
  String get collectionsExportTooltip;

  /// No description provided for @collectionsFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter requests…'**
  String get collectionsFilterHint;

  /// No description provided for @collectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No endpoints yet — create a folder to get started.'**
  String get collectionsEmpty;

  /// No description provided for @collectionsVersion.
  ///
  /// In en, this message translates to:
  /// **'API Flow Studio {version}'**
  String collectionsVersion(String version);

  /// No description provided for @collectionsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export endpoints'**
  String get collectionsExportTitle;

  /// No description provided for @collectionsExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String collectionsExportedTo(String path);

  /// No description provided for @collectionsFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get collectionsFolderName;

  /// No description provided for @collectionsAddRequest.
  ///
  /// In en, this message translates to:
  /// **'Add request'**
  String get collectionsAddRequest;

  /// No description provided for @collectionsNewRequestName.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get collectionsNewRequestName;

  /// No description provided for @collectionsDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get collectionsDeleteFolder;

  /// No description provided for @collectionsDeleteFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Delete this folder\'s contents first.'**
  String get collectionsDeleteFolderFirst;

  /// No description provided for @collectionsEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'No endpoints yet — + Add request'**
  String get collectionsEmptyFolder;

  /// No description provided for @collectionsDeleteRequest.
  ///
  /// In en, this message translates to:
  /// **'Delete request'**
  String get collectionsDeleteRequest;

  /// No description provided for @collectionsLoadWhat.
  ///
  /// In en, this message translates to:
  /// **'collections'**
  String get collectionsLoadWhat;

  /// No description provided for @curlPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste curl'**
  String get curlPasteTitle;

  /// No description provided for @curlCouldNotParse.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t parse this curl command: {message}'**
  String curlCouldNotParse(String message);

  /// No description provided for @requestUnsaved.
  ///
  /// In en, this message translates to:
  /// **'UNSAVED'**
  String get requestUnsaved;

  /// No description provided for @requestNoFolder.
  ///
  /// In en, this message translates to:
  /// **'NO FOLDER'**
  String get requestNoFolder;

  /// No description provided for @requestTabDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get requestTabDocs;

  /// No description provided for @requestTabParams.
  ///
  /// In en, this message translates to:
  /// **'Params'**
  String get requestTabParams;

  /// No description provided for @requestTabHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get requestTabHeaders;

  /// No description provided for @requestTabBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get requestTabBody;

  /// No description provided for @requestTabAuth.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get requestTabAuth;

  /// No description provided for @requestTabTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get requestTabTests;

  /// No description provided for @requestTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get requestTabSettings;

  /// No description provided for @requestTestsOutOfScope.
  ///
  /// In en, this message translates to:
  /// **'Tests are out of MVP scope'**
  String get requestTestsOutOfScope;

  /// No description provided for @requestSettingsOutOfScope.
  ///
  /// In en, this message translates to:
  /// **'Settings are out of MVP scope'**
  String get requestSettingsOutOfScope;

  /// No description provided for @requestDocsHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what this endpoint is for, when to use it, prerequisites, etc.'**
  String get requestDocsHint;

  /// No description provided for @authBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get authBasic;

  /// No description provided for @authBearer.
  ///
  /// In en, this message translates to:
  /// **'Bearer'**
  String get authBearer;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get authToken;

  /// No description provided for @bodyJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get bodyJson;

  /// No description provided for @bodyFormUrlEncoded.
  ///
  /// In en, this message translates to:
  /// **'Form URL-Encoded'**
  String get bodyFormUrlEncoded;

  /// No description provided for @bodyFormData.
  ///
  /// In en, this message translates to:
  /// **'Form Data'**
  String get bodyFormData;

  /// No description provided for @bodyNone.
  ///
  /// In en, this message translates to:
  /// **'This request has no body'**
  String get bodyNone;

  /// No description provided for @bodyFormatJson.
  ///
  /// In en, this message translates to:
  /// **'Format JSON'**
  String get bodyFormatJson;

  /// No description provided for @bodyInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get bodyInvalidJson;

  /// No description provided for @tableAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get tableAddRow;

  /// No description provided for @multipartAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get multipartAddField;

  /// No description provided for @multipartText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get multipartText;

  /// No description provided for @multipartFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get multipartFile;

  /// No description provided for @multipartPathHint.
  ///
  /// In en, this message translates to:
  /// **'path to the file'**
  String get multipartPathHint;

  /// No description provided for @multipartChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get multipartChoose;

  /// No description provided for @multipartNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get multipartNoFile;

  /// No description provided for @responseCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get responseCopy;

  /// No description provided for @responseNothingToCopy.
  ///
  /// In en, this message translates to:
  /// **'Nothing to copy'**
  String get responseNothingToCopy;

  /// No description provided for @responseCopied.
  ///
  /// In en, this message translates to:
  /// **'Response copied'**
  String get responseCopied;

  /// No description provided for @responseCurlCopied.
  ///
  /// In en, this message translates to:
  /// **'curl copied'**
  String get responseCurlCopied;

  /// No description provided for @responseTabResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get responseTabResponse;

  /// No description provided for @responseTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get responseTabHistory;

  /// No description provided for @responseNone.
  ///
  /// In en, this message translates to:
  /// **'No response yet'**
  String get responseNone;

  /// No description provided for @responseNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a request and send. Cmd/Ctrl + Enter also sends.'**
  String get responseNoneHint;

  /// No description provided for @responseErrorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String responseErrorWithMessage(String message);

  /// No description provided for @responseTabBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get responseTabBody;

  /// No description provided for @responseTabHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get responseTabHeaders;

  /// No description provided for @responseTabCookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get responseTabCookies;

  /// No description provided for @responseTabTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get responseTabTimeline;

  /// No description provided for @responseViewFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get responseViewFormat;

  /// No description provided for @responseViewRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get responseViewRaw;

  /// No description provided for @responseViewPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get responseViewPreview;

  /// No description provided for @responseNoCookies.
  ///
  /// In en, this message translates to:
  /// **'No cookies'**
  String get responseNoCookies;

  /// No description provided for @responseTimeline.
  ///
  /// In en, this message translates to:
  /// **'Request sent → response received, {ms}ms'**
  String responseTimeline(int ms);

  /// No description provided for @commonActiveTag.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get commonActiveTag;

  /// No description provided for @envKicker.
  ///
  /// In en, this message translates to:
  /// **'ENVIRONMENTS'**
  String get envKicker;

  /// No description provided for @envNew.
  ///
  /// In en, this message translates to:
  /// **'New Environment'**
  String get envNew;

  /// No description provided for @envCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create your first environment to get started'**
  String get envCreateFirst;

  /// No description provided for @envEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No environments yet — create your first one above.'**
  String get envEmptyList;

  /// No description provided for @envVariableCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 variable} other{{count} variables}}'**
  String envVariableCount(int count);

  /// No description provided for @envColumnName.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get envColumnName;

  /// No description provided for @envColumnValue.
  ///
  /// In en, this message translates to:
  /// **'VALUE'**
  String get envColumnValue;

  /// No description provided for @envColumnSecret.
  ///
  /// In en, this message translates to:
  /// **'SECRET'**
  String get envColumnSecret;

  /// No description provided for @envAddVariable.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get envAddVariable;

  /// No description provided for @envProTip.
  ///
  /// In en, this message translates to:
  /// **'Pro tip: Syntax & Resolution'**
  String get envProTip;

  /// No description provided for @envTipReference.
  ///
  /// In en, this message translates to:
  /// **'Reference variables anywhere across URLs, headers, and payloads using the '**
  String get envTipReference;

  /// No description provided for @envTipSyntaxSuffix.
  ///
  /// In en, this message translates to:
  /// **' syntax.'**
  String get envTipSyntaxSuffix;

  /// No description provided for @envTipGenerated.
  ///
  /// In en, this message translates to:
  /// **'A fresh value is generated on every send: '**
  String get envTipGenerated;

  /// No description provided for @envVariableHint.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get envVariableHint;

  /// No description provided for @envLoadWhat.
  ///
  /// In en, this message translates to:
  /// **'environments'**
  String get envLoadWhat;

  /// No description provided for @flowsKicker.
  ///
  /// In en, this message translates to:
  /// **'FLOWS'**
  String get flowsKicker;

  /// No description provided for @flowsNew.
  ///
  /// In en, this message translates to:
  /// **'New flow'**
  String get flowsNew;

  /// No description provided for @flowsNewName.
  ///
  /// In en, this message translates to:
  /// **'New Flow'**
  String get flowsNewName;

  /// No description provided for @flowsImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import flows'**
  String get flowsImportTooltip;

  /// No description provided for @flowsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export flows'**
  String get flowsExportTooltip;

  /// No description provided for @flowsSelectOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Select or create a flow to get started'**
  String get flowsSelectOrCreate;

  /// No description provided for @flowsEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No flows yet — create one to chain requests together.'**
  String get flowsEmptyList;

  /// No description provided for @flowsStepCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String flowsStepCount(int count);

  /// No description provided for @flowsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete flow'**
  String get flowsDelete;

  /// No description provided for @flowsSave.
  ///
  /// In en, this message translates to:
  /// **'Save Flow'**
  String get flowsSave;

  /// No description provided for @flowsRun.
  ///
  /// In en, this message translates to:
  /// **'Run Flow'**
  String get flowsRun;

  /// No description provided for @flowsNoSteps.
  ///
  /// In en, this message translates to:
  /// **'No steps yet — add a saved endpoint to get started'**
  String get flowsNoSteps;

  /// No description provided for @flowsAddNextStep.
  ///
  /// In en, this message translates to:
  /// **'Add Next Step to Pipeline'**
  String get flowsAddNextStep;

  /// No description provided for @flowsLoadWhat.
  ///
  /// In en, this message translates to:
  /// **'flows'**
  String get flowsLoadWhat;

  /// No description provided for @flowsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All flows'**
  String get flowsSelectAll;

  /// No description provided for @flowsNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'There are no flows to export yet'**
  String get flowsNothingToExport;

  /// No description provided for @flowsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export flows'**
  String get flowsExportTitle;

  /// No description provided for @flowsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import flows'**
  String get flowsImportTitle;

  /// No description provided for @flowsExported.
  ///
  /// In en, this message translates to:
  /// **'Exported {count, plural, =1{1 flow} other{{count} flows}} — credentials are not included'**
  String flowsExported(int count);

  /// No description provided for @flowsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the flows: {error}'**
  String flowsExportFailed(Object error);

  /// No description provided for @flowsFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file has no flows in it.'**
  String get flowsFileEmpty;

  /// No description provided for @flowsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import the flows: {error}'**
  String flowsImportFailed(Object error);

  /// No description provided for @flowsImportErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not import the flows'**
  String get flowsImportErrorTitle;

  /// No description provided for @flowsImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {flows}{details}'**
  String flowsImported(String flows, String details);

  /// No description provided for @flowsImportedFlowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 flow} other{{count} flows}}'**
  String flowsImportedFlowCount(int count);

  /// No description provided for @flowsImportedDetails.
  ///
  /// In en, this message translates to:
  /// **' — {parts}'**
  String flowsImportedDetails(String parts);

  /// No description provided for @flowsPartRequestsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 request} other{{count} requests}} added'**
  String flowsPartRequestsAdded(int count);

  /// No description provided for @flowsPartRequestsReused.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 request} other{{count} requests}} already there'**
  String flowsPartRequestsReused(int count);

  /// No description provided for @flowsPartStepsMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}} without a request'**
  String flowsPartStepsMissing(int count);

  /// No description provided for @flowsPartFilesToChoose.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}} to choose'**
  String flowsPartFilesToChoose(int count);

  /// No description provided for @flowsFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large to be a flows file (the limit is 10 MB).'**
  String get flowsFileTooLarge;

  /// No description provided for @flowsFileNotJson.
  ///
  /// In en, this message translates to:
  /// **'That file is not valid JSON.'**
  String get flowsFileNotJson;

  /// No description provided for @flowsFileNotFlows.
  ///
  /// In en, this message translates to:
  /// **'That file is not an API Flow Studio flows file.'**
  String get flowsFileNotFlows;

  /// No description provided for @flowsFileNewer.
  ///
  /// In en, this message translates to:
  /// **'That file was made by a newer version of API Flow Studio. Update the app to open it.'**
  String get flowsFileNewer;

  /// No description provided for @flowsFileInvalid.
  ///
  /// In en, this message translates to:
  /// **'That flows file is damaged or incomplete.'**
  String get flowsFileInvalid;

  /// No description provided for @pickerAddStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get pickerAddStep;

  /// No description provided for @pickerUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get pickerUncategorized;

  /// No description provided for @pickerNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved endpoints yet — save a request first.'**
  String get pickerNoSaved;

  /// No description provided for @pickerAllEndpoints.
  ///
  /// In en, this message translates to:
  /// **'All endpoints'**
  String get pickerAllEndpoints;

  /// No description provided for @pickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search endpoints…'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No endpoints match your search.'**
  String get pickerNoMatch;

  /// No description provided for @assertionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assertions'**
  String get assertionsTitle;

  /// No description provided for @assertionsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add assertion'**
  String get assertionsAdd;

  /// No description provided for @assertionsGot.
  ///
  /// In en, this message translates to:
  /// **'got \"{value}\"'**
  String assertionsGot(String value);

  /// No description provided for @assertionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{passed}/{total} assertions'**
  String assertionsSummary(int passed, int total);

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Error'**
  String get errorUnknown;

  /// No description provided for @errorAssertionFailure.
  ///
  /// In en, this message translates to:
  /// **'Assertion Failure'**
  String get errorAssertionFailure;

  /// No description provided for @errorConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration Error'**
  String get errorConfiguration;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network Error'**
  String get errorNetwork;

  /// No description provided for @runReRunFlow.
  ///
  /// In en, this message translates to:
  /// **'Re-run Flow'**
  String get runReRunFlow;

  /// No description provided for @runPassed.
  ///
  /// In en, this message translates to:
  /// **'{count} passed'**
  String runPassed(int count);

  /// No description provided for @runFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String runFailed(int count);

  /// No description provided for @runSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String runSkipped(int count);

  /// No description provided for @runSelectStep.
  ///
  /// In en, this message translates to:
  /// **'Select a step to see its details'**
  String get runSelectStep;

  /// No description provided for @runMissingEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Missing endpoint'**
  String get runMissingEndpoint;

  /// No description provided for @runSkippedStep.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get runSkippedStep;

  /// No description provided for @inspectorErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error Details'**
  String get inspectorErrorDetails;

  /// No description provided for @inspectorRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent'**
  String get inspectorRequestSent;

  /// No description provided for @inspectorResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Response Body'**
  String get inspectorResponseBody;

  /// No description provided for @inspectorNoRequest.
  ///
  /// In en, this message translates to:
  /// **'No request was sent'**
  String get inspectorNoRequest;

  /// No description provided for @inspectorNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No response received'**
  String get inspectorNoResponse;

  /// No description provided for @inspectorRerunFrom.
  ///
  /// In en, this message translates to:
  /// **'Re-run From Step {step}'**
  String inspectorRerunFrom(int step);

  /// No description provided for @stepMissingEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Missing endpoint ({id})'**
  String stepMissingEndpoint(String id);

  /// No description provided for @stepTerminal.
  ///
  /// In en, this message translates to:
  /// **'TERMINAL'**
  String get stepTerminal;

  /// No description provided for @stepPayloadTemplate.
  ///
  /// In en, this message translates to:
  /// **'PAYLOAD TEMPLATE'**
  String get stepPayloadTemplate;

  /// No description provided for @stepExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Output Variables'**
  String get stepExtractTitle;

  /// No description provided for @stepAddExtracted.
  ///
  /// In en, this message translates to:
  /// **'Add extracted variable'**
  String get stepAddExtracted;

  /// No description provided for @stepStopOnFailure.
  ///
  /// In en, this message translates to:
  /// **'Stop on failure'**
  String get stepStopOnFailure;

  /// No description provided for @multipartNameHint.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get multipartNameHint;

  /// No description provided for @multipartAutoHint.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get multipartAutoHint;

  /// No description provided for @multipartValueHint.
  ///
  /// In en, this message translates to:
  /// **'value'**
  String get multipartValueHint;

  /// No description provided for @assertionExpectedHint.
  ///
  /// In en, this message translates to:
  /// **'expected'**
  String get assertionExpectedHint;

  /// No description provided for @stepChangeRequest.
  ///
  /// In en, this message translates to:
  /// **'Change request'**
  String get stepChangeRequest;
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
