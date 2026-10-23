using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Keeps the reviewed Space `SourceSpaceId` signed in to the sites the other
/// browser was signed in to that belong with it, or leaves them out.
public sealed record IncludeImportSignIns(Guid SourceSpaceId, bool Included) : SetupFlowIntent {
    #region Actions - Device

    internal override void Apply(Device device, DeviceTurn turn) => device.ReviseFlow(turn.Changes, (flow, session) =>
        Device.Editing(flow, review => review.IncludingSignIns(SourceSpaceId, Included, session)));

    #endregion
}
