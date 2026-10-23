using CrestCore.Application;

namespace CrestCore.Contracts;

/// A content-blocking policy's rules as content rule lists to compile:
/// translated from `Lists`, the text of the policy's downloaded filter lists,
/// or its fallback hosts while it has none, and leaving the sites
/// `ExemptHosts` names, and their subdomains, unblocked. A policy that blocks
/// nothing has none.
/// The lists of a strict policy run to tens of megabytes of text.
[MessageLimit(160 * 1024 * 1024)]
public sealed record ContentBlockingRules(ContentBlockingPolicy Policy, IReadOnlyList<string> Lists, IReadOnlyList<string> ExemptHosts)
    : Query<ContentRuleLists> {
    #region Actions - Answering

    internal override ContentRuleLists Answer(CrestApp app) => new(Policy.RuleLists(Lists, ExemptHosts));

    #endregion
}
