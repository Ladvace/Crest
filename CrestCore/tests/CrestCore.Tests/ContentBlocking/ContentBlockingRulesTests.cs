using System.Text.Json.Nodes;

using CrestCore.Contracts;
using CrestCore.Domain;
using CrestCore.Native;

using Xunit;

namespace CrestCore.Tests;

/// Content blocking as WebKit compiles it: a policy's filter lists, or its
/// fallback hosts, as content rules, with the sites a person exempts left
/// alone.
public sealed class ContentBlockingRulesTests {
    private const string List = """
        [Adblock Plus 2.0]
        ! A comment
        ||ads.example^
        ||tracker.example^$third-party,script
        /banner/*$image,domain=news.example|~sports.news.example
        @@||ads.example/allowed^$script
        ##.ad-slot
        ##.sponsored
        news.example##.promo
        shop.example#@#.sponsored
        example.org#@#.ad-slot
        ##+js(set-constant, ads, false)
        news.example#?#.story:has-text(Sponsored)
        /^https?:\/\/regex\.example/
        ||unsupported.example^$redirect=noop.js
        """;

    [Fact]
    public void FallbackHostsBlockThirdPartyLoadsThroughTheAppBoundary() {
        using var app = new AppClient();
        var lists = app.Ask(new ContentBlockingRules(ContentBlockingPolicy.Balanced, [], []), ContractCodec.ReadContentRuleLists).Lists;
        var rules = JsonNode.Parse(Assert.Single(lists).Source)!.AsArray();
        Assert.StartsWith("com.pauldavis.crest.content-blocking.balanced.v2.", lists[0].Identifier);
        Assert.Equal(ContentBlockingPolicy.Balanced.BlockedHostSuffixes.Count, rules.Count);
        var trigger = rules[0]!["trigger"]!;
        Assert.Equal(@"^[^:]+://+([^:/]+\.)?doubleclick\.net[:/]", trigger["url-filter"]!.GetValue<string>());
        Assert.Equal(["third-party"], trigger["load-type"]!.AsArray().Select(value => value!.GetValue<string>()));
        Assert.DoesNotContain("document", trigger["resource-type"]!.AsArray().Select(value => value!.GetValue<string>()));
        Assert.Empty(app.Ask(new ContentBlockingRules(ContentBlockingPolicy.Off, [List], []), ContractCodec.ReadContentRuleLists).Lists);
    }

    [Fact]
    public void ListsTranslateWhatWebKitCanMatchAndLeaveOutTheRest() {
        var rules = Rules(WebKitFilterTranslation.Sources([List], []));
        var blocks = rules.Where(rule => Action(rule) == "block").ToList();
        Assert.Equal(3, blocks.Count);
        Assert.Equal(@"^[^:]+://+([^:/]+\.)?ads\.example[:/]", Filter(blocks[0]));
        Assert.Null(blocks[0]["trigger"]!["load-type"]);
        Assert.Null(blocks[0]["trigger"]!["resource-type"]);
        Assert.DoesNotContain("document", Strings(blocks[2]["trigger"]!["resource-type"]));
        Assert.Equal(["third-party"], Strings(blocks[1]["trigger"]!["load-type"]));
        Assert.Equal(["script"], Strings(blocks[1]["trigger"]!["resource-type"]));
        Assert.Equal(["*news.example"], Strings(blocks[2]["trigger"]!["if-domain"]));
        Assert.Equal(@"/banner/", Filter(blocks[2]));
        Assert.DoesNotContain(rules, rule => Filter(rule).Contains("regex") || Filter(rule).Contains("unsupported"));
        Assert.DoesNotContain(rules, rule => rule["action"]!["selector"]?.GetValue<string>().Contains("has-text") == true);
    }

