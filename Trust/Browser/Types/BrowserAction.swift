// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit

enum BrowserNavigation {
    case goBack
    case more(sender: UIView)
    case select(sender: UIView)
    case enter(String)
    case beginEditing
}
