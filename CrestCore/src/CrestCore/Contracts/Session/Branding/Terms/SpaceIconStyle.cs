namespace CrestCore.Contracts;

/// How a Space's icon is drawn: as its plain symbol. A Space stored with a
/// layered crest, which Crest no longer draws, reads as its plain symbol.
public sealed class SpaceIconStyle {
    #region Types

    public enum Kinds { SimpleSymbol }

    #endregion

    #region Variables

    public static readonly SpaceIconStyle SimpleSymbol = new(Kinds.SimpleSymbol, "simpleSymbol", "Icon");

    public static IReadOnlyList<SpaceIconStyle> All { get; } = [SimpleSymbol];

    public Kinds Kind { get; }
    public string Name { get; }

    /// The choice's name where a person picks it.
    [Localized]
    public string Title { get; }

    #endregion

    #region Constructors

    private SpaceIconStyle(Kinds kind, string name, string title) {
        Kind = kind;
        Name = name;
        Title = title;
    }

    #endregion

    #region Actions - Lookup

    public static SpaceIconStyle? Named(string? name) => All.FirstOrDefault(style => style.Name == name);

    #endregion
}
