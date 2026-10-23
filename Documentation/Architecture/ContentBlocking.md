# Content blocking

Each Space blocks ads and trackers with one of three policies: Standard
(EasyList and EasyPrivacy), Strict (those lists plus uBlock Origin's own
lists and EasyList Cookie) or Off. Sites a person exempts are left alone in
every Space.

## Filter lists

Crest ships no filter list. `FilterList` in `CrestCore` names each list, its
address and its license, and each policy names the lists it blocks with.
`FilterListLibrary` downloads them from their maintainers into Application
Support, checks for a newer version once a day with the server's ETag, and
keeps only what reads as an Adblock Plus list. An isolated launch downloads
nothing.

Until a policy's lists are downloaded, it blocks third-party loads from a short
list of well-known advertising and analytics hosts, the policy's
`BlockedHostSuffixes`, so a first launch is never unprotected.

## WebKit

The portable core owns the translation. The `ContentBlockingRules` query takes
a policy, the text of its downloaded lists and the exempt sites, and answers
WebKit content rule lists (`WebKitFilterTranslation`):

- Network rules (`||host^`, anchored and plain patterns with `*` and `^`, the
  `third-party`, `domain` and resource-type options) become `block` rules, and
  `@@` exceptions become `ignore-previous-rules`. A rule for a whole host also
  blocks the host's own pages, as uBlock's strict blocking does; no other rule
  blocks a page.
- Element hiding (`##selector`, per site or for every site, and `#@#`
  exceptions) becomes `css-display-none`, with a site's exception expressed as
  `unless-domain` on the selector it spares.
- Regular-expression rules, scriptlets, procedural selectors, redirects and
  options that rewrite a request are left out rather than approximated.

WebKit compiles at most 150,000 rules into a list, and an exception cancels
only the rules before it in its own list, so every list ends with all the
exceptions and, last, an `ignore-previous-rules` rule for the exempt sites.
Exempting a site therefore compiles the rules again, which takes seconds; the
page reloads once they are ready.

A list's identifier carries a digest of its rules. `BrowserContentRuleListProvider`
looks up rules compiled before from the same lists and exemptions, compiles
anything new into `WKContentRuleListStore`, and removes compiled rules no
policy uses. If WebKit refuses a list, the policy falls back to its hosts. A
list update applies to each page on its next navigation; changing a Space's
policy or a site's exemption reloads the presented pages it affects.

## Chromium

The Chromium host exposes no per-request hook, and adding one would change the
engine's inputs. Chromium Spaces block with uBlock Origin Lite instead:
`ChromiumExtensionStore.keepContentBlocker` installs it in a Space the first
time the Space blocks, without asking, enables it while the Space blocks and
disables it while it doesn't. A Space it was installed in once is never given
it again, so a person can remove it. The Chromium registration still declares
`content-blocking` unavailable, since Crest's own rules never reach its pages.

## Compatibility

A list can occasionally break a site. The site controls turn blocking off for
that site in every Space; Settings › Privacy lists the exempt sites and turns
blocking back on.
