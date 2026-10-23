using CrestCore.Application;

namespace CrestCore.Contracts;

/// The Spaces the sign-ins of each of `Sites` go to once the review setup
/// holds for `WorkspaceId` is imported: the destination of each reviewed
/// Space that brings its sign-ins and that the site belongs with, as
/// `ImportPasswordDestinations` routes passwords. Only each site's profile
/// and host cross; what keeps it signed in never does. Throws `Rejected`
/// with `NoSetup` when setup holds no review for the workspace.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ImportSignInDestinations(Guid WorkspaceId, IReadOnlyList<ImportPasswordSource> Sites)
    : Query<ImportPasswordRoutes> {
    #region Actions - Answering

    internal override ImportPasswordRoutes Answer(CrestApp app) {
        var review = app.Device.ImportReview(WorkspaceId) ?? throw new Rejected(new NoSetup());
        var authority = app.Device.Workspace(WorkspaceId);
        return review.SignInRoutes(Sites, authority.Current, authority.IsLocked);
    }

    #endregion
}
