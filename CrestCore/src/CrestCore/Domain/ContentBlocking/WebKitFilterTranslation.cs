using System.Text;
using System.Text.Json.Nodes;

namespace CrestCore.Domain;

/// Filter lists in Adblock Plus syntax as WebKit content-blocker rules.
///
/// Network rules block a page's subresources: `||host^`, anchored and plain
/// patterns with `*` and `^`, the `third-party`, `domain` and resource-type
/// options, and `@@` exceptions. Element hiding rules hide what a page draws
/// itself: `##selector`, for every site or the sites named before it, and
/// `#@#` exceptions. What WebKit cannot express is left out rather than
/// approximated: regular-expression rules, scriptlets, procedural selectors,
/// redirects and the options that rewrite a request.
///
/// WebKit compiles at most `MaximumRulesPerList` rules into one list, and an
/// exception only cancels the rules before it in its own list, so every list
/// ends with all the exceptions and, last, the sites exempt from blocking. A
/// rule for a whole host blocks the host's own pages too, as uBlock's strict
/// blocking does; no other rule blocks a page.
internal static class WebKitFilterTranslation {
    #region Static Variables

    /// The most rules WebKit compiles into one content rule list.
    internal const int MaximumRulesPerList = 150_000;

    /// How many selectors one hiding rule joins. An invalid selector voids
    /// only the rule it is in, so rules stay small.
    private const int SelectorsPerRule = 40;

    /// Every subresource a page fetches; the top-level document never is.
    private static readonly string[] NetworkResourceTypes = [
        "child-document", "image", "style-sheet", "script", "font", "raw", "svg-document", "media", "popup", "ping", "fetch",
        "websocket", "csp-report", "other"
    ];

    /// The resource types each Adblock Plus type option names.
    private static readonly Dictionary<string, string[]> ResourceTypes = new(StringComparer.Ordinal) {
        ["script"] = ["script"],
        ["image"] = ["image", "svg-document"],
        ["img"] = ["image", "svg-document"],
        ["stylesheet"] = ["style-sheet"],
        ["css"] = ["style-sheet"],
        ["font"] = ["font"],
        ["media"] = ["media"],
        ["object"] = ["media", "other"],
        ["subdocument"] = ["child-document"],
        ["frame"] = ["child-document"],
        ["xmlhttprequest"] = ["fetch", "raw"],
        ["xhr"] = ["fetch", "raw"],
        ["websocket"] = ["websocket"],
        ["ping"] = ["ping"],
        ["beacon"] = ["ping"],
        ["popup"] = ["popup"],
        ["other"] = ["other"]
    };

    /// Options that change nothing WebKit decides.
    private static readonly HashSet<string> IgnoredOptions = new(StringComparer.Ordinal) { "important", "all", "match-case" };

    /// Selector syntax only an extension's own engine understands.
    private static readonly string[] ProceduralSelectorMarkers = [
        ":-abp-", ":has-text(", ":xpath(", ":upward(", ":remove(", ":style(", ":matches-css", ":min-text-length(", ":watch-attr(",
        ":others(", ":if(", ":if-not(", ":matches-path(", ":remove-attr(", ":remove-class(", ":matches-attr(", ":matches-prop(",
        ":nth-ancestor(", ":spath(", ":matches-media(", ":contains(", "{", "}"
    ];

    #endregion

    #region Actions - Translation

    /// The WebKit content-rule JSON sources `lists` translate to, each at
    /// most `maximumRules` rules long, ending with the rules that leave the
    /// sites `exemptHosts` names, and their subdomains, unblocked.
    internal static IReadOnlyList<string> Sources(IEnumerable<string> lists, IReadOnlyCollection<string> exemptHosts,
        int maximumRules = MaximumRulesPerList) {
        var translation = new Translation();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var list in lists)
            foreach (var raw in list.Split('\n')) {
                var line = raw.Trim();
                if (line.Length > 0 && seen.Add(line)) translation.Add(line);
            }

        List<JsonNode> closing = [.. translation.Exceptions.Take(maximumRules / 2)];
        if (ExemptionRule(exemptHosts) is { } exemption) closing.Add(exemption);
        var room = maximumRules - closing.Count;

