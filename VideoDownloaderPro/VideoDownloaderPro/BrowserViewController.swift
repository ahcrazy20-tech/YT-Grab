import UIKit
import WebKit

struct VideoInfo {
    enum Kind { case file, hls, dash }
    let url: String
    let title: String
    let kind: Kind

    var kindLabel: String {
        switch kind {
        case .file: return "MP4"
        case .hls:  return "HLS"
        case .dash: return "DASH"
        }
    }
}

final class BrowserViewController: UIViewController {

    private var webView: WKWebView!
    private var urlTextField: UITextField!
    private var progressView: UIProgressView!
    private var menuButton: UIButton!
    private var downloadButton: UIBarButtonItem!
    private var shareButton: UIBarButtonItem!
    private var detectedVideos: [VideoInfo] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "متصفح"
        view.backgroundColor = .systemBackground

        setupUI()
        setupWebView()
        setupToolbar()
        loadHomePage()
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    // MARK: - UI

    private func setupUI() {
        let urlContainer = UIView()
        urlContainer.backgroundColor = .systemBackground
        view.addSubview(urlContainer)
        urlContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            urlContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            urlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            urlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            urlContainer.heightAnchor.constraint(equalToConstant: 50)
        ])

        menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        menuButton.addTarget(self, action: #selector(showMenu), for: .touchUpInside)
        urlContainer.addSubview(menuButton)
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo: urlContainer.leadingAnchor, constant: 12),
            menuButton.centerYAnchor.constraint(equalTo: urlContainer.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        urlTextField = UITextField()
        urlTextField.borderStyle = .roundedRect
        urlTextField.placeholder = "ابحث أو أدخل الرابط..."
        urlTextField.keyboardType = .webSearch
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.returnKeyType = .go
        urlTextField.clearButtonMode = .whileEditing
        urlTextField.delegate = self
        urlTextField.backgroundColor = .secondarySystemBackground
        urlContainer.addSubview(urlTextField)
        urlTextField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            urlTextField.leadingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 8),
            urlTextField.trailingAnchor.constraint(equalTo: urlContainer.trailingAnchor, constant: -12),
            urlTextField.centerYAnchor.constraint(equalTo: urlContainer.centerYAnchor),
            urlTextField.heightAnchor.constraint(equalToConstant: 36)
        ])

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progressTintColor = .systemBlue
        progressView.isHidden = true
        view.addSubview(progressView)
        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: urlContainer.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptEnabled = true

        let contentController = WKUserContentController()
        contentController.addUserScript(WKUserScript(source: JSScripts.adBlocker,
                                                     injectionTime: .atDocumentStart,
                                                     forMainFrameOnly: false))
        contentController.addUserScript(WKUserScript(source: JSScripts.videoDetector,
                                                     injectionTime: .atDocumentEnd,
                                                     forMainFrameOnly: false))
        contentController.add(self, name: "videoHandler")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44)
        ])

        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
    }

    private func setupToolbar() {
        let toolbar = UIToolbar()
        view.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])

        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(goBack))
        let forwardButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(goForward))
        let refreshButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reloadPage))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        downloadButton = UIBarButtonItem(image: UIImage(systemName: "arrow.down.circle.fill"), style: .plain, target: self, action: #selector(showDownloadOptions))
        shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(sharePage))

        toolbar.items = [backButton, flexSpace, forwardButton, flexSpace, refreshButton, flexSpace, downloadButton, flexSpace, shareButton]
    }

    private func loadHomePage() {
        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Actions

    @objc private func showMenu() {
        let alert = UIAlertController(title: "القائمة", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "الصفحة الرئيسية", style: .default) { [weak self] _ in
            self?.loadHomePage()
        })

        alert.addAction(UIAlertAction(title: "مسح بيانات المواقع", style: .destructive) { [weak self] _ in
            self?.clearData()
        })

        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))

        // Required on iPad — an action sheet without an anchor crashes the app.
        alert.popoverPresentationController?.sourceView = menuButton
        alert.popoverPresentationController?.sourceRect = menuButton.bounds

        present(alert, animated: true)
    }

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func reloadPage() { webView.reload() }

    @objc private func showDownloadOptions() {
        guard !detectedVideos.isEmpty else {
            showAlert("لا توجد فيديوهات", message: "لم يتم اكتشاف أي فيديو في هذه الصفحة.\nشغّل الفيديو أولاً ثم حاول مجدداً.")
            return
        }

        let alert = UIAlertController(title: "اختر الفيديو (\(detectedVideos.count))", message: nil, preferredStyle: .actionSheet)

        for video in detectedVideos.prefix(10) {
            let label = "[\(video.kindLabel)] \(video.title)"
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.startDownload(video)
            })
        }

        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))

        alert.popoverPresentationController?.barButtonItem = downloadButton
        present(alert, animated: true)
    }

    @objc private func sharePage() {
        guard let url = webView.url else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = shareButton
        present(activityVC, animated: true)
    }

    private func clearData() {
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                DispatchQueue.main.async {
                    self.webView.reload()
                    self.showAlert("تم", message: "تم مسح جميع بيانات التصفح")
                }
            }
        }
    }

    // MARK: - Downloading

    private func startDownload(_ video: VideoInfo) {
        guard let url = URL(string: video.url) else {
            showAlert("خطأ", message: "رابط الفيديو غير صالح")
            return
        }

        switch video.kind {
        case .dash:
            showAlert("غير مدعوم", message: "صيغة البث DASH غير مدعومة حالياً.")
        case .hls:
            showAlert("بدأ التحميل", message: video.title)
            DownloadManager.shared.downloadHLS(url: url, title: video.title, referer: webView.url) { [weak self] result in
                self?.handleDownloadResult(result, title: video.title)
            }
        case .file:
            showAlert("بدأ التحميل", message: video.title)
            DownloadManager.shared.downloadFile(url: url, title: video.title, referer: webView.url) { [weak self] result in
                self?.handleDownloadResult(result, title: video.title)
            }
        }
    }

    private func handleDownloadResult(_ result: Result<URL, Error>, title: String) {
        switch result {
        case .success:
            showAlert("تم التحميل ✅", message: "تم حفظ «\(title)» في المكتبة")
        case .failure(let error):
            showAlert("فشل التحميل", message: error.localizedDescription)
        }
    }

    // MARK: - Alert helpers

    private func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسناً", style: .default))
        presentOnTop(alert)
    }

    /// Presenting while an action sheet is still dismissing silently fails —
    /// dismiss whatever is up first, then present.
    private func presentOnTop(_ vc: UIViewController) {
        if let presented = presentedViewController {
            presented.dismiss(animated: false) { [weak self] in
                self?.present(vc, animated: true)
            }
        } else {
            present(vc, animated: true)
        }
    }

    // MARK: - KVO (page load progress)

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        detectedVideos.removeAll()
        progressView.isHidden = false
        progressView.progress = 0
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
        urlTextField.text = webView.url?.absoluteString
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension BrowserViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open target=_blank links in the same web view (popups are blocked by JS anyway).
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - UITextFieldDelegate

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return false }

        var urlString = text
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            if text.contains(".") && !text.contains(" ") {
                urlString = "https://" + text
            } else {
                let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
                urlString = "https://www.google.com/search?q=" + query
            }
        }

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        textField.resignFirstResponder()
        return true
    }
}

// MARK: - WKScriptMessageHandler

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "videoHandler", let dict = message.body as? [String: Any] else { return }

        let kind: VideoInfo.Kind
        switch (dict["format"] as? String)?.uppercased() {
        case "HLS":  kind = .hls
        case "DASH": kind = .dash
        default:     kind = .file
        }

        let video = VideoInfo(
            url: dict["url"] as? String ?? "",
            title: dict["title"] as? String ?? "فيديو",
            kind: kind
        )

        guard !video.url.isEmpty,
              !detectedVideos.contains(where: { $0.url == video.url }) else { return }

        detectedVideos.append(video)
    }
}
