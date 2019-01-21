// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore
import RealmSwift
import URLNavigator
import WebKit
import Branch

protocol BrowserCoordinatorDelegate: class {
    func didSentTransaction(transaction: SentTransaction, in coordinator: BrowserCoordinator)
}

final class BrowserCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    let session: WalletSession
    let keystore: Keystore
    let navigationController: NavigationController
    
    

    lazy var rybViewController: BrowserViewController = {
        let controller = BrowserViewController(account: session.account, config: session.config, server: server ,browserUrl: Constants.dappsGameRYBBrowserURL)
        controller.delegate = self
        controller.webView.uiDelegate = self
        return controller
    }()

    lazy var diceViewController: BrowserViewController = {
        let controller = BrowserViewController(account: session.account, config: session.config, server: server ,browserUrl: Constants.dappsGameDiceBrowserURL)
        controller.delegate = self
        controller.webView.uiDelegate = self
        return controller
    }()
    
    lazy var guessViewController: BrowserViewController = {
        let controller = BrowserViewController(account: session.account, config: session.config, server: server ,browserUrl: Constants.dappsGameGuessBrowserURL)
        controller.delegate = self
        controller.webView.uiDelegate = self
        return controller
    }()

    lazy var rootViewController: MasterBrowserViewController = {
        let controller = MasterBrowserViewController(
            rybViewController: rybViewController,
            diceViewController: diceViewController,
            guessViewController: guessViewController,
            type: .ryb
        )
        controller.delegate = self
        return controller
    }()

    
    private let sharedRealm: Realm
    private lazy var bookmarksStore: BookmarksStore = {
        return BookmarksStore(realm: sharedRealm)
    }()
    private lazy var historyStore: HistoryStore = {
        return HistoryStore(realm: sharedRealm)
    }()
    lazy var preferences: PreferencesController = {
        return PreferencesController()
    }()
    var urlParser: BrowserURLParser {
        let engine = SearchEngine(rawValue: preferences.get(for: .browserSearchEngine)) ?? .default
        return BrowserURLParser(engine: engine)
    }

    var server: RPCServer {
        return session.currentRPC
    }

    weak var delegate: BrowserCoordinatorDelegate?

    var enableToolbar: Bool = true {
        didSet {
            navigationController.isToolbarHidden = !enableToolbar
        }
    }

    init(
        session: WalletSession,
        keystore: Keystore,
        navigator: Navigator,
        sharedRealm: Realm
    ) {
        self.navigationController = NavigationController(navigationBarClass: BrowserNavigationBar.self, toolbarClass: nil)
        self.session = session
        self.keystore = keystore
        self.sharedRealm = sharedRealm
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
        rootViewController.guessViewController.goHome()
        rootViewController.rybViewController.goHome()
        rootViewController.diceViewController.goHome()
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    private func executeTransaction(account: Account, action: DappAction, callbackID: Int, transaction: UnconfirmedTransaction, type: ConfirmType, server: RPCServer) {
        let configurator = TransactionConfigurator(
            session: session,
            account: account,
            transaction: transaction,
            server: server,
            chainState: ChainState(server: server)
        )
        let coordinator = ConfirmCoordinator(
            session: session,
            configurator: configurator,
            keystore: keystore,
            account: account,
            type: type,
            server: server
        )
        addCoordinator(coordinator)
        coordinator.didCompleted = { [unowned self] result in
            switch result {
            case .success(let type):
                switch type {
                case .signedTransaction(let transaction):
                    // on signing we pass signed hex of the transaction
                    let callback = DappCallback(id: callbackID, value: .signTransaction(transaction.data))
                    self.rootViewController.currentViewController
                        .notifyFinish(callbackID: callbackID, value: .success(callback))
                    self.delegate?.didSentTransaction(transaction: transaction, in: self)
                case .sentTransaction(let transaction):
                    // on send transaction we pass transaction ID only.
                    let data = Data(hex: transaction.id)
                    let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                    self.rootViewController.currentViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    self.delegate?.didSentTransaction(transaction: transaction, in: self)
                }
            case .failure:
                self.rootViewController.currentViewController.notifyFinish(
                    callbackID: callbackID,
                    value: .failure(DAppError.cancelled)
                )
            }
            coordinator.didCompleted = nil
            self.removeCoordinator(coordinator)
            self.navigationController.dismiss(animated: true, completion: nil)
        }
        coordinator.start()
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
    }

    func openURL(_ url: URL) {
        rootViewController.currentViewController.goTo(url: url)
        handleToolbar(for: url)
    }

    func handleToolbar(for url: URL) {
        let isToolbarHidden = url.absoluteString != Constants.dappsBrowserURL
        navigationController.isToolbarHidden = isToolbarHidden
    }

    func signMessage(with type: SignMesageType, account: Account, callbackID: Int) {
        let coordinator = SignMessageCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            account: account
        )
        coordinator.didComplete = { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let data):
                let callback: DappCallback
                switch type {
                case .message:
                    callback = DappCallback(id: callbackID, value: .signMessage(data))
                case .personalMessage:
                    callback = DappCallback(id: callbackID, value: .signPersonalMessage(data))
                case .typedMessage:
                    callback = DappCallback(id: callbackID, value: .signTypedMessage(data))
                }
                self.rootViewController.currentViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
            case .failure:
                self.rootViewController.currentViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            }
            coordinator.didComplete = nil
            self.removeCoordinator(coordinator)
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(with: type)
    }

    private func presentMoreOptions(sender: UIView) {
        let alertController = makeMoreAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true, completion: nil)
    }
    
    private func presentGameOptions(sender: UIView) {
        let alertController = makeGameAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true, completion: nil)
    }
    
    private func makeGameAlertSheet(sender: UIView) -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect
        let rybAction = UIAlertAction(title: NSLocalizedString("Game.ryb", comment: "RYB"), style: .default) { [unowned self] _ in
//            self.rootViewController.browserViewController.reload()
            self.rootViewController.select(viewType: .ryb)
        }
        let diceAction = UIAlertAction(title: NSLocalizedString("Game.dice", comment: "Dice"), style: .default) { [unowned self] _ in
//            self.share()
            self.rootViewController.select(viewType: .dice)
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        let guessAction = UIAlertAction(title: NSLocalizedString("Game.guess", comment: "Guess"), style: .default) { [unowned self] _ in
//            self.rootViewController.browserViewController.addBookmark()
            self.rootViewController.select(viewType: .guess)
        }
        alertController.addAction(rybAction)
        alertController.addAction(diceAction)
        alertController.addAction(guessAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    private func makeMoreAlertSheet(sender: UIView) -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect
        let reloadAction = UIAlertAction(title: R.string.localizable.reload(), style: .default) { [unowned self] _ in
            self.rootViewController.currentViewController.reload()
        }
        let shareAction = UIAlertAction(title: R.string.localizable.share(), style: .default) { [unowned self] _ in
            self.share()
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(reloadAction)
        alertController.addAction(shareAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    private func share() {
        guard let url = rootViewController.currentViewController.webView.url else { return }
        rootViewController.displayLoading()
        let params = BranchEvent.openURL(url).params
        Branch.getInstance().getShortURL(withParams: params) { [weak self] shortURLString, _ in
            guard let `self` = self else { return }
            let shareURL: URL = {
                if let shortURLString = shortURLString, let shortURL = URL(string: shortURLString) {
                    return shortURL
                }
                return url
            }()
            self.rootViewController.showShareActivity(from: UIView(), with: [shareURL]) { [weak self] in
                self?.rootViewController.hideLoading()
            }
        }
    }
}

extension BrowserCoordinator: BrowserViewControllerDelegate {
    func runAction(action: BrowserAction) {
        switch action {
        case .navigationAction(let navAction):
            switch navAction {
            case .select(let sender):
                presentGameOptions(sender: sender)
            case .more(let sender):
                presentMoreOptions(sender: sender)
            case .enter(let string):
                guard let url = urlParser.url(from: string) else { return }
                openURL(url)
            case .goBack:
                rootViewController.currentViewController.webView.goBack()
            default: break
            }
        case .changeURL(let url):
            break
        }
    }

    func didCall(action: DappAction, callbackID: Int) {
        guard let account = session.account.currentAccount, let _ = account.wallet else {
            self.rootViewController.currentViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            self.navigationController.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
            return
        }
        switch action {
        case .signTransaction(let unconfirmedTransaction):
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: self.rootViewController.currentViewController.server)
        case .sendTransaction(let unconfirmedTransaction):
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: self.rootViewController.currentViewController.server)
        case .signMessage(let hexMessage):
            signMessage(with: .message(Data(hex: hexMessage)), account: account, callbackID: callbackID)
        case .signPersonalMessage(let hexMessage):
            signMessage(with: .personalMessage(Data(hex: hexMessage)), account: account, callbackID: callbackID)
        case .signTypedMessage(let typedData):
            signMessage(with: .typedMessage(typedData), account: account, callbackID: callbackID)
        case .unknown:
            break
        }
    }

    func didVisitURL(url: URL, title: String) {
        historyStore.record(url: url, title: title)
    }
}

extension BrowserCoordinator: SignMessageCoordinatorDelegate {
    func didCancel(in coordinator: SignMessageCoordinator) {
        coordinator.didComplete = nil
        removeCoordinator(coordinator)
    }
}

extension BrowserCoordinator: ConfirmCoordinatorDelegate {
    func didCancel(in coordinator: ConfirmCoordinator) {
        navigationController.dismiss(animated: true, completion: nil)
        coordinator.didCompleted = nil
        removeCoordinator(coordinator)
    }
}


extension BrowserCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            self.rootViewController.currentViewController.webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: message,
            style: .alert,
            in: navigationController
        )
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            completionHandler()
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: message,
            style: .alert,
            in: navigationController
        )
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            completionHandler(true)
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .default, handler: { _ in
            completionHandler(false)
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: prompt,
            style: .alert,
            in: navigationController
        )
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .default, handler: { _ in
            completionHandler(nil)
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }
}

extension BrowserCoordinator: MasterBrowserViewControllerDelegate {
    func didPressAction(_ action: BrowserToolbarAction) {
        switch action {
        case .view(let viewType):
            switch viewType {
            case .dice:
                break
            case .guess:
                break
            case .ryb:
                break
            }
        }
    }
}
