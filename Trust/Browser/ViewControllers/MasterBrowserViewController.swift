// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit

protocol MasterBrowserViewControllerDelegate: class {
    func didPressAction(_ action: BrowserToolbarAction)
}

enum BrowserToolbarAction {
    case view(GameViewType)
}

enum GameViewType: Int {
    case ryb
    case dice
    case guess
}

final class MasterBrowserViewController: UIViewController {

    private lazy var segmentController: UISegmentedControl = {
        let items = [
            NSLocalizedString("Game.ryb", comment: "RYB"),
            NSLocalizedString("Game.dice", comment: "Dice"),
            NSLocalizedString("Game.guess", comment: "Guess"),
        ]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.addTarget(self, action: #selector(selectionDidChange(_:)), for: .valueChanged)
        segmentedControl.tintColor = .clear
        return segmentedControl
    }()

    weak var delegate: MasterBrowserViewControllerDelegate?

    let rybViewController: BrowserViewController
    let diceViewController: BrowserViewController
    let guessViewController: BrowserViewController
    var currentViewController: BrowserViewController

    init(
        rybViewController: BrowserViewController,
        diceViewController: BrowserViewController,
        guessViewController: BrowserViewController,
        type: GameViewType
    ) {
        self.rybViewController = rybViewController
        self.diceViewController = diceViewController
        self.guessViewController = guessViewController
        self.currentViewController = rybViewController
        super.init(nibName: nil, bundle: nil)

        segmentController.selectedSegmentIndex = type.rawValue
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    func select(viewType: GameViewType) {
        segmentController.selectedSegmentIndex = viewType.rawValue
        updateView()
    }

    private func setupView() {
        let items: [UIBarButtonItem] = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(customView: segmentController),
//            UIBarButtonItem(customView: qrcodeButton),
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
        ]
        self.toolbarItems = items
        self.navigationController?.isToolbarHidden = false
        self.navigationController?.toolbar.isTranslucent = false
        updateView()
    }

    private func updateView() {
        if segmentController.selectedSegmentIndex == GameViewType.ryb.rawValue {
            remove(asChildViewController: guessViewController)
            remove(asChildViewController: diceViewController)
            add(asChildViewController: rybViewController)
            self.currentViewController = rybViewController
        } else if segmentController.selectedSegmentIndex == GameViewType.dice.rawValue {
            remove(asChildViewController: guessViewController)
            remove(asChildViewController: rybViewController)
            add(asChildViewController: diceViewController)
            self.currentViewController = diceViewController
        } else {
            remove(asChildViewController: rybViewController)
            remove(asChildViewController: diceViewController)
            add(asChildViewController: guessViewController)
            self.currentViewController = guessViewController
        }
    }

    @objc func selectionDidChange(_ sender: UISegmentedControl) {
        updateView()

        guard let viewType = GameViewType(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        delegate?.didPressAction(.view(viewType))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MasterBrowserViewController: Scrollable {
    func scrollOnTop() {
        self.currentViewController.goHome()
    }
}
