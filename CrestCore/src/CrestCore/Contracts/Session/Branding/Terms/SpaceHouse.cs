namespace CrestCore.Contracts;

/// A look a Space can start from: a gradient of its colors down the
/// sidebar, with its icon in a light color of its own. Each keeps the name it
/// had when looks were heraldic houses, which stored looks recorded. Choosing
/// one copies its look into the Space, so a Space keeps the look it was given
/// when a house changes.
public sealed class SpaceHouse {
    #region Variables

    /// Midnight blue deepening to azure, its icon in starlight.
    public static readonly SpaceHouse Winter = new("winter", "Midnight", "CrestWinter", HouseLook(
        [Tincture.MidnightNight, Tincture.MidnightDeep, Tincture.MidnightAzure], SpaceThemeMode.Gradient,
        Tincture.MidnightStar));

    /// Plum through magenta to orange, its icon in apricot.
    public static readonly SpaceHouse Lion = new("lion", "Sunset", "CrestLion", HouseLook(
        [Tincture.SunsetPlum, Tincture.SunsetMagenta, Tincture.SunsetOrange], SpaceThemeMode.Gradient,
        Tincture.SunsetApricot));

    /// Deep sea through teal to green, its icon in mint.
    public static readonly SpaceHouse Storm = new("storm", "Aurora", "CrestStorm", HouseLook(
        [Tincture.AuroraDeep, Tincture.AuroraTeal, Tincture.AuroraGreen], SpaceThemeMode.Gradient,
        Tincture.AuroraMint));

    /// Charcoal through red to flame, its icon in glow.
    public static readonly SpaceHouse Dragon = new("dragon", "Ember", "CrestDragon", HouseLook(
        [Tincture.EmberCoal, Tincture.EmberRed, Tincture.EmberFlame], SpaceThemeMode.Gradient,
        Tincture.EmberGlow));

    /// Pine through green to fern, its icon in spring.
    public static readonly SpaceHouse Meadow = new("meadow", "Forest", "CrestMeadow", HouseLook(
        [Tincture.ForestPine, Tincture.ForestGreen, Tincture.ForestFern], SpaceThemeMode.Gradient,
        Tincture.ForestSpring));

    /// Graphite through slate to steel, its icon in frost.
    public static readonly SpaceHouse Iron = new("iron", "Graphite", "CrestIron", HouseLook(
        [Tincture.GraphiteDark, Tincture.GraphiteSlate, Tincture.GraphiteSteel], SpaceThemeMode.Gradient,
        Tincture.GraphiteFrost));

    /// Abyss through ocean blue to lagoon, its icon in foam.
    public static readonly SpaceHouse River = new("river", "Ocean", "CrestRiver", HouseLook(
        [Tincture.OceanAbyss, Tincture.OceanBlue, Tincture.OceanLagoon], SpaceThemeMode.Gradient,
        Tincture.OceanFoam));

    /// Mulberry through coral to peach, its icon in cream.
    public static readonly SpaceHouse Sun = new("sun", "Dawn", "CrestSun", HouseLook(
        [Tincture.DawnMulberry, Tincture.DawnCoral, Tincture.DawnPeach], SpaceThemeMode.Gradient,
        Tincture.DawnCream, gradientAngle: 160));

    /// Aubergine through violet to lavender, its icon in lilac.
    public static readonly SpaceHouse Vigil = new("vigil", "Grape", "CrestVigil", HouseLook(
        [Tincture.GrapeAubergine, Tincture.GrapeViolet, Tincture.GrapeLavender], SpaceThemeMode.Gradient,
        Tincture.GrapeLilac));

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
