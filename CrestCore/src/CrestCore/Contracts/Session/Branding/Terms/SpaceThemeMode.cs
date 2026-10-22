namespace CrestCore.Contracts;

/// Whether a Space's sidebar is one solid color or a gradient of its colors.
public sealed class SpaceThemeMode {
    #region Types

    /// Each mode is drawn by a different view, so the code that draws a sidebar switches over the kind.
    public enum Kinds { Banner, Gradient }

    #endregion

    #region Variables

    public static readonly SpaceThemeMode Banner = new(Kinds.Banner, "banner", "Solid");
    public static readonly SpaceThemeMode Gradient = new(Kinds.Gradient, "gradient", "Gradient");

    public static IReadOnlyList<SpaceThemeMode> All { get; } = [Banner, Gradient];

    public Kinds Kind { get; }
    public string Name { get; }

    /// The choice's name where a person picks it.
    [Localized]
    public string Title { get; }

    #endregion

    #region Constructors

    private SpaceThemeMode(Kinds kind, string name, string title) {
        Kind = kind;
        Name = name;
        Title = title;
    }

    #endregion

    #region Actions - Lookup

    public static SpaceThemeMode? Named(string? name) => All.FirstOrDefault(mode => mode.Name == name);

    #endregion
}
