import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achvH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'14 of 42 earned'**
  String get achvSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Add all to list'**
  String get addAll;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get addManualItem;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addPhoto;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get addStep;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Add to shopping list'**
  String get addToList;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Added to your shopping list'**
  String get addedToList;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'I grew up on this'**
  String get adv;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Teach me the fifty-year techniques.'**
  String get advS;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'FRESH'**
  String get aisleFresh;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'MEAT & DAIRY'**
  String get aisleMeat;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'PANTRY'**
  String get aislePantry;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'SPICE & DRY'**
  String get aisleSpice;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'FlameUp'**
  String get appName;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get askAssistant;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Ask about a substitution, a step, or why something went wrong.'**
  String get assistantHint;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get assistantPlaceholder;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'You already signed up with a different method.'**
  String get authErrorAccountExistsDifferentCredential;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Those credentials belong to another account.'**
  String get authErrorCredentialInUse;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'An account already uses that email.'**
  String get authErrorEmailInUse;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'We could not sign you in.'**
  String get authErrorGeneric;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authErrorInvalidCredentials;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That email address is not valid.'**
  String get authErrorInvalidEmail;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That sign-in method is not enabled.'**
  String get authErrorOperationNotAllowed;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That account is already linked.'**
  String get authErrorProviderAlreadyLinked;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get authErrorRequiresRecentLogin;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'You are signed out. Sign in to continue.'**
  String get authErrorSignedOut;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again shortly.'**
  String get authErrorTooManyRequests;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrorUserDisabled;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Choose a longer password.'**
  String get authErrorWeakPassword;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Onion Patience'**
  String get badgeName;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Dry-cooked onions for a full 15 minutes without cheating.'**
  String get badgeSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'I can boil water and follow instructions.'**
  String get beginnerS;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Seven dishes, one injera, photographed together. Judged by three cooks from Addis.'**
  String get chBody;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get chH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'LIVE · ENDS IN 2 DAYS'**
  String get chLive;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get chPast;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook the whole fasting plate'**
  String get chTitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'FROM THIS RECIPE'**
  String get claimRecipe;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'AI SUGGESTION'**
  String get claimSuggestion;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'COMMON PRACTICE'**
  String get claimTradition;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Clear checked'**
  String get clearDone;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'When family comes'**
  String get colBig;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Fasting nights'**
  String get colFast;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Weeknight fast'**
  String get colQuick;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook a Gurage dish'**
  String get cookOne;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook tonight'**
  String get cookTonight;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'No dairy'**
  String get dDairy;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Fasting / vegan'**
  String get dFast;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'No gluten'**
  String get dGluten;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Meat lover'**
  String get dMeat;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Under 30 min'**
  String get dQuick;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Raw dishes ok'**
  String get dRaw;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'ANYTHING WE SHOULD KNOW?'**
  String get dietary;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Dishes from here'**
  String get dishesFrom;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Doro Wat, done.'**
  String get doneH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Four hours of onion patience. That is the hard one out of the way.'**
  String get doneSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Doro Wat · step 3 of 9'**
  String get doroWat;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Find something to cook'**
  String get empCta;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get empH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on any recipe and it lands here, ready offline.'**
  String get empSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get errBack;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'That flame went out.'**
  String get errH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'We could not load the recipe. Your timer is still running in the background.'**
  String get errSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'We received an unexpected response.'**
  String get errorBadResponse;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Could not read saved data.'**
  String get errorCache;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get errorCancelled;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That has already been saved.'**
  String get errorConflict;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That request was not valid.'**
  String get errorInvalidRequest;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'We could not find that.'**
  String get errorNotFound;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errorOffline;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get errorPermission;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side.'**
  String get errorServer;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'That took too long. Try again.'**
  String get errorTimeout;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnknown;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'explored'**
  String get explored;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get fAll;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get fFast;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Mitmita hot'**
  String get fHot;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Dish name'**
  String get fName;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Name in Amharic'**
  String get fNameAm;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'New to me'**
  String get fNew;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Photo of the dish'**
  String get fPhoto;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Under 30m'**
  String get fQuick;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get fSteps;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Write it the way they said it.'**
  String get fStepsP;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Tigray'**
  String get fTigray;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Who taught you?'**
  String get fWho;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Grandmother, Mekelle'**
  String get fWhoP;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get feedH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Sixty-one people cooked tonight.'**
  String get feedSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fieldName;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Finish dish'**
  String get finish;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotLink;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Check your email for the reset link.'**
  String get forgotSent;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a link to set a new one.'**
  String get forgotSubtitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'2 freeze days left'**
  String get freeze;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Miss a day without losing the flame.'**
  String get freezeSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Where it comes from'**
  String get fromRegion;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Build shopping list from plan'**
  String get generateList;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Light the first flame'**
  String get getStarted;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Grandma’s Kitchen'**
  String get grandmaH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Recorded in home kitchens, unedited, with the pauses left in.'**
  String get grandmaSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Selam, good evening'**
  String get greeting;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestBadge;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Gurage — kitfo, kocho, and the long grind'**
  String get gurageTitle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get h1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get h2;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get h3;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get h4;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Mitmita'**
  String get h5;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccount;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'HEAT'**
  String get heatLbl;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'HEAT TOLERANCE'**
  String get heatLevel;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Getting there'**
  String get inter;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'I’ve made shiro and it went fine.'**
  String get interS;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Invite someone to cook with you'**
  String get invite;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Streaks last longer in pairs.'**
  String get inviteSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Join the challenge'**
  String get join;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'312 joined'**
  String get joined;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get lbFriends;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get lbGlobal;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get lbH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Addis'**
  String get lbRegion;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Level 12 · Wot Wanderer'**
  String get levelNow;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Wot Wanderer'**
  String get lvlName;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'LEVEL 12'**
  String get lvlNo;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Taste Ethiopia'**
  String get mapH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'MAP · REGION SHAPES'**
  String get mapPh;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Nine regions, nine ways to cook the same grain.'**
  String get mapSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get masteryH;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'What your hands know'**
  String get masteryH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Mastery climbs when you repeat a technique, not when you finish a recipe.'**
  String get masterySub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextStep;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccountYet;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'What would you do differently next time?'**
  String get noteP;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofWord;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'OFFLINE · CACHED'**
  String get offBanner;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook from downloads'**
  String get offCta;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Eighteen recipes are on this phone, including everything you started this week.'**
  String get offSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'PICK UP WHERE YOU LEFT'**
  String get pickUp;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get planEmpty;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Meal planner'**
  String get planH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Drag a dish onto a night.'**
  String get planSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'No meals planned yet'**
  String get plannerEmpty;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Pick a night and choose something to cook.'**
  String get plannerEmptySub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Post to community'**
  String get postToComm;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get qDaily;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'FASTING SEASON'**
  String get qSeason;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get qWeekly;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'2 of 3 done this week'**
  String get questSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Today’s quest: cook one fasting dish'**
  String get questTitle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get questsH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get r1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Edible'**
  String get r2;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get r3;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Proud of it'**
  String get r4;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Grandma would nod'**
  String get r5;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'How did it turn out?'**
  String get rateH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Rate it'**
  String get rateIt;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Only you and your friends see this.'**
  String get rateSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Gurage cooking is built on the enset plant — false banana — scraped, buried, and fermented for months before it becomes kocho. Nothing here is fast. Kitfo is the exception that proves it: raw, warm with mitmita, eaten the day the cow is slaughtered.'**
  String get regionBody;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'REGION 04 OF 09'**
  String get regionEyebrow;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Gurage'**
  String get regionTitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFromPlan;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'24 dishes'**
  String get results;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Resume cooking'**
  String get resumeCooking;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get savedEmpty;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get savedH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'12 saved · 3 collections'**
  String get savedSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Search dishes, regions, spices'**
  String get searchPh;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Serves 6'**
  String get serves;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get setAbout;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get setAccount;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get setApp;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cooks and elders'**
  String get setCredits;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setDarkL;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Default heat'**
  String get setHeat;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'KITCHEN'**
  String get setKitchen;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLang;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setLightL;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Timers & reminders'**
  String get setNotif;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Downloaded recipes'**
  String get setOffline;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'18 dishes'**
  String get setOfflineV;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Who sees my cooking'**
  String get setPrivacy;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get setPrivacyV;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Liya Bekele'**
  String get setProfile;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Level 12 · Addis Ababa'**
  String get setProfileSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get setTheme;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get setUnits;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get setUnitsV;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Version 2.4'**
  String get setVersion;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shopH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'For Doro Wat and two more'**
  String get shopSub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Nothing on the list'**
  String get shoppingEmpty;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Add a recipe\'s ingredients from any dish, or type something in.'**
  String get shoppingEmptySub;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Your streak is where you left it.'**
  String get signInSubtitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'So your cooking follows you to any phone.'**
  String get signUpSubtitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Make it yours'**
  String get signUpTitle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'How well do you know the kitchen?'**
  String get skillH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'We’ll set the pace of your first ten dishes.'**
  String get skillSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Dishes cooked'**
  String get stDishes;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Regions tasted'**
  String get stRegions;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get stStreak;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Start cooking'**
  String get startCooking;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get stepOf;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Doro wat is what you make when someone is worth a whole day. Four onions, cooked dry until they give up their water — that is the whole secret, and it cannot be hurried. In much of Ethiopia it is the dish that ends a fast, carried to the table whole, the eggs scored so the sauce gets inside.'**
  String get storyBody;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'12 days on the fire'**
  String get streakH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Best run: 21 days, last Lent.'**
  String get streakSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Save and finish'**
  String get submit;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabComm;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get tabCook;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tabYou;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Cook your way through Ethiopia.'**
  String get tagline;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'How much heat can you take?'**
  String get tasteH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Berbere is a spectrum, not a switch.'**
  String get tasteSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Taught by Emahoy Tsehay, 74, Gondar'**
  String get taughtBy;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK’S REGION'**
  String get thisWeek;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeekH;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get tier;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'TOTAL TIME'**
  String get timeLbl;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'ONIONS, DRY-COOKING'**
  String get timerLabel;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'No oil until the onions give up'**
  String get tipDry;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'520 XP to Level 13'**
  String get toNext;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'NEW BADGE'**
  String get unlocked;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Create my account'**
  String get upgradeCta;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'You\'re cooking as a guest. Add an account and your XP, streak and saved recipes come with you.'**
  String get upgradeSubtitle;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Save your progress'**
  String get upgradeTitle;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Send to the kitchen'**
  String get uploadCta;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Add your family’s recipe'**
  String get uploadH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Reviewed by two cooks from that region before it goes live.'**
  String get uploadNote;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Someone taught you. Write it down before it goes.'**
  String get uploadSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Liya'**
  String get userName;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'Tell us what to call you.'**
  String get validationNameRequired;

  /// Application copy
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get validationPasswordShort;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'WARMING THE PAN'**
  String get warming;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Every dish is a place you’ve been.'**
  String get welcomeH1;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'Learn the wat, the ferment, the ceremony — one flame at a time, from the people who cook it at home.'**
  String get welcomeSub;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'2,480 / 3,000 XP'**
  String get xpOf;

  /// Design prototype copy
  ///
  /// In en, this message translates to:
  /// **'YIELD'**
  String get yieldLbl;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am': return AppLocalizationsAm();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
