import { readFileSync } from 'node:fs';

const preview = readFileSync(new URL('../outputs/ui-screenshots/climate-note-preview.html', import.meta.url), 'utf8');
const screenshotFixture = readFileSync(new URL('../apps/ios/ClimateNote/Views/ScreenshotRootView.swift', import.meta.url), 'utf8');

const requiredTabs = ['Home', 'Explore', 'Write', 'Saved'];
const requiredStates = [
  'welcome', 'home', 'feed', 'explore', 'write', 'reader', 'story', 'story-visual', 'story-no-generation',
  'summary', 'actions', 'action-selected', 'reflection', 'reflection-keyboard', 'save-queued', 'save-error',
  'save-synced', 'progress', 'progress-completed', 'journal-empty', 'journal-guest', 'signin',
  'signin-unavailable', 'account', 'privacy', 'feed-loading', 'feed-refreshing', 'feed-stale', 'feed-empty',
  'feed-error', 'feed-image-loading', 'feed-image-error', 'impact-loading', 'impact-threshold',
  'impact-populated', 'impact-stale', 'impact-error',
];
const expectedTitles = [
  'Benjamin Jance IV: Cities, the savior of energy? (Chaeho)',
  'The Colorful Reefs in Finding Nemo We Grew Up With Are a Lie',
  'Disappearance of Bees',
  'Biotic Homogenization',
  'Mangrove and Coastal Habitat Degradation (Amrii)',
  'Soil Salinization (Seoha)',
  'Seeking Shade, Killing the Coral Reef: Sunscreen Chemicals and the Crisis of Coral Bleaching (Sooah)',
  'The Rise of “Microtrends”: Clothing Waste Edition (YESEO)',
  'Addressing the Overflow of Food Delivery Packaging (Chaeho Song)',
  'Pharmaceutical pollution',
  'Lignin-based materials in tires and coatings',
];

for (const label of requiredTabs) {
  if (!preview.includes(`>${label}</span>`)) throw new Error(`Missing shared tab label: ${label}`);
}
if (!preview.includes('grid-template-columns:repeat(4,minmax(0,1fr))')) {
  throw new Error('Shared tab component does not lock a four-column layout.');
}
if (!preview.includes("const icon={home:'<svg") || !preview.includes("saved:'<svg")) {
  throw new Error('Shared tab component must use consistent inline SVG icons.');
}
for (const route of ['home', 'explore', 'write', 'saved']) {
  if (!preview.includes(`const ${route}=`)) throw new Error(`Missing tabbed preview route: ${route}`);
}
if (!preview.includes("const page=(content,selected='home')") || !preview.includes('${tab(selected)}')) {
  throw new Error('Tabbed preview routes must share one four-tab component.');
}

for (const state of requiredStates) {
  if (!preview.includes(`'${state}'`)) throw new Error(`Preview fixture state is missing: ${state}`);
  if (!screenshotFixture.includes(`"${state}"`)) throw new Error(`Native fixture state is missing: ${state}`);
}
if (!screenshotFixture.includes('static var isIsolated')) {
  throw new Error('Native fixtures must retain ScreenshotConfiguration.isIsolated.');
}
if (screenshotFixture.includes('Calendar.current') || screenshotFixture.includes('Date()')) {
  throw new Error('Native fixture captures must not depend on the current date or calendar.');
}
if (!screenshotFixture.includes('fixtureCalendar') || !screenshotFixture.includes('referenceDate')) {
  throw new Error('Native fixture calendar and reference date must remain deterministic.');
}

