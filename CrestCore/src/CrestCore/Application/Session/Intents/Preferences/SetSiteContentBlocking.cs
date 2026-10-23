using CrestCore.Application;

namespace CrestCore.Contracts;

/// Content blocking blocks on the site `Host` names, or leaves it and its
/// subdomains alone, in every Space. A host is kept without `www.`; one that
/// names no host changes nothing.
public sealed record SetSiteContentBlocking(Guid WorkspaceId, string Host, bool Blocks) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequirePreferenceOwner();
        return workspace.Preferred(turn.Basis, (turn.Basis.AppPreferences ?? AppPreferences.Default)
            .WithContentBlocking(Host, Blocks));
    }

    #endregion
}
