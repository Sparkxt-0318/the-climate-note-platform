import { readFileSync, readdirSync } from 'node:fs';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const readSwiftSources = directory => readdirSync(new URL(`../${directory}/`, import.meta.url), { withFileTypes: true })
  .flatMap(entry => {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) return readSwiftSources(path);
    return entry.isFile() && path.endsWith('.swift') ? [[path, read(path)]] : [];
  });
const files = {
  app: read('apps/ios/ClimateNote/ClimateNoteApp.swift'),
  appDelegate: read('apps/ios/ClimateNote/AppDelegate.swift'),
  root: read('apps/ios/ClimateNote/Views/RootView.swift'),
  detail: read('apps/ios/ClimateNote/Views/ArticleDetailView.swift'),
  notes: read('apps/ios/ClimateNote/Views/MyNoteView.swift'),
  actions: read('apps/ios/ClimateNote/Views/ClimateActionPicker.swift'),
  account: read('apps/ios/ClimateNote/Views/AccountView.swift'),
  signIn: read('apps/ios/ClimateNote/Views/SignInView.swift'),
  impactViews: read('apps/ios/ClimateNote/Views/ImpactViews.swift'),
  articles: read('apps/ios/ClimateNote/Services/ArticleStore.swift'),
  auth: read('apps/ios/ClimateNote/Services/AuthService.swift'),
  notifications: read('apps/ios/ClimateNote/Services/NotificationService.swift'),
  drafts: read('apps/ios/ClimateNote/Services/DraftOperationStore.swift'),
  impacts: read('apps/ios/ClimateNote/Services/ImpactStore.swift'),
  readingSession: read('apps/ios/ClimateNote/Services/ReadingSessionStore.swift'),
  bundledCovers: read('apps/ios/ClimateNote/Services/BundledCoverCatalog.swift'),
  pixabayCovers: read('apps/ios/ClimateNote/Services/PixabayCoverService.swift'),
  screenshotFixtures: read('apps/ios/ClimateNote/Views/ScreenshotRootView.swift'),
  theme: read('apps/ios/ClimateNote/Design/ClimateTheme.swift'),
  config: read('apps/ios/ClimateNote/Support/AppConfig.swift'),
  reflectionStore: read('apps/ios/ClimateNote/Services/ReflectionStore.swift'),
  actionLog: read('apps/ios/ClimateNote/Models/ActionLog.swift'),
  impactModels: read('apps/ios/ClimateNote/Models/ImpactModels.swift'),
  rules: read('firestore.rules'),
  tabTests: read('apps/ios/ClimateNoteTests/ClimateTabTests.swift'),
  draftTests: read('apps/ios/ClimateNoteTests/ActionLogAndDraftTests.swift'),
  coverTests: read('apps/ios/ClimateNoteTests/PixabayCoverSelectorTests.swift'),
  project: read('apps/ios/ClimateNote.xcodeproj/project.pbxproj'),
  mockPreview: read('outputs/ui-screenshots/climate-note-preview.html'),
};
const checks = [
  ['Firestore loads only published articles', files.articles, '.whereField("status", isEqualTo: "published")'],
  ['Firestore articles are ordered by publication date', files.articles, '.order(by: "publishedAt", descending: true)'],
  ['Article refresh remains callable', files.articles, 'func refresh() async throws'],
  ['Article refresh retains useful cached content', files.articles, 'ArticleRefreshPresentationPolicy'],
  ['Article refresh exposes retry', files.articles, 'func retry()'],
  ['Article refresh has a server timeout', files.articles, 'timeoutRefresh(for requestID:'],
  ['App starts auth, article, reflection, impact, and notification services', files.app, 'impactStore.start()'],
  ['App observes reflection ownership changes', files.app, 'reflectionStore.observe(userID: userID)'],
  ['App observes impact preference ownership changes', files.app, 'impactStore.observePreference(userID: userID)'],
  ['App injects reading continuity', files.app, '.environmentObject(ReadingSessionStore.shared)'],
  ['Notification taps route to the exact journal entry', files.appDelegate, 'AppRouter.shared.showJournal(entryID: entryID)'],
  ['Notification routing rejects a different signed-in owner', files.appDelegate, 'reminderUserID != currentUserID'],
  ['Google auth remains available', files.auth, 'signInWithGoogle()'],
  ['Apple auth remains available', files.auth, 'configureAppleSignIn'],
  ['Guest accounts remain available', files.auth, 'signInAsGuest()'],
  ['Guest credentials are linked before fallback sign-in', files.auth, 'user.link(with: credential)'],
  ['Sign out remains available', files.auth, 'func signOut()'],
  ['Account export remains available', files.auth, 'exportAccountData()'],
  ['Account exports use complete file protection', files.auth, '.completeFileProtection'],
  ['Stale account exports are removed', files.auth, 'removeStaleExportFiles()'],
  ['Account deletion remains available', files.auth, 'deleteAccount()'],
  ['Explore search remains discoverable', files.root, 'Search climate articles'],
  ['Root retains four-tab routing', files.root, 'TabView(selection: $router.selectedTab)'],
  ['Root supports article deep links', files.root, 'showArticle(slug:'],
  ['Root supports journal deep links', files.root, 'showJournal(entryID:'],
  ['Root forwards an exact requested journal entry', files.root, 'requestedEntryID: router.requestedJournalEntryID'],
  ['Root supports iPad split reading', files.root, 'NavigationSplitView'],
  ['Write routes into a real private-note composer', files.root, 'openingComposer: true'],
  ['Private action saving is protected while pending', files.actions, 'guard !isSaving else { return }'],
  ['Composer supports reflection, action, and suggestion modes', files.actions, 'Picker("Note type", selection: $mode)'],
  ['Composer accepts a reflection prefill', files.actions, 'initialCustomText: String = ""'],
  ['Composer accepts an initial writing focus', files.actions, 'initialWritingFocus: Bool = false'],
  ['Composer links synced work to My Note', files.actions, 'onViewInMyNote:'],
  ['Composer shows queued state', files.actions, 'case .queued:'],
  ['Composer shows failed state and retry', files.actions, 'Retry save'],
  ['Composer resumes an explicit guest submission once', files.actions, 'guestResumeGuard.consumeIfReady'],
  ['Protected drafts isolate owner namespaces', files.drafts, 'enum Owner: Hashable'],
  ['Draft revisions are persisted', files.drafts, 'revision: revision'],
  ['Draft operations bind immutable operation IDs', files.drafts, 'bindCurrentDraft'],
  ['Only failed local operations can be removed', files.reflectionStore, 'discardFailedOperation'],
  ['Complete-action control remains available', files.notes, 'Mark complete'],
  ['Completed actions can be reopened', files.notes, 'Mark incomplete'],
  ['Action reminder control remains available', files.notes, 'Remind me'],
  ['Reminder dates are editable', files.notes, 'DatePicker("Remind me"'],
  ['Reminders can be removed', files.notes, 'Remove reminder'],
  ['Journal separates unknown legacy notes', files.notes, 'Saved notes'],
  ['Journal deep-link focus is accessible', files.notes, '@AccessibilityFocusState'],
  ['Editable reflections remain available from saved entries', files.notes, 'onWriteReflection'],
  ['Reflection changes persist privately', files.reflectionStore, 'func saveReflection'],
  ['Reflection operations are revisioned and observable', files.reflectionStore, '@Published private(set) var operationStates'],
  ['Failed reflection operations reuse the immutable save intent', files.reflectionStore, 'if let existing = ledger.operation(id: intentID)'],
  ['Completed actions can be reopened in storage', files.reflectionStore, 'func reopen(_ log: ActionLog)'],
  ['Legacy reflection fields remain optional', files.actionLog, 'let reflectionText: String?'],
  ['Legacy missing kinds decode as actions', files.actionLog, '?? .action'],
  ['Unknown future kinds remain readable', files.actionLog, 'case unknown(String)'],
  ['Action documents preserve factor metadata', files.actionLog, 'factorVersion'],
  ['Canonical article sharing remains available', files.detail, 'AppConfig.articleURL(slug: article.slug)'],
  ['Reader uses local art when canonical cover is absent', files.detail, 'ClimateLocalArt.assetName(for: article)'],
  ['Reader restores reading position', files.detail, 'readingSession.scrollOffset(for: article.id)'],
  ['Reader exposes reading progress', files.detail, 'ReadingProgressBar'],
  ['Reader can start a reflection from selected text', files.detail, 'Start a reflection'],
  ['Canonical share paths remain scoped to articles', files.config, 'apiBaseURL.appending(path: "/articles/\\(slug)")'],
  ['Weekly notification preference remains available', files.notifications, 'setWeeklyEnabled'],
  ['Action reminder dates persist', files.notifications, 'struct ActionReminder'],
  ['Reminder cancellation remains available', files.notifications, 'cancelActionReminder'],
  ['Sign-out clears reminder privacy state', files.notifications, 'clearSessionPrivacyState'],
  ['Reading session remembers the last article', files.readingSession, 'lastOpenedArticleID'],
  ['Reading session remembers topic filters', files.readingSession, 'selectedTopic'],
  ['Reading session remembers article offsets', files.readingSession, 'scrollOffset(for articleID:'],
  ['Reading session controls the first-launch tip', files.readingSession, 'showFirstLaunchTip'],
  ['Bundled cover assets retain provenance', files.bundledCovers, 'provider: "bundled"'],
  ['Pixabay ranking remains deterministic', files.pixabayCovers, 'enum PixabayCoverSelector'],
  ['Pixabay covers retain provider provenance', files.pixabayCovers, 'provider: "pixabay"'],
  ['Impact privacy preference remains opt-in', files.impacts, 'includeInCommunityImpact'],
  ['Impact presentation includes privacy threshold', files.impactModels, 'case threshold(CommunityImpactDocument)'],
  ['Impact presentation includes stale state', files.impactModels, 'case populated(CommunityImpactDocument, isStale: Bool)'],
  ['Personal impact summary remains visible', files.impactViews, 'PersonalImpactSummaryView'],
  ['Community impact exposes loading and retry states', files.impactViews, 'CommunityImpactScreenContent'],
  ['Account privacy/export/delete controls remain available', files.account, 'Export synced account data'],
  ['Account header derives from a truthful signed-in email', files.account, 'profileHeader(for: user.email)'],
  ['Private relay account fallback remains explicit', files.account, 'Apple private relay'],
  ['Account can open community impact', files.account, 'CommunityImpactLink'],
  ['Sign-in explains private ownership', files.signIn, 'private'],
  ['Reader preserves block rendering', files.detail, 'article.contentBlocks[index]'],
];
for (const [name, source, needle] of checks) {
  if (!source.includes(needle)) throw new Error(`Parity check failed: ${name}`);
}
if (files.account.includes('Text("climate_mindset")')) {
  throw new Error('Parity check failed: Account header contains a fabricated handle.');
}
if (files.tabTests.includes('ScreenshotFixtures.') && !files.screenshotFixtures.includes('enum ScreenshotFixtures')) {
  throw new Error('Parity check failed: ScreenshotFixtures test reference has no fixture declaration.');
}
if (files.tabTests.includes('ScreenshotFixtures.') && files.screenshotFixtures.includes('private enum ScreenshotFixtures')) {
  throw new Error('Parity check failed: Tests cannot access a private ScreenshotFixtures declaration.');
}
for (const testFile of ['ClimateTabTests.swift', 'ActionLogAndDraftTests.swift', 'PixabayCoverSelectorTests.swift']) {
  if (!files.project.includes(`${testFile} in Sources`)) {
    throw new Error(`Parity check failed: ${testFile} is not in an Xcode Sources build phase.`);
  }
}
for (const serviceFile of ['DraftOperationStore.swift', 'ImpactStore.swift', 'ReadingSessionStore.swift', 'BundledCoverCatalog.swift', 'PixabayCoverService.swift']) {
  if (!files.project.includes(`${serviceFile} in Sources`)) {
    throw new Error(`Parity check failed: ${serviceFile} is not in the app Sources build phase.`);
  }
}
if (!files.project.includes('ImpactViews.swift in Sources')) {
  throw new Error('Parity check failed: ImpactViews.swift is not in the app Sources build phase.');
}
for (const testNeedle of [
  'testLegacyAndUnknownKindsRemainReadable',
  'testLedgerFreezesPayloadAndCompletedEntryCannotReturnToQueue',
  'testProtectedDraftsSeparateGuestFromAccount',
  'testImpactPresentationProtectsThresholdAndLegacyImpactStillDecodes',
  'testOnlyFailedOperationsMayBeRemovedFromLocalRetryLedger',
  'testPendingOperationSurvivesStoreRecreationWithFrozenIdentifier',
  'testNewDraftRevisionDoesNotReattachOrDeleteOlderPendingOperation',
  'testOnlyInitialDurableWriteMayRemainQueuedWhenOffline',
  'testGuestSubmitResumesOnceOnlyAfterBothUserSourcesAgree',
  'testPersonalWritingAndOwnerTransitionsFollowPickerPolicy',
  'testPersonalImpactCountsOnlyCompletedActionsWithSupportedCarbonEstimates',
  'testCommunityPresentationMarksStaleVisibleAggregate',
  'testLicensedCoverDecodesServerProvenanceWithoutDroppingMedia',
  'testRefreshPresentationRetainsUsefulContentUntilServerResolution',
]) {
  if (!files.draftTests.includes(testNeedle)) {
    throw new Error(`Parity check failed: missing durability test ${testNeedle}.`);
  }
}
for (const testNeedle of ['testSearchQueryUsesVisualPlanThenTopicAndTitleFallback', 'testRankingPrefersLandscapeEngagementAndMapsProvenance']) {
  if (!files.coverTests.includes(testNeedle)) {
    throw new Error(`Parity check failed: missing cover test ${testNeedle}.`);
  }
}
const productionSwiftSources = readSwiftSources('apps/ios/ClimateNote');
const productionSwift = productionSwiftSources.map(([, source]) => source).join('\n');
const productionViews = productionSwiftSources
  .filter(([path]) => path.includes('/Views/'))
  .map(([, source]) => source)
  .join('\n');