        var actions = translation.Blocks.Concat(translation.HidingRules()).ToList();
        if (actions.Count == 0) return closing.Count == 0 ? [] : [Source([], closing)];
        List<string> sources = [];
        for (int start = 0; start < actions.Count; start += room)
            sources.Add(Source(actions.Skip(start).Take(room), closing));
        return sources;
    }

    /// The rule that ignores every rule before it on the sites `hosts` names
    /// and their subdomains, or null when no site is exempt.
    internal static JsonNode? ExemptionRule(IReadOnlyCollection<string> hosts) => hosts.Count == 0 ? null : new JsonObject {
        ["trigger"] = new JsonObject { ["url-filter"] = ".*", ["if-domain"] = Domains(hosts) },
        ["action"] = new JsonObject { ["type"] = "ignore-previous-rules" }
    };

    private static string Source(IEnumerable<JsonNode> actions, IEnumerable<JsonNode> closing) =>
        new JsonArray([.. actions.Concat(closing).Select(rule => rule.DeepClone())]).ToJsonString();

    /// WebKit's spelling of sites and their subdomains.
    private static JsonArray Domains(IEnumerable<string> hosts) => new([.. hosts.Select(host => (JsonNode?)JsonValue.Create("*" + host))]);

    #endregion

    #region Types

    /// The rules of the lines read so far.
    private sealed class Translation {
        internal List<JsonNode> Blocks { get; } = [];
        internal List<JsonNode> Exceptions { get; } = [];

        /// Selectors hidden on every site.
        private readonly List<string> generic = [];
        /// Selectors hidden only on some sites, by the sites they name.
        private readonly Dictionary<string, (List<string> Selectors, string[] Included, string[] Excluded)> specific =
            new(StringComparer.Ordinal);
        /// Selectors no site hides.
        private readonly HashSet<string> sparedEverywhere = new(StringComparer.Ordinal);
        /// The sites where a selector is not hidden.
        private readonly Dictionary<string, HashSet<string>> sparedOn = new(StringComparer.Ordinal);

        internal void Add(string line) {
            if (line[0] == '!' || line[0] == '[' || line.Contains("$$", StringComparison.Ordinal)) return;
            if (HidingMarker(line) is { } marker) AddHiding(line, marker);
            else AddNetwork(line);
        }

        /// Where an element-hiding line splits into its sites and its
        /// selector, and whether it is an exception; null for a line that
        /// hides nothing or hides with syntax WebKit lacks.
        private static (int Index, int Length, bool IsException)? HidingMarker(string line) {
            int index = line.IndexOf('#');
            while (index >= 0 && index < line.Length - 1) {
                var rest = line.AsSpan(index);
                if (rest.StartsWith("##")) return (index, 2, false);
                if (rest.StartsWith("#@#")) return (index, 3, true);
                // Scriptlets, procedural and CSS-injection rules.
                if (rest.StartsWith("#?#") || rest.StartsWith("#$#") || rest.StartsWith("#%#") || rest.StartsWith("#@?#")
                    || rest.StartsWith("#@$#") || rest.StartsWith("#@%#"))
                    return (index, 0, false);
                index = line.IndexOf('#', index + 1);
            }
            return null;
        }

        private void AddHiding(string line, (int Index, int Length, bool IsException) marker) {
            if (marker.Length == 0) return;
            var selector = line[(marker.Index + marker.Length)..].Trim();
            if (!IsPlainSelector(selector)) return;
            var (included, excluded) = SiteList(line[..marker.Index], ',');
            if (included is null) return;
            if (marker.IsException) {
                if (included.Length == 0) sparedEverywhere.Add(selector);
                else if (sparedOn.TryGetValue(selector, out var sites)) sites.UnionWith(included);
                else sparedOn[selector] = [.. included];
                return;
            }
            if (included.Length == 0 && excluded.Length == 0) {
                generic.Add(selector);
                return;
            }
            var key = string.Join(',', included) + "|" + string.Join(',', excluded);
            if (!specific.TryGetValue(key, out var group)) specific[key] = group = ([], included, excluded);
            group.Selectors.Add(selector);
        }

        private void AddNetwork(string line) {
            bool isException = line.StartsWith("@@", StringComparison.Ordinal);
            var rule = isException ? line[2..] : line;
            if (rule.Length > 1 && rule[0] == '/' && rule[^1] == '/') return;
            var pattern = rule;
            var options = "";
            int dollar = rule.LastIndexOf('$');
            if (dollar >= 0 && !rule.AsSpan(dollar).Contains('/')) {
                pattern = rule[..dollar];
                options = rule[(dollar + 1)..];
            }
            if (Options(options, isException) is not { } parsed) return;
            if (parsed.IsSiteException) {
                if (parsed.Included.Length == 0 && HostOnly(pattern) is { } host) Exceptions.Add(SiteException([host]));
                else if (parsed.Included.Length > 0) Exceptions.Add(SiteException(parsed.Included));
                return;
            }
            if (UrlFilter(pattern) is not { } filter) return;
            // A pattern this broad would block far more than its list meant to.
            if (filter is ".*" && parsed.Included.Length == 0 && parsed.Types is null) return;
            var trigger = new JsonObject { ["url-filter"] = filter };
            if (parsed.IsCaseSensitive) trigger["url-filter-is-case-sensitive"] = true;
            // A rule for a whole host blocks it everywhere, its pages too, as
            // uBlock's strict blocking does; any other never blocks a page.
            bool blocksHost = !isException && parsed.Types is null && HostOnly(pattern) is not null && pattern.EndsWith('^');
            if (!blocksHost)
                trigger["resource-type"] = new JsonArray([.. (parsed.Types ?? NetworkResourceTypes).Select(type => (JsonNode?)type)]);
            if (parsed.LoadType is { } loadType) trigger["load-type"] = new JsonArray(loadType);
            if (parsed.Included.Length > 0) trigger["if-domain"] = Domains(parsed.Included);
            else if (parsed.Excluded.Length > 0) trigger["unless-domain"] = Domains(parsed.Excluded);
            var action = new JsonObject { ["type"] = isException ? "ignore-previous-rules" : "block" };
            (isException ? Exceptions : Blocks).Add(new JsonObject { ["trigger"] = trigger, ["action"] = action });
        }

        /// The hiding rules: generic selectors in groups, a selector some
        /// sites spare on its own without them, and each set of sites'
        /// selectors together, less the sites that spare one.
        internal IEnumerable<JsonNode> HidingRules() {
            List<string> plain = [];
            foreach (var selector in generic.Distinct(StringComparer.Ordinal)) {
                if (sparedEverywhere.Contains(selector)) continue;
                if (sparedOn.TryGetValue(selector, out var spared)) yield return Hiding([selector], null, [.. spared]);
                else plain.Add(selector);
            }
            foreach (var batch in plain.Chunk(SelectorsPerRule)) yield return Hiding(batch, null, null);
            foreach (var (selectors, included, excluded) in specific.Values) {
                List<string> together = [];
                foreach (var selector in selectors.Distinct(StringComparer.Ordinal)) {
                    if (sparedEverywhere.Contains(selector)) continue;
                    if (sparedOn.TryGetValue(selector, out var spared) && included.Any(spared.Contains)) {
                        string[] rest = [.. included.Where(site => !spared.Contains(site))];
                        if (rest.Length > 0) yield return Hiding([selector], rest, null);
                    } else {
                        together.Add(selector);
                    }
                }
                foreach (var batch in together.Chunk(SelectorsPerRule)) yield return Hiding(batch, included, excluded);
            }
        }

        private static JsonNode Hiding(IEnumerable<string> selectors, string[]? included, string[]? excluded) {
            var trigger = new JsonObject { ["url-filter"] = ".*" };
            if (included is { Length: > 0 }) trigger["if-domain"] = Domains(included);
            else if (excluded is { Length: > 0 }) trigger["unless-domain"] = Domains(excluded);
            return new JsonObject {
                ["trigger"] = trigger,
                ["action"] = new JsonObject { ["type"] = "css-display-none", ["selector"] = string.Join(", ", selectors) }
            };
        }

        private static JsonNode SiteException(IEnumerable<string> hosts) => new JsonObject {
            ["trigger"] = new JsonObject { ["url-filter"] = ".*", ["if-domain"] = Domains(hosts) },
            ["action"] = new JsonObject { ["type"] = "ignore-previous-rules" }
        };
    }

    /// A network rule's options, or null for a rule with one WebKit can't
    /// honor.
    private sealed record ParsedOptions(string[]? Types, string? LoadType, string[] Included, string[] Excluded, bool IsCaseSensitive,
        bool IsSiteException);

    #endregion

    #region Actions - Parsing

    private static ParsedOptions? Options(string options, bool isException) {
        HashSet<string>? included = null;
        HashSet<string> excluded = [];
        string? loadType = null;
        string[] sitesIncluded = [], sitesExcluded = [];
        bool caseSensitive = false, siteException = false;
        if (options.Length == 0) return new(null, null, [], [], false, false);
        foreach (var raw in options.Split(',', StringSplitOptions.TrimEntries)) {
            bool negated = raw.StartsWith('~');
            var option = negated ? raw[1..] : raw;
            int equals = option.IndexOf('=');
            var name = (equals >= 0 ? option[..equals] : option).ToLowerInvariant();
            var value = equals >= 0 ? option[(equals + 1)..] : null;
            switch (name) {
                case "third-party" or "3p":
                    loadType = negated ? "first-party" : "third-party";
                    break;
                case "first-party" or "1p":
                    loadType = negated ? "third-party" : "first-party";
                    break;
                case "domain" or "from" when value is not null:
                    var (sites, spared) = SiteList(value, '|');
                    if (sites is null) return null;
                    (sitesIncluded, sitesExcluded) = (sites, spared);
                    break;
                case "match-case":
                    caseSensitive = true;
                    break;
                case "document" or "doc" when isException && !negated:
                    siteException = true;
                    break;
                case var type when ResourceTypes.TryGetValue(type, out var types):
                    if (negated) excluded.UnionWith(types);
                    else (included ??= []).UnionWith(types);
                    break;
                case var ignored when IgnoredOptions.Contains(ignored):
                    break;
                default:
                    return null;
            }
        }
        string[]? resourceTypes = included is not null
            ? [.. included.Except(excluded)]
            : excluded.Count > 0 ? [.. NetworkResourceTypes.Except(excluded)] : null;
        if (resourceTypes is { Length: 0 }) return null;
        return new(resourceTypes, loadType, sitesIncluded, sitesExcluded, caseSensitive, siteException);
    }

    /// The sites a list names and the ones it spares with `~`, or a null
    /// list when a site is one WebKit cannot match, such as `example.*`.
    private static (string[]? Included, string[] Excluded) SiteList(string spelled, char separator) {
        List<string> included = [], excluded = [];
        foreach (var raw in spelled.Split(separator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) {
            bool spared = raw.StartsWith('~');
            var site = (spared ? raw[1..] : raw).ToLowerInvariant();
            if (!IsHost(site)) {
                if (!spared) return (null, []);
                continue;
            }
            (spared ? excluded : included).Add(site);
        }
        return ([.. included], [.. excluded]);
    }

    /// The host a `||host^` pattern names alone, or null.
    private static string? HostOnly(string pattern) {
        if (!pattern.StartsWith("||", StringComparison.Ordinal)) return null;
        var host = pattern[2..].TrimEnd('^', '/', '|').ToLowerInvariant();
        return IsHost(host) ? host : null;
    }

    private static bool IsHost(string host) => host.Length is > 0 and <= 253 && host[0] != '.' && host[^1] != '.'
        && host.All(c => c is (>= 'a' and <= 'z') or (>= '0' and <= '9') or '.' or '-');

    private static bool IsPlainSelector(string selector) => selector.Length > 0 && selector[0] != '+' && selector[0] != '^'
        && selector.All(char.IsAscii) && !ProceduralSelectorMarkers.Any(marker => selector.Contains(marker, StringComparison.Ordinal));

    /// The WebKit URL filter an Adblock Plus pattern spells: `||` matches
    /// any scheme and subdomain, `|` anchors an end, `*` matches anything and
    /// `^` a separator or the end. Null for a pattern WebKit can't match.
    internal static string? UrlFilter(string pattern) {
        if (!pattern.All(char.IsAscii)) return null;
        // A whole host, the commonest rule, matches as its own name followed
        // by a port or path, which WebKit matches fastest.
        if (HostOnly(pattern) is { } host && pattern.EndsWith('^'))
            return $"^[^:]+://+([^:/]+\\.)?{host.Replace(".", "\\.", StringComparison.Ordinal)}[:/]";
        var filter = new StringBuilder();
        int start = 0, end = pattern.Length;
        if (pattern.StartsWith("||", StringComparison.Ordinal)) {
            filter.Append("^[^:]+://+([^:/]+\\.)?");
            start = 2;
        } else if (pattern.StartsWith('|')) {
            filter.Append('^');
            start = 1;
        }
        bool anchoredEnd = end > start && pattern[end - 1] == '|';
        if (anchoredEnd) end--;
        while (start < end && pattern[start] == '*' && filter.Length == 0) start++;
        while (end > start && pattern[end - 1] == '*' && !anchoredEnd) end--;
        for (int index = start; index < end; index++) {
            char c = pattern[index];
            switch (c) {
                case '*':
                    filter.Append(".*");
                    break;
                case '^' when index == end - 1:
                    filter.Append(anchoredEnd ? "[^a-zA-Z0-9_.%-]?" : "([^a-zA-Z0-9_.%-].*)?$");
                    if (!anchoredEnd) return filter.ToString();
                    break;
                case '^':
                    filter.Append("[^a-zA-Z0-9_.%-]");
                    break;
                case '|':
                    return null;
                case '\\':
                    return null;
                case '.' or '+' or '?' or '(' or ')' or '[' or ']' or '{' or '}' or '$':
                    filter.Append('\\').Append(c);
                    break;
                default:
                    filter.Append(c);
                    break;
            }
        }
        if (anchoredEnd) filter.Append('$');
        return filter.Length == 0 ? ".*" : filter.ToString();
    }

    #endregion
}
