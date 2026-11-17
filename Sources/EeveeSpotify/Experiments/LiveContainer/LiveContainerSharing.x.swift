import Orion
import UIKit
import UniformTypeIdentifiers

class UIApplicationLiveContainerSharingHook: ClassHook<UIApplication> {
    func openURL(
        _ url: URL,
        options: [String: Any],
        completionHandler: (@MainActor (ObjCBool) -> Void)?
    ) {
        if UserDefaults.experimentsOptions.liveContainerSharing, !target.canOpenURL(url) {
            UIPasteboard.general.addItems([[UTType.url.identifier: url]])
            
            let data = url.dataRepresentation
            var components = URLComponents()
            components.scheme = "livecontainer"
            components.host = "open-url"
            components.queryItems = [URLQueryItem(name: "url", value: data.base64EncodedString())]
            guard let liveContainerUrl = components.url else {
                onMainThreadSync { completionHandler?(false) }
                return
            }
            
            orig.openURL(
                liveContainerUrl,
                options: options,
                completionHandler: { success in
                    completionHandler?(success)
                    
                    if !success.boolValue {
                        PopUpHelper.showPopUp(
                            delayed: false,
                            message: "could_not_share_popup".localized,
                            buttonText: "OK".uiKitLocalized
                        )
                    }
                }
            )
            
            return
        }
        
        orig.openURL(url, options: options, completionHandler: completionHandler)
    }
}
