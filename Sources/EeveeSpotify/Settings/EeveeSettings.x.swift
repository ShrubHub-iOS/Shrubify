import Orion
import SwiftUI
import UIKit

// Settings integration - only works on non-9.1.x versions
struct SettingsIntegrationGroup: HookGroup { }

class ProfileSettingsSectionHook: ClassHook<NSObject> {
    typealias Group = SettingsIntegrationGroup
    static let targetName = "ProfileSettingsSection"

    func numberOfRows() -> Int {
        return 2
    }

    func didSelectRow(_ row: Int) {
        if row == 1 {
            guard let rootSettingsController = WindowHelper.shared.findFirstViewController(
                "RootSettingsViewController"
            ), let navigationController = rootSettingsController.navigationController else {
                eeveeLog("[Shrubify] Settings controller unavailable; skipping presentation")
                return
            }

            ShrubifySettingsPresenter.present(from: navigationController)

            return
        }

        orig.didSelectRow(row)
    }

    func cellForRow(_ row: Int) -> UITableViewCell {
        if row == 1 {
            let settingsTableCell = Dynamic.SPTSettingsTableViewCell
                .alloc(interface: SPTSettingsTableViewCell.self)
                .initWithStyle(3, reuseIdentifier: "Shrubify")
            
            let tableViewCell = Dynamic.convert(settingsTableCell, to: UITableViewCell.self)

            tableViewCell.accessoryView = type(
                of: Dynamic.SPTDisclosureAccessoryView
                    .alloc(interface: SPTDisclosureAccessoryView.self)
            )
            .disclosureAccessoryView()
            
            tableViewCell.textLabel?.text = "Shrubify"
            return tableViewCell
        }

        return orig.cellForRow(row)
    }
}
