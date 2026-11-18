import Foundation

func getPremiumPlanBadge() throws -> Data {
    let badge = YourPremiumBadge.with {
        $0.name = "Shrubify"
        $0.version = 2
        $0.colorCode = "#FFD2D7"
    }
    
    return try badge.serializedData()
}

func getPremiumPlanRowData(originalPremiumPlanRow: PremiumPlanRow) throws -> Data {
    var premiumPlanRow = originalPremiumPlanRow
    
    premiumPlanRow.planName = "Shrubify"
    premiumPlanRow.planIdentifier = "Shrubify"
    premiumPlanRow.colorCode = "#FFD2D7"
    
    return try premiumPlanRow.serializedData()
}

// Change the local display name without fabricating a paid subscription,
// billing dates, renewal state or server-backed capabilities.
func getPlanOverviewData(original: SpotifyPlan) throws -> Data {
    var plan = original
    plan.subscription.planName = "Shrubify"
    plan.subscription.colorCode = "#FFD2D7"
    if plan.hasNotice {
        plan.notice.message = "Shrubify features are active on this device. Your Spotify subscription and billing are separate."
    }
    return try plan.serializedData()
}
