namespace CrestCore.Contracts;

/// What the person chose for one Space an import brings, and what those
/// choices mean: whether it comes in, the existing Space it joins or none for
/// a new Space, the name and look it takes, the tabs it brings and the
/// placements they move to, its saved passwords, the sites it would stay
/// signed in to, which stay out unless the person asks for them, and the
/// extensions it offers with those left on. `DuplicateTabIds` are its tabs the destination
/// already holds, which it leaves out until the person asks for them;
/// `MatchedTabIds` are the destination's tabs it matches.
public sealed record SetupReviewSpace(SpaceState Source, bool Included, Guid? DestinationId, SpaceCustomization Customization,
    IReadOnlyList<Guid> IncludedTabIds, IReadOnlyList<Guid> DuplicateTabIds, IReadOnlyList<Guid> MatchedTabIds,
    IReadOnlyList<TabPlacementChoice> Placements, bool IncludesPasswords, int PasswordCount, IReadOnlyList<ImportExtension> Extensions,
    IReadOnlyList<string> IncludedExtensionIds, bool IncludesSignIns = false, int SignInSiteCount = 0,
    string? SourceProfileId = null) {
    #region Variables

    /// The name the Space shows and takes once imported: the one chosen,
    /// trimmed, or "Untitled Space" for a blank one.
    [Resolved]
    public string ShownName => SpaceCustomization.Resolved(Customization.Name);

    /// Whether the passwords that belong with the Space come in with it.
    [Resolved]
    public bool BringsPasswords => Included && IncludesPasswords;

    /// Whether the Space comes in signed in to the sites the other browser
    /// was signed in to that belong with it.
    [Resolved]
    public bool BringsSignIns => Included && IncludesSignIns && SignInSiteCount > 0;

    /// The extensions that install in the Space's destination once it is
    /// imported: those the person left on, in the order the Space offers them,
    /// when the Space comes in.
    [Resolved]
    public IReadOnlyList<ImportExtension> BroughtExtensions => Included
        ? [.. Extensions.Where(extension => IncludedExtensionIds.Contains(extension.ExtensionId))] : [];

    /// Whether the Space comes in as a new Space, taking room in the
    /// workspace, rather than joining one it holds.
    internal bool MakesNewSpace => Included && DestinationId is null;

    #endregion

    #region Actions - Review

    /// The review of `space` as a review starts it: joining `match`, taking
    /// its name and look and leaving out the tabs it holds, or coming in new
    /// with its own. It comes in when `included`, with the
    /// `passwordCount` saved passwords that belong with it, offering
    /// `offered`, all of them left on, and the `signInSiteCount` sites it
    /// could stay signed in to, left off.
    internal static SetupReviewSpace Started(SpaceState space, SpaceState? match, bool included, int passwordCount,
        int signInSiteCount, IReadOnlyList<ImportExtension> offered) {
        var duplicates = match is null ? [] : space.TabsAlsoIn(match).ToHashSet();
        return new(space, included, match?.Id, match?.Customization ?? space.Customization.Normalized(),
            included ? [.. space.Tabs.Where(tab => !duplicates.Contains(tab.Id)).Select(tab => tab.Id)] : [], [], [], [],
            IncludesPasswords: true, passwordCount, offered, [.. offered.Select(extension => extension.ExtensionId)],
            IncludesSignIns: false, signInSiteCount);
    }

    /// The Space with what joining `destination` means: its tabs the
    /// destination already holds, and, when it comes in, the destination's
    /// tabs it matches.
    internal SetupReviewSpace Analyzed(SpaceState? destination) => this with {
        DuplicateTabIds = destination is null ? [] : Source.TabsAlsoIn(destination),
        MatchedTabIds = destination is null || !Included ? [] : destination.TabsAlsoIn(Source)
    };

    /// `ids` in the order the Space holds its tabs.
    internal Guid[] Ordered(IEnumerable<Guid> ids) {
        var chosen = ids.ToHashSet();
        return [.. Source.Tabs.Select(tab => tab.Id).Where(chosen.Contains)];
    }

    #endregion
}
