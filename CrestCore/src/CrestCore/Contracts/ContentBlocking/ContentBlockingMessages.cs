namespace CrestCore.Contracts;

#region Models

/// A content rule list: the versioned identifier a rule-list store compiles it
/// under, and its WebKit content-rule JSON source.
public sealed record ContentRuleList(string Identifier, string Source);

/// The content rule lists a policy compiles into, in the order a page applies
/// them.
public sealed record ContentRuleLists(IReadOnlyList<ContentRuleList> Lists);

#endregion
