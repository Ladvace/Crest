using CrestCore.Application;

namespace CrestCore.Contracts;

/// The reviewed Spaces the sign-ins of each of `Sites` belong with, by their
/// identity in the review setup holds for `WorkspaceId`, before it is
/// imported: an engine that lays sign-ins down in a new Space's profile
/// before that profile opens asks this. Only each site's profile and host
/// cross. Throws `Rejected` with `NoSetup` when setup holds no review for
/// the workspace.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ImportSignInSources(Guid WorkspaceId, IReadOnlyList<ImportPasswordSource> Sites)
    : Query<ImportPasswordRoutes> {
    #region Actions - Answering

    internal override ImportPasswordRoutes Answer(CrestApp app) =>
        (app.Device.ImportReview(WorkspaceId) ?? throw new Rejected(new NoSetup())).SignInSources(Sites);

    #endregion
}
