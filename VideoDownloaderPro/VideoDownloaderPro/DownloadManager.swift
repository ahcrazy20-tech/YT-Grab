import Foundation
import AVFoundation

enum DownloadError: LocalizedError {
    case httpStatus(Int)
    case invalidResponse
    case missingFile
    case taskCreationFailed

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "استجابة غير متوقعة من الخادم (HTTP \(code))"
        case .invalidResponse:     return "استجابة غير صالحة من الخادم"
        case .missingFile:         return "لم يتم العثور على الملف المُحمَّل"
        case .taskCreationFailed:  return "تعذّر إنشاء مهمة التحميل"
        }
    }
}

/// Handles both kinds of downloads:
///  - Direct video files (mp4 / m4v / mov / webm) via URLSession.
///  - HLS streams (.m3u8) via AVAssetDownloadURLSession, which downloads the
///    real video as a playable .movpkg package — the old build "downloaded"
///    the playlist text file and produced garbage.
/// DASH (.mpd) is rejected by the caller; AVFoundation cannot fetch it.
final class DownloadManager: NSObject {

    static let shared = DownloadManager()

    /// Posted on the main thread whenever a download completes successfully.
    static let didFinishNotification = Notification.Name("DownloadManagerDidFinish")

    /// Mobile Safari UA — many servers 403 anything that doesn't look like a browser.
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private var hlsHandlers: [Int: (Result<URL, Error>) -> Void] = [:]
    private var hlsTitles: [Int: String] = [:]
    private var hlsResults: [Int: Result<URL, Error>] = [:]

    private lazy var hlsSession: AVAssetDownloadURLSession = {
        AVAssetDownloadURLSession(configuration: .default,
                                  assetDownloadDelegate: self,
                                  delegateQueue: .main)
    }()

    private override init() {
        super.init()
    }

    var downloadsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Direct file download

    func downloadFile(url: URL, title: String, referer: URL?,
                      completion: @escaping (Result<URL, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        if let referer = referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }

        URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            func finish(_ result: Result<URL, Error>) {
                DispatchQueue.main.async {
                    if case .success = result {
                        NotificationCenter.default.post(name: Self.didFinishNotification, object: nil)
                    }
                    completion(result)
                }
            }

            if let error = error { finish(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else { finish(.failure(DownloadError.invalidResponse)); return }
            guard (200...299).contains(http.statusCode) else { finish(.failure(DownloadError.httpStatus(http.statusCode))); return }
            guard let tempURL = tempURL else { finish(.failure(DownloadError.missingFile)); return }

            do {
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension.lowercased()
                let dest = self.downloadsDirectory.appendingPathComponent(self.uniqueFileName(base: title, ext: ext))
                try FileManager.default.moveItem(at: tempURL, to: dest)
                finish(.success(dest))
            } catch {
                finish(.failure(error))
            }
        }.resume()
    }

    // MARK: - HLS download

    func downloadHLS(url: URL, title: String, referer: URL?,
                     completion: @escaping (Result<URL, Error>) -> Void) {
        var options: [String: Any]?
        var headers = ["User-Agent": Self.userAgent]
        if let referer = referer {
            headers["Referer"] = referer.absoluteString
        }
        options = ["AVURLAssetHTTPHeaderFieldsKey": headers]

        let asset = AVURLAsset(url: url)
        guard let task = hlsSession.makeAssetDownloadTask(asset: asset,
                                                          assetTitle: sanitized(title),
                                                          assetArtworkData: nil,
                                                          options: options) else {
            DispatchQueue.main.async { completion(.failure(DownloadError.taskCreationFailed)) }
            return
        }
        let id = task.taskIdentifier
        hlsTitles[id] = title
        hlsHandlers[id] = completion
        task.resume()
    }

    // MARK: - File naming helpers

    private func sanitized(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.controlCharacters)
            .union(.newlines)
        let cleaned = title.components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(cleaned.prefix(80))
        return trimmed.isEmpty ? "فيديو" : trimmed
    }

    private func uniqueFileName(base: String, ext: String) -> String {
        let name = sanitized(base)
        let fm = FileManager.default
        var candidate = "\(name).\(ext)"
        var index = 2
        while fm.fileExists(atPath: downloadsDirectory.appendingPathComponent(candidate).path) {
            candidate = "\(name) \(index).\(ext)"
            index += 1
        }
        return candidate
    }
}

// MARK: - AVAssetDownloadURLSessionDelegate

extension DownloadManager: AVAssetDownloadURLSessionDelegate {

    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let id = assetDownloadTask.taskIdentifier
        let title = hlsTitles[id] ?? "فيديو"
        let dest = downloadsDirectory.appendingPathComponent(uniqueFileName(base: title, ext: "movpkg"))
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            hlsResults[id] = .success(dest)
        } catch {
            hlsResults[id] = .failure(error)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let id = task.taskIdentifier
        guard let handler = hlsHandlers.removeValue(forKey: id) else { return }
        hlsTitles.removeValue(forKey: id)

        if let error = error {
            handler(.failure(error))
            hlsResults.removeValue(forKey: id)
            return
        }

        if let result = hlsResults.removeValue(forKey: id) {
            if case .success = result {
                NotificationCenter.default.post(name: Self.didFinishNotification, object: nil)
            }
            handler(result)
        } else {
            handler(.failure(DownloadError.missingFile))
        }
    }
}
