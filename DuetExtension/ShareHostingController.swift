import UIKit
import SwiftUI
import Firebase

class ShareHostingController: UIViewController {
    private let vm = ShareSheetViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Firebase for getting fresh auth tokens
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let rootView = ShareContentView(vm: vm)
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        vm.configure(with: extensionContext)
    }
} 