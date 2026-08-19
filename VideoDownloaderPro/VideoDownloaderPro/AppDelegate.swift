import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

// MARK: - Tab Bar Controller

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let browserNav = UINavigationController(rootViewController: BrowserViewController())
        browserNav.tabBarItem = UITabBarItem(title: "متصفح", image: UIImage(systemName: "safari"), tag: 0)

        let libraryNav = UINavigationController(rootViewController: LibraryViewController())
        libraryNav.tabBarItem = UITabBarItem(title: "المكتبة", image: UIImage(systemName: "film"), tag: 1)

        let settingsNav = UINavigationController(rootViewController: SettingsViewController())
        settingsNav.tabBarItem = UITabBarItem(title: "الإعدادات", image: UIImage(systemName: "gear"), tag: 2)

        viewControllers = [browserNav, libraryNav, settingsNav]
        tabBar.tintColor = .systemBlue
    }
}