for (const title of expectedTitles) {
  if (!preview.includes(`title:'${title}'`)) throw new Error(`Missing verified preview article: ${title}`);
  if (!screenshotFixture.includes(`"${title}"`)) throw new Error(`Missing verified native article: ${title}`);
}
if ((preview.match(/\{title:'/g) ?? []).length !== 11) {
  throw new Error('Preview must initialize exactly 11 verified articles.');
}
if ((screenshotFixture.match(/preview\(/g) ?? []).length !== 11 || !screenshotFixture.includes('static let article = Article(')) {
  throw new Error('Native fixture must initialize the canonical story plus ten additional verified articles.');
}
for (const imageClass of ['art-city', 'art-coral', 'art-bee', 'art-community', 'art-mangrove', 'art-drought', 'art-coral2', 'art-textile', 'art-packaging', 'art-lab', 'art-tire']) {
  if (!preview.includes(`.${imageClass}{background-image:url(`)) throw new Error(`Missing distinct Pixabay image fixture: ${imageClass}`);
}

if (preview.includes('>Publish<') || screenshotFixture.includes('"Publish"')) {
  throw new Error('Preview fixtures must not present draft review as publishing.');
}
for (const requirement of [
  'PRIVATE NOTEBOOK',
  'Write what<br>stayed with you.',
  'Begin with a published story, then capture your own response. Notes are private by default.',
  'Only you can see your note',
  'Choose a story',
  'Write a private note for ${a.title}',
]) {
  if (!preview.includes(requirement)) throw new Error(`Preview is missing private-note writing flow copy: ${requirement}`);
}
for (const requirement of [
  'class="explore-head"',
  'Search by title, topic, or idea',
  "EDITOR'S PICK",
  'Browse the archive',
  'class="explore-feature',
]) {
  if (!preview.includes(requirement)) throw new Error(`Preview is missing the premium Explore hierarchy: ${requirement}`);
}
for (const requirement of ['climateDiscoveryDisplay', 'climateEditorialDisplay', 'ScreenshotExploreFeatureCard', 'ScreenshotWriteNotebookHero', 'ScreenshotComposeStoryCard']) {
  if (!screenshotFixture.includes(requirement)) throw new Error(`Native fixtures are missing differentiated Explore/Write UI: ${requirement}`);
}
if (!preview.includes('.discovery{') || !preview.includes('.editorial{') || !preview.includes('.story-shelf{')) {
  throw new Error('Preview is missing the distinct discovery and notebook type/layout systems.');
}
for (const staleWritingCopy of ['START A DRAFT', 'ARTICLE TITLE', 'Review draft', 'This editor does not publish articles.']) {
  if (preview.includes(staleWritingCopy)) throw new Error(`Preview still contains a stale publishing-style writing control: ${staleWritingCopy}`);
}

for (const requirement of [
  'I confirm I am 13 or older.',
  'Confirm your age to continue.',
  'Continue as guest',
  'Reading never requires an account. Continue as a guest to save privately, or use Apple or Google.',
  'By creating a guest account or continuing with Apple or Google, you agree to the Terms of Service and Privacy Policy.',
]) {
  if (!preview.includes(requirement) || !screenshotFixture.includes(requirement)) {
    throw new Error(`Preview and native fixture must retain the age-confirmed guest sign-in path: ${requirement}`);
  }
}

for (const requirement of [
  'The story in three parts',
  'AI summary. Read the article and sources for context.',
]) {
  if (!preview.includes(requirement) || !screenshotFixture.includes(requirement)) {
    throw new Error(`Preview and native fixture must retain current editorial/AI summary context: ${requirement}`);
  }
}

for (const requirement of [
  'Export synced account data',
  'Sign out',
  'Include my completed supported actions in anonymous community totals',
  'This is optional. You can withdraw at any time; private notes and identity are never included.',
  'Delete account',
]) {
  if (!preview.includes(requirement)) throw new Error(`Preview is missing account data or impact boundary: ${requirement}`);
}
for (const requirement of ['height:232px', 'grid-template-columns:92px', 'min-height:220px', 'font:19px/1.62', 'min-height:44px']) {
  if (!preview.includes(requirement)) throw new Error(`Preview is missing required editorial sizing: ${requirement}`);
}
if (!preview.includes('apple-signin') || !preview.includes('padding-inline:24px')) {
  throw new Error('Preview is missing compact-safe Apple sign-in button padding.');
}
if (preview.includes('⌘ K') || screenshotFixture.includes('⌘ K')) {
  throw new Error('Preview fixtures must not present a desktop keyboard shortcut in phone search.');
}

console.log(`Screenshot fixture validation passed (${requiredStates.length} deterministic states, 11 verified articles).`);
