import UIKit

final class SettingsViewController: UIViewController {

    private let settings: [(title: String, icon: String)] = [
        ("معلومات التطبيق", "info.circle"),
        ("مسح جميع التحميلات", "trash"),
        ("مشاركة التطبيق", "square.and.arrow.up")
    ]

    private var tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "الإعدادات"
        view.backgroundColor = .systemBackground

        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Actions

    private func showAppInfo() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let message = """
        الإصدار: \(version)

        متصفح مع مانع إعلانات واكتشاف وتحميل فيديوهات.

        التحميل المدعوم:
        • ملفات مباشرة (MP4 / MOV / M4V)
        • بث HLS (m3u8) — يُحفظ كفيديو كامل قابل للتشغيل

        غير مدعوم: DASH والمواقع المحمية بتوقيعات خاصة.
        """
        let alert = UIAlertController(title: "Video Pro", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسناً", style: .default))
        present(alert, animated: true)
    }

    private func confirmClearDownloads() {
        let alert = UIAlertController(title: "مسح جميع التحميلات؟",
                                      message: "سيتم حذف كل الفيديوهات المحفوظة في المكتبة نهائياً.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        alert.addAction(UIAlertAction(title: "مسح", style: .destructive) { [weak self] _ in
            self?.clearDownloads()
        })
        present(alert, animated: true)
    }

    private func clearDownloads() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(at: documents,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: .skipsHiddenFiles) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        NotificationCenter.default.post(name: DownloadManager.didFinishNotification, object: nil)

        let alert = UIAlertController(title: "تم", message: "تم مسح جميع التحميلات", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسناً", style: .default))
        present(alert, animated: true)
    }

    private func shareApp(from sourceView: UIView) {
        let text = "جرّب تطبيق Video Pro — متصفح قوي مع مانع إعلانات وتحميل فيديوهات!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = sourceView
        activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        present(activityVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        settings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let setting = settings[indexPath.row]
        cell.textLabel?.text = setting.title
        cell.imageView?.image = UIImage(systemName: setting.icon)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.row {
        case 0:
            showAppInfo()
        case 1:
            confirmClearDownloads()
        case 2:
            if let cell = tableView.cellForRow(at: indexPath) {
                shareApp(from: cell)
            }
        default:
            break
        }
    }
}
