namespace CrestCore.Contracts;

/// A look a Space can start from: a gradient of the house's colors down the
/// sidebar, with its icon in the house's metal. Choosing one copies its
/// look into the Space, so a Space keeps the look it was given when a house
/// changes.
public sealed class SpaceHouse {
    #region Variables

    /// Slate and steel, its icon in ice.
    public static readonly SpaceHouse Winter = new("winter", "Winter", "CrestWinter", HouseLook(
        [Tincture.WinterSlate, Tincture.WinterSteel, Tincture.WinterIce], SpaceThemeMode.Gradient,
        Tincture.WinterWolf));

    /// Oxblood and crimson, its icon in gold.
    public static readonly SpaceHouse Lion = new("lion", "Lion", "CrestLion", HouseLook(
        [Tincture.LionOxblood, Tincture.LionCrimson, Tincture.LionGold], SpaceThemeMode.Gradient,
        Tincture.LionOr));

    /// Midnight and gunmetal, its icon in gold.
    public static readonly SpaceHouse Storm = new("storm", "Storm", "CrestStorm", HouseLook(
        [Tincture.StormMidnight, Tincture.StormGunmetal, Tincture.StormBrass], SpaceThemeMode.Gradient,
        Tincture.StormOr));

    /// Char and blood, its icon in fire.
    public static readonly SpaceHouse Dragon = new("dragon", "Dragon", "CrestDragon", HouseLook(
        [Tincture.DragonChar, Tincture.DragonBlood, Tincture.DragonScarlet], SpaceThemeMode.Gradient,
        Tincture.DragonFire));

    /// Forest and moss, its icon in rose.
    public static readonly SpaceHouse Meadow = new("meadow", "Meadow", "CrestMeadow", HouseLook(
        [Tincture.MeadowForest, Tincture.MeadowMoss, Tincture.MeadowWheat], SpaceThemeMode.Gradient,
        Tincture.MeadowRose));

    /// Iron black and pewter, its icon in gold.
    public static readonly SpaceHouse Iron = new("iron", "Iron", "CrestIron", HouseLook(
        [Tincture.IronBlack, Tincture.IronPewter, Tincture.IronPatina], SpaceThemeMode.Gradient,
        Tincture.IronOr));

    /// Navy and lapis, its icon in silver.
    public static readonly SpaceHouse River = new("river", "River", "CrestRiver", HouseLook(
        [Tincture.RiverNavy, Tincture.RiverLapis, Tincture.RiverRust], SpaceThemeMode.Gradient,
        Tincture.RiverArgent));

    /// A gradient of umber and terracotta, its icon in gold.
    public static readonly SpaceHouse Sun = new("sun", "Sun", "CrestSun", HouseLook(
        [Tincture.SunUmber, Tincture.SunTerracotta, Tincture.SunDune], SpaceThemeMode.Gradient,
        Tincture.SunOr, gradientAngle: 160));

    /// Onyx and charcoal, its icon in bone.
    public static readonly SpaceHouse Vigil = new("vigil", "Vigil", "CrestVigil", HouseLook(
        [Tincture.VigilOnyx, Tincture.VigilCharcoal, Tincture.VigilAsh], SpaceThemeMode.Gradient,
        Tincture.VigilBone));

    public static IReadOnlyList<SpaceHouse> All { get; } = [Winter, Lion, Storm, Dragon, Meadow, Iron, River, Sun, Vigil];

    public string Name { get; }

    /// The house's name in the template gallery.
    [Localized]
    public string Title { get; }

    /// The look a Space starting from the house wears.
    public SpaceBranding Look { get; }

    /// The app icon in the house's colors, by its asset name.
    public string AppIconName { get; }

    #endregion

    #region Constructors

    private SpaceHouse(string name, string title, string appIconName, SpaceBranding look) {
        Name = name;
        Title = title;
        AppIconName = appIconName;
        Look = look;
    }

    #endregion

    #region Actions - Lookup

    public static SpaceHouse? Named(string? name) => All.FirstOrDefault(house => house.Name == name);

    #endregion

    #region Actions - Looks

    /// A house's look: its sidebar colors in a gradient, which keeps controls
    /// readable, and its icon in `icon`.
    private static SpaceBranding HouseLook(Tincture[] colors, SpaceThemeMode mode, Tincture icon,
        double gradientAngle = SpaceBranding.DownwardGradientAngle) =>
        SpaceBranding.Announced(new(new([.. colors.Select(tincture => tincture.Color)]), SpaceBannerPattern.Solid, BannerStrength: 1,
            ReadabilityFade: 0.45, KeepsControlsReadable: true, mode, gradientAngle, ShowsTexture: false, SpaceIconStyle.SimpleSymbol,
            icon.Color, SpaceBranding.Neutral.Crest, SpaceBranding.BaselineRenderingVersion, FolderColorIntensity: 0,
            SpaceTextColorMode.Automatic, HasCustomAppearance: false));

    #endregion
}
