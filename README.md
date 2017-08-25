# CoreDataJsonParser
JSON to Core Data parser

# Example

```swift

protocol PresenterDelegate: ArrayChangeManagerDelegate {}

class Presenter<D: PresenterDelegate> where D.Object == Int {

    weak var delegate: D? {
        didSet {
            arrayManager.delegate = delegate
        }
    }

    private let arrayManager = D.Manager()

    private(set) var array: [D.Object] {
        get { return arrayManager.objects }
        set { arrayManager.objects = newValue }
    }

    func test() {
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            arrayManager.cancelPreviousChanges()
            array = (0..<random()).map { _ in random() }
        }
    }

    private func random() -> Int {
        return Int(arc4random_uniform(9) + 1)
    }

}

import UIKit

final class ViewController: UITableViewController, PresenterDelegate {

    // MARK: - UITableViewController

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.array.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    // MARK: - Manager

    lazy var presenter: Presenter<ViewController> = {
        let presenter = Presenter<ViewController>()
        presenter.delegate = self
        return presenter
    }()

    // MARK: - ManagerDelegate

    typealias Object = Int

    func objectAtIndex(_ change: Manager.ObjectChange, manager: Manager) {
        switch change {
        case .begin:
            tableView.beginUpdates()
        case .added(let position):
            tableView.insertRows(at: [IndexPath(row: position, section: 0)], with: .fade)
        case .moved(let at, let to):
            tableView.moveRow(at: IndexPath(row: at, section: 0), to: IndexPath(row: to, section: 0))
        case .deleted(let position):
            tableView.deleteRows(at: [IndexPath(row: position, section: 0)], with: .fade)
        case .end:
            tableView.endUpdates()
        case .new:
            tableView.reloadData()
        }
    }

}

let controller = ViewController()
controller.presenter.test()

```