    [Fact]
    public void ExceptionsAndSpareSitesWinOverTheRulesBeforeThem() {
        var rules = Rules(WebKitFilterTranslation.Sources([List], []));
        var exception = rules.Single(rule => Action(rule) == "ignore-previous-rules");
        Assert.True(rules.IndexOf(exception) > rules.FindLastIndex(rule => Action(rule) == "block"));
        Assert.Equal(["script"], Strings(exception["trigger"]!["resource-type"]));

        var hiding = rules.Where(rule => Action(rule) == "css-display-none").ToList();
        var adSlot = hiding.Single(rule => Selector(rule) == ".ad-slot");
        Assert.Equal(["*example.org"], Strings(adSlot["trigger"]!["unless-domain"]));
        var sponsored = hiding.Single(rule => Selector(rule) == ".sponsored");
        Assert.Equal(["*shop.example"], Strings(sponsored["trigger"]!["unless-domain"]));
        var promo = hiding.Single(rule => Selector(rule) == ".promo");
        Assert.Equal(["*news.example"], Strings(promo["trigger"]!["if-domain"]));
    }

    [Fact]
    public void EveryListEndsWithItsExceptionsAndTheExemptSitesWithinWebKitsLimit() {
        string lines = string.Join('\n', Enumerable.Range(0, 25).Select(index => $"||host{index}.example^"));
        var sources = WebKitFilterTranslation.Sources([lines, "@@||host3.example^$script"], ["calm.example"], maximumRules: 10);
        Assert.Equal(4, sources.Count);
        foreach (var source in sources) {
            var rules = Rules([source]);
            Assert.True(rules.Count <= 10);
            Assert.Equal("ignore-previous-rules", Action(rules[^2]));
            Assert.Equal(["*calm.example"], Strings(rules[^1]["trigger"]!["if-domain"]));
            Assert.Null(rules[^1]["trigger"]!["resource-type"]);
        }
        Assert.Equal(25, sources.Sum(source => Rules([source]).Count(rule => Action(rule) == "block")));
    }

    [Fact]
    public void AnIdentifierChangesWithTheRulesItNames() {
        var plain = ContentBlockingPolicy.Strict.RuleLists([List], []);
        var exempting = ContentBlockingPolicy.Strict.RuleLists([List], ["news.example"]);
        Assert.All(plain, list => Assert.StartsWith("com.pauldavis.crest.content-blocking.strict.v1.", list.Identifier));
        Assert.NotEqual(plain[0].Identifier, exempting[0].Identifier);
        Assert.Equal(plain[0].Identifier, ContentBlockingPolicy.Strict.RuleLists([List], [])[0].Identifier);
    }

    [Theory]
    [InlineData("||ads.example^", @"^[^:]+://+([^:/]+\.)?ads\.example[:/]")]
    [InlineData("||ads.example/banner^", @"^[^:]+://+([^:/]+\.)?ads\.example/banner([^a-zA-Z0-9_.%-].*)?$")]
    [InlineData("|https://cdn.example/ad.js|", @"^https://cdn\.example/ad\.js$")]
    [InlineData("/ads/*/banner^", @"/ads/.*/banner([^a-zA-Z0-9_.%-].*)?$")]
    [InlineData("*-ad-*", "-ad-")]
    [InlineData("a|b", null)]
    [InlineData("café", null)]
    public void PatternsSpellWebKitUrlFilters(string pattern, string? filter) =>
        Assert.Equal(filter, WebKitFilterTranslation.UrlFilter(pattern));

    private static List<JsonNode> Rules(IEnumerable<string> sources) =>
        [.. sources.SelectMany(source => JsonNode.Parse(source)!.AsArray()).OfType<JsonNode>()];

    private static string Action(JsonNode rule) => rule["action"]!["type"]!.GetValue<string>();
    private static string Filter(JsonNode rule) => rule["trigger"]!["url-filter"]!.GetValue<string>();
    private static string? Selector(JsonNode rule) => rule["action"]!["selector"]?.GetValue<string>();
    private static string[] Strings(JsonNode? node) => [.. node!.AsArray().Select(value => value!.GetValue<string>())];
}
