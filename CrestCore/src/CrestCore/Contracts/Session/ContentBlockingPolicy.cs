using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

using CrestCore.Domain;

namespace CrestCore.Contracts;

/// How a Space blocks trackers and ads. Standard blocks with EasyList and
/// EasyPrivacy, Strict adds uBlock's own lists and cookie notices. Until a
/// policy's lists are downloaded, third-party loads from a few well-known
/// advertising and analytics hosts, and their subdomains, are blocked.
///
/// The stored session spells a policy as its `Name`, so a name never changes.
/// A policy travels as its index in `All`, so `All` is append-only.
public sealed class ContentBlockingPolicy {
    #region Variables

    /// Every resource a page fetches over the network; top-level documents are
    /// never blocked.
    private static readonly string[] NetworkResourceTypes = [
        "child-document", "image", "style-sheet", "script", "font", "raw", "svg-document", "media", "popup", "ping", "fetch",
        "websocket", "csp-report", "other"
    ];

    /// The hosts every blocking policy blocks before its lists are downloaded.
    private static readonly string[] FallbackHosts = [
            "doubleclick.net",
            "googleadservices.com",
            "googlesyndication.com",
            "google-analytics.com",
            "googletagmanager.com",
            "ads-twitter.com",
            "analytics.twitter.com",
            "scorecardresearch.com",
            "quantserve.com",
            "hotjar.com",
            "segment.io",
            "segment.com",
            "mixpanel.com",
            "amplitude.com",
            "clarity.ms",
            "nr-data.net",
            "taboola.com",
            "outbrain.com",
            "snap.licdn.com"
        ];

    public static readonly ContentBlockingPolicy Balanced = new(name: "balanced", title: "Standard",
        switchTitle: "Turn Off Content Blocking in This Space", identifier: "com.pauldavis.crest.content-blocking.balanced.v2",
        blockedHostSuffixes: FallbackHosts, filterListNames: [FilterList.EasyList.Name, FilterList.EasyPrivacy.Name]);
    public static readonly ContentBlockingPolicy Off = new(name: "off", title: "Off",
        switchTitle: "Turn On Content Blocking in This Space", identifier: null, blockedHostSuffixes: [], filterListNames: []);
    public static readonly ContentBlockingPolicy Strict = new(name: "strict", title: "Strict",
        switchTitle: "Turn Off Content Blocking in This Space", identifier: "com.pauldavis.crest.content-blocking.strict.v1",
        blockedHostSuffixes: FallbackHosts, filterListNames: [.. FilterList.All.Select(list => list.Name)]);

    public static IReadOnlyList<ContentBlockingPolicy> All { get; } = [Balanced, Off, Strict];

    public string Name { get; }

    /// What the settings call the policy.
    [Localized]
    public string Title { get; }

    /// What a page's actions offer to switch the Space away from this policy.
    [Localized]
    public string SwitchTitle { get; }

    /// The versioned name a rule-list store compiles the policy's rules under,
    /// or null for a policy that blocks nothing. It changes with the rules.
    public string? Identifier { get; }

    /// The hosts whose third-party loads, and their subdomains', are blocked.
    public IReadOnlyList<string> BlockedHostSuffixes { get; }

    /// The names of the filter lists the policy blocks with, in
    /// `FilterList.All`.
    public IReadOnlyList<string> FilterListNames { get; }

    /// The policy blocks anything at all.
    public bool BlocksContent => BlockedHostSuffixes.Count > 0;

    #endregion

    #region Constructors

    private ContentBlockingPolicy(string name, string title, string switchTitle, string? identifier,
        IReadOnlyList<string> blockedHostSuffixes, IReadOnlyList<string> filterListNames) {
        Name = name;
        Title = title;
        SwitchTitle = switchTitle;
        Identifier = identifier;
        BlockedHostSuffixes = blockedHostSuffixes;
        FilterListNames = filterListNames;
    }

    #endregion

    #region Actions - Lookup

    public static ContentBlockingPolicy? Named(string? name) => All.FirstOrDefault(policy => policy.Name == name);

    #endregion

    #region Actions - Rules

    /// The policy's rules as content rule lists, in the WebKit content-rule
    /// format, translated from `lists`, the text of its filter lists, and
    /// leaving the sites `exemptHosts` names unblocked. Without lists, each
    /// fallback host and its subdomains are blocked for third-party network
    /// loads of every resource type but the top-level document. A policy that
    /// blocks nothing has none. A list's identifier names its rules, so it
    /// changes whenever they do.
    internal IReadOnlyList<ContentRuleList> RuleLists(IReadOnlyList<string> lists, IReadOnlyCollection<string> exemptHosts) {
        if (Identifier is not { } identifier) return [];
        IReadOnlyList<string> sources = lists.Count > 0
            ? WebKitFilterTranslation.Sources(lists, exemptHosts)
            : [FallbackSource(exemptHosts)];
        var digest = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join('\n', sources))))[..16];
        return [.. sources.Select((source, index) => new ContentRuleList($"{identifier}.{digest}.{index}", source))];
    }

    private string FallbackSource(IReadOnlyCollection<string> exemptHosts) => new JsonArray([.. BlockedHostSuffixes.Select(host => (JsonNode)new JsonObject {
        ["trigger"] = new JsonObject {
            ["url-filter"] = UrlFilter(host),
            ["url-filter-is-case-sensitive"] = true,
            ["load-type"] = new JsonArray("third-party"),
            ["resource-type"] = new JsonArray([.. NetworkResourceTypes.Select(type => (JsonNode?)JsonValue.Create(type))])
        },
        ["action"] = new JsonObject { ["type"] = "block" }
    }).Append(WebKitFilterTranslation.ExemptionRule(exemptHosts)).OfType<JsonNode>()]).ToJsonString();

    /// The URL filter for one host suffix: any scheme, the host itself or any
    /// subdomain, followed by a port or path.
    private static string UrlFilter(string hostSuffix) =>
        $"^[^:]+://+([^:/]+\\.)?{hostSuffix.Replace(".", "\\.", StringComparison.Ordinal)}[:/]";

    #endregion
}
