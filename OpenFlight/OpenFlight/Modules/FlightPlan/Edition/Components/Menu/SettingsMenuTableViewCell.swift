//    Copyright (C) 2021 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import UIKit
import Reusable

enum SettingsMenuArrowVisibility {
    case visible
    case invisible
    case gone
}

/// Settings menu table view cell.
final class SettingsMenuTableViewCell: SettingsTableViewCell, NibReusable {
    // MARK: - Outlets
    @IBOutlet private weak var settingsKey: UILabel!
    @IBOutlet private weak var settingsValue: UILabel!
    @IBOutlet private weak var arrowView: UIView!
    @IBOutlet private weak var arrowStackView: UIStackView!

    // MARK: - Override Funcs
    override func awakeFromNib() {
        super.awakeFromNib()

        settingsKey.makeUp(with: .current, color: .defaultTextColor)
        settingsValue.makeUp(with: .current, color: .defaultTextColor)
    }
}

// MARK: - Internal Funcs
internal extension SettingsMenuTableViewCell {
    /// Setup cell.
    ///
    /// - Parameters:
    ///     - setting: flight plan setting
    func setup(setting: FlightPlanSetting, arrowVisibility: SettingsMenuArrowVisibility) {
        settingsKey.text = setting.shortTitle ?? setting.title
        if let descriptions = setting.valueDescriptions,
           let current = setting.currentValue,
           descriptions.count > current {
            // Use valueDescriptions if setting is custom.
            settingsValue.text = descriptions[current]
        } else if let currentValueDescription = setting.currentValueDescription {
            settingsValue.text = currentValueDescription
        } else {
            settingsValue.text = Style.dash
        }

        if settingsValue.text == L10n.commonYes {
            settingsValue.textColor = ColorName.highlightColor.color
        } else {
            settingsValue.textColor = ColorName.defaultTextColor.color
        }

        switch arrowVisibility {
        case .visible:
            arrowView.isHidden = false
            arrowStackView.isHidden = false

        case .invisible:
            arrowView.isHidden = false
            arrowStackView.isHidden = true
        case .gone:
            arrowView.isHidden = true
            arrowStackView.isHidden = false
        }
    }
}
