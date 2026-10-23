using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Reopens the archived tabs `TabIds` as open tabs of their Space, in that
/// order at the top of its open tabs, and removes their entries from the
/// archive: what undoing a clear of the Space's open tabs asks. The window
/// that asked shows `ShownTabId` when it comes back, or else the first. A tab
/// the archive no longer holds, or one already open again, is passed over.
/// Refused with `UnknownArchivedTab` when the archive holds none of them.
public sealed record RestoreArchivedTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, IReadOnlyList<Guid> TabIds, Guid? ShownTabId)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        var space = workspace.Editable(turn.Basis, SpaceId);
        var open = turn.Basis.Spaces.SelectMany(candidate => candidate.Tabs).Select(tab => tab.Id).ToHashSet();
        var wanted = TabIds.Where(id => !open.Contains(id)).Distinct().ToArray();
        var archived = wanted.Select(id => space.ArchivedTabs.FirstOrDefault(entry => entry.Tab.Id == id))
            .OfType<ArchivedTabState>().ToArray();
        if (archived.Length == 0) throw new Rejected(new UnknownArchivedTab(TabIds.FirstOrDefault()));
        var restoredIds = archived.Select(entry => entry.Tab.Id).ToHashSet();
        var remaining = space with { ArchivedTabs = [.. space.ArchivedTabs.Where(entry => !restoredIds.Contains(entry.Tab.Id))] };
        var edited = BrowserTabCollection.Restore(remaining);
        // Each goes in at the top of the open tabs, so the last goes in first.
        foreach (var entry in archived.Reverse()) edited.RestoreArchived(entry.Tab, turn.Now);
        var shown = ShownTabId is { } id && restoredIds.Contains(id) ? id : archived[0].Tab.Id;
        var followUp = new WindowFollowUp(workspace.IssuingWindow(WindowId)).ShowTab(space.Id, shown);
        return new(NativeSessionAuthority.Replacing(turn.Basis, edited.Capture(remaining)), SyncStaging.Creation, followUp);
    }

    #endregion
}
