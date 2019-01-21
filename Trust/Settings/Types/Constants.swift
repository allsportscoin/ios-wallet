// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public struct Constants {
    public static let keychainKeyPrefix = "trustwallet"
    public static let keychainTestsKeyPrefix = "trustwallet-tests"

    // social
    public static let website = "https://trustwalletapp.com"
    public static let twitterUsername = "trustwalletapp"
    public static let defaultTelegramUsername = "trustwallet"
    public static let facebookUsername = "trustwalletapp"

    public static var localizedTelegramUsernames = ["ru": "trustwallet_ru", "vi": "trustwallet_vn", "es": "trustwallet_vves", "zh": "trustwallet_cn", "ja": "trustwallet_jp", "de": "trustwallet_de", "fr": "trustwallet_fr"]

    // support
    public static let supportEmail = "support@trustwalletapp.com"

    public static let dappsBrowserURL = ""
    public static let dappsGameRYBBrowserURL = "http://test-socscan.allsportschain.com/pages/dapp/ryb/?language=en#/"
    public static let dappsGameDiceBrowserURL = "http://test-socscan.allsportschain.com/pages/dapp/dice/?language=en"
    public static let dappsGameGuessBrowserURL = "http://test-socscan.allsportschain.com/pages/dapp/guess/?language=en#/"
    public static let dappsOpenSea = "https://opensea.io"
    public static let dappsRinkebyOpenSea = "https://rinkeby.opensea.io"

    public static let images = "https://trustwalletapp.com/images"

    public static let trustAPI = URL(string: "https://public.trustwalletapp.com")!
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
}

public struct URLSchemes {
    public static let trust = "app://"
    public static let browser = trust + "browser"
}
