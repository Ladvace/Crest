using CrestCore.Domain;

namespace CrestCore.Contracts;

/// <summary>
/// The app-wide behavior preferences of one installation: what a window opens with,
/// page translation and its per-language rules, spelling, automatic Picture in
/// Picture, what closing a saved tab does, whether Split View focus follows the
/// pointer, whether local pages open with the developer toolbar, how the
/// command palette ranks and arranges what it offers, and the sites content
/// blocking leaves alone in every Space. Translation rules are in ordinal order
/// of their source language; exempt sites are in ordinal order. They stay on
/// this device and never become sync records.
/// </summary>
public sealed record AppPreferences(StartupBehavior Startup, bool OffersTranslation, bool AutomaticallyTranslates,
    IReadOnlyList<TranslationRule> TranslationRules, bool ChecksSpelling, bool AutomaticallyEntersPictureInPicture,
    SavedTabClosePolicy SavedTabClose, bool SavedTabFaviconReturnsToSavedUrl, bool SplitFocusFollowsMouse,
    bool AutomaticallyShowsDeveloperToolbar, PalettePreferences Palette, IReadOnlyList<string> ContentBlockingExemptions) {
    #region Static Variables

    /// The documented defaults for a person who never chose, which a platform
    /// shows and applies until its session holds the record.
    public static AppPreferences Default { get; } = new(StartupBehavior.ShowStartPage, OffersTranslation: true,
        AutomaticallyTranslates: false, TranslationRules: [], ChecksSpelling: false, AutomaticallyEntersPictureInPicture: true,
        SavedTabClosePolicy.ResumeLastLocation, SavedTabFaviconReturnsToSavedUrl: false, SplitFocusFollowsMouse: false,
        AutomaticallyShowsDeveloperToolbar: true, PalettePreferences.Default, ContentBlockingExemptions: []);

    /// The most sites content blocking leaves alone.
    public const int MaximumContentBlockingExemptions = 1000;

    #endregion

    #region Variables

    /// Collections are owned when constructed or replaced on a copy.
    public IReadOnlyList<TranslationRule> TranslationRules {
        get;
        init => field = [.. value];
    } = [.. TranslationRules];

    /// Collections are owned when constructed or replaced on a copy.
    public IReadOnlyList<string> ContentBlockingExemptions {
        get;
        init => field = [.. value];
    } = [.. ContentBlockingExemptions];

    #endregion

    #region Actions - Translation

    /// Records a source language's translation choice through the rule set's
    /// alias rules.
    internal AppPreferences WithTranslationRule(string source, string target, bool isEnabled) =>
        this with { TranslationRules = AutomaticTranslationRules.Restore(TranslationRules).Set(source, target, isEnabled).Rules };

    #endregion

    #region Actions - Content blocking

    /// Content blocking blocks on `host`, or leaves it and its subdomains
    /// alone, in every Space. Blocking on a host also ends the exemption of
    /// each site it is a subdomain of, which would otherwise keep leaving it
    /// alone. A host is kept as its lowercase name without `www.`; one that is
    /// no host name, or past the limit, changes nothing.
    internal AppPreferences WithContentBlocking(string host, bool blocks) {
        if (ExemptHost(host) is not { } exempt) return this;
        var exemptions = ContentBlockingExemptions.Where(kept =>
            kept != exempt && !(blocks && exempt.EndsWith("." + kept, StringComparison.Ordinal)));
        if (!blocks) exemptions = exemptions.Append(exempt);
        string[] next = [.. exemptions.Order(StringComparer.Ordinal)];
        return next.Length > MaximumContentBlockingExemptions ? this : this with { ContentBlockingExemptions = next };
    }

    /// The name content blocking keeps `host` exempt under, or null when it
    /// names no host.
    internal static string? ExemptHost(string? host) {
        var name = host?.Trim().TrimEnd('.').ToLowerInvariant();
        if (name is null) return null;
        if (name.StartsWith("www.", StringComparison.Ordinal)) name = name[4..];
        return name.Length is > 0 and <= 253 && name[0] != '.'
            && name.All(c => c is (>= 'a' and <= 'z') or (>= '0' and <= '9') or '.' or '-') ? name : null;
    }

    #endregion

    #region Actions - Equality

    public bool Equals(AppPreferences? other) => other is not null
        && Startup == other.Startup
        && OffersTranslation == other.OffersTranslation
        && AutomaticallyTranslates == other.AutomaticallyTranslates
        && TranslationRules.SequenceEqual(other.TranslationRules)
        && ChecksSpelling == other.ChecksSpelling
        && AutomaticallyEntersPictureInPicture == other.AutomaticallyEntersPictureInPicture
        && SavedTabClose == other.SavedTabClose
        && SavedTabFaviconReturnsToSavedUrl == other.SavedTabFaviconReturnsToSavedUrl
        && SplitFocusFollowsMouse == other.SplitFocusFollowsMouse
        && AutomaticallyShowsDeveloperToolbar == other.AutomaticallyShowsDeveloperToolbar
        && Palette.Equals(other.Palette)
        && ContentBlockingExemptions.SequenceEqual(other.ContentBlockingExemptions);

    public override int GetHashCode() => HashCode.Combine(Startup, OffersTranslation, AutomaticallyTranslates,
        TranslationRules.Count, ChecksSpelling, AutomaticallyEntersPictureInPicture, SavedTabClose,
        HashCode.Combine(SavedTabFaviconReturnsToSavedUrl, SplitFocusFollowsMouse, AutomaticallyShowsDeveloperToolbar, Palette,
            ContentBlockingExemptions.Count));

    #endregion
}