const tabItemCount = (files.root.match(/\.tabItem\s*\{/g) ?? []).length;
const screenshotTabItemCount = (files.screenshotFixtures.match(/\.tabItem\s*\{/g) ?? []).length;
const tabTags = ['home', 'explore', 'write', 'saved']
  .filter(tab => files.root.includes(`.tag(ClimateTab.${tab}.rawValue)`));
const universalTargetCount = (files.project.match(/TARGETED_DEVICE_FAMILY = "1,2";/g) ?? []).length;
const premiumChecks = [
  ['Native and deterministic mock UI sources do not reference Georgia', !/\bGeorgia\b/.test(`${productionSwift}\n${files.mockPreview}`)],
  ['Production views do not use caption2', !/\.caption2\b/.test(productionViews)],
  ['Theme metadata maps to SwiftUI caption', /static var climateMetadata: Font \{\s*Font\(ClimateTypography\.scaledFont\(size: 14, relativeTo: \.caption,/.test(files.theme)],
  ['Theme honors Reduce Motion for press and image transitions',
    files.theme.includes('@Environment(\\.accessibilityReduceMotion)') &&
    files.theme.includes('.animation(reduceMotion ? nil : ClimateMotion.press') &&
    files.theme.includes('Transaction(animation: reduceMotion ? nil : ClimateMotion.content)') &&
    files.mockPreview.includes('@media (prefers-reduced-motion:reduce)')],
  ['Shared text buttons meet the 44pt minimum target',
    files.theme.includes('static let minimumTarget: CGFloat = 44') &&
    files.theme.includes('.frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget)')],
  ['Native root and screenshot fixture contain the four required labeled tabs',
    tabItemCount === 4 && screenshotTabItemCount === 4 && tabTags.length === 4],
  ['Both app configurations target iPhone and iPad', universalTargetCount === 2 && !files.project.includes('TARGETED_DEVICE_FAMILY = 1;')],
  ['Reader copy stays concise and avoids the old AI disclaimer', !files.detail.includes('AI summary. Original article unchanged.')],
  ['Write is truthful and never claims article publishing', !files.root.includes('Button("Publish"') && !files.root.includes('publishes articles')],
  ['Explore and Write use distinct native type voices',
    files.theme.includes('func climateDiscoveryDisplay(') &&
    files.theme.includes('func climateEditorialDisplay(') &&
    files.root.includes('.climateDiscoveryDisplay(42') &&
    files.root.includes('.climateEditorialDisplay(37')],
  ['Explore uses a discovery feature while Write uses a private notebook shelf',
    files.root.includes('ExploreFeatureCard') &&
    files.root.includes('WriteNotebookHero') &&
    files.root.includes('ComposeStoryCard') &&
    files.root.includes('Search by title, topic, or idea') &&
    files.root.includes('Only you can see your note')],
];
for (const [name, passes] of premiumChecks) {
  if (!passes) throw new Error(`Premium UI invariant failed: ${name}`);
}
const mappedCanonicalAssets = [...files.theme.matchAll(/case "[^"]+": "(Pixabay[^"]+)"/g)].map(match => match[1]);
if (mappedCanonicalAssets.length !== 11 || new Set(mappedCanonicalAssets).size !== 11) {
  throw new Error('Parity check failed: the 11 verified articles do not have 11 distinct local covers.');
}
const verifiedFixtureIds = [...files.screenshotFixtures.matchAll(/(?:preview\(|documentID:)\s*"(drive-[^"]+)"/g)].map(match => match[1]);
if (verifiedFixtureIds.length !== 11 || new Set(verifiedFixtureIds).size !== 11) {
  throw new Error('Parity check failed: deterministic fixtures do not contain the 11 unique verified Drive articles.');
}
if (!files.rules.includes('affectedKeys().hasOnly([') || !files.rules.includes('"reflectionText", "reflectionUpdatedAt"')) {
  throw new Error('Parity check failed: reflection updates are not field-limited by Firestore rules.');
}
if (!files.rules.includes('allow read: if owns(userId)') || !files.rules.includes('request.resource.data.userID == userId')) {
  throw new Error('Parity check failed: private action logs are not owner-bound.');
}
if (!files.rules.includes('request.resource.data.reflectionText.size() <= 2000')) {
  throw new Error('Parity check failed: Firestore does not enforce the reflection length limit.');
}
if (!files.rules.includes('request.resource.data.articleID == resource.data.articleID') || !files.rules.includes('request.resource.data.actionID == resource.data.actionID')) {
  throw new Error('Parity check failed: Firestore does not preserve action-log identity fields.');
}
if (!files.rules.includes('allow create: if owns(userId)') || !files.rules.includes('request.resource.data.status == "planned"')) {
  throw new Error('Parity check failed: clients can create non-planned action logs.');
}
if (!files.rules.includes('resource.data.status == "planned"') || !files.rules.includes('request.resource.data.status == "completed"')) {
  throw new Error('Parity check failed: Firestore rules do not allow planned → completed.');
}
if (!files.rules.includes('resource.data.status == "completed"') || !files.rules.includes('request.resource.data.status == "planned"')) {
  throw new Error('Parity check failed: Firestore rules do not allow completion undo.');
}
if (!files.rules.includes('resource.data.kind == "action"')) {
  throw new Error('Parity check failed: Firestore completion transitions are not limited to actions.');
}
console.log(`iOS feature parity source validation passed (${checks.length + premiumChecks.length} checks).`);
