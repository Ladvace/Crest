import WebKit

extension BrowserPlatformPage {
    func applyContentBlocking(
        policy: ContentBlockingPolicy,
        ruleList: WKContentRuleList?,
        activation: BrowserContentRuleListActivation = .onNextNavigation
    ) {
        applyContentBlocking(
            policy: policy,
            ruleLists: ruleList.map { [$0] } ?? [],
            activation: activation
        )
    }
}
