// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import TrustCore

struct ImageURLFormatter {

    func image(for coin: Coin) -> String {
        return Constants.images + "/coins/\(coin.rawValue).png"
    }

    func image(for contract: String) -> String {
        return Constants.images + "/tokens/\(contract.lowercased()).png"
    }
    
    func imageForSoc() -> String {
        return "http://test-socscan.allsportschain.com/static/img/soc-logo.99617b5.png"
    }
    
}
