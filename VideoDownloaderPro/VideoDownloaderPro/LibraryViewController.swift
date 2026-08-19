import UIKit
import AVKit
import AVFoundation

final class LibraryViewController: UIViewController {

    private static let supportedExtensions: Set<String> = ["mp4", "m4v", "mov", "movpkg", "webm"]

    private var tableView = UITableView(frame: .zero, style: .plain)
    private var items: [URL] = []

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "لا توجد تحميلات بعد\nستظهر هنا الفيديوهات التي تحمّلها من المتصفح"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "المكتبة"
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

        navigationItem.rightBarButtonItem = editButtonItem

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadItems),
                                               name: DownloadManager.didFinishNotification,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadItems()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }

    @objc private func reloadItems() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        items = files
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return lDate > rDate
            }

        tableView.backgroundView = items.isEmpty ? emptyLabel : nil
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension LibraryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let item = items[indexPath.row]
        cell.textLabel?.text = item.deletingPathExtension().lastPathComponent
        cell.detailTextLabel?.text = item.pathExtension.uppercased()
        cell.imageView?.image = UIImage(systemName: item.pathExtension.lowercased() == "movpkg" ? "hifispeaker.fill" : "play.rectangle")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let player = AVPlayer(url: items[indexPath.row])
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) {
            player.play()
        }
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        try? FileManager.default.removeItem(at: items[indexPath.row])
        items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        tableView.backgroundView = items.isEmpty ? emptyLabel : nil
    }
}
