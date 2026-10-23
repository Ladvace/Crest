namespace CrestCore.Contracts;

/// A community filter list Crest's content blocking downloads, in Adblock
/// Plus syntax. Crest never ships a list; each comes from its maintainers'
/// address under their license.
///
/// A list is named by its `Name`, so a name never changes. A list travels as
/// its index in `All`, so `All` is append-only.
public sealed class FilterList {
    #region Variables

    public static readonly FilterList EasyList = new(name: "easylist", title: "EasyList",
        address: "https://easylist.to/easylist/easylist.txt", licenseAddress: "https://easylist.to/pages/licence.html");
    public static readonly FilterList EasyPrivacy = new(name: "easyprivacy", title: "EasyPrivacy",
        address: "https://easylist.to/easylist/easyprivacy.txt", licenseAddress: "https://easylist.to/pages/licence.html");
    public static readonly FilterList UBlockFilters = new(name: "ublock-filters", title: "uBlock filters",
        address: "https://ublockorigin.github.io/uAssets/filters/filters.txt",
        licenseAddress: "https://github.com/uBlockOrigin/uAssets/blob/master/LICENSE");
    public static readonly FilterList UBlockPrivacy = new(name: "ublock-privacy", title: "uBlock filters – Privacy",
        address: "https://ublockorigin.github.io/uAssets/filters/privacy.txt",
        licenseAddress: "https://github.com/uBlockOrigin/uAssets/blob/master/LICENSE");
    public static readonly FilterList CookieNotices = new(name: "easylist-cookie", title: "EasyList Cookie",
        address: "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt", licenseAddress: "https://easylist.to/pages/licence.html");

    public static IReadOnlyList<FilterList> All { get; } = [EasyList, EasyPrivacy, UBlockFilters, UBlockPrivacy, CookieNotices];

    public string Name { get; }

    /// What the settings call the list.
    public string Title { get; }

    /// Where the list is downloaded from.
    public string Address { get; }

    /// Where the list's license is published.
    public string LicenseAddress { get; }

    #endregion

    #region Constructors

    private FilterList(string name, string title, string address, string licenseAddress) {
        Name = name;
        Title = title;
        Address = address;
        LicenseAddress = licenseAddress;
    }

    #endregion

    #region Actions - Lookup

    public static FilterList? Named(string? name) => All.FirstOrDefault(list => list.Name == name);

    #endregion
}
