import Foundation
import AVFoundation
import AppKit

/// 動画ファイルからサムネイル画像を生成するサービス
/// 重たい処理なので NSCache で簡易キャッシュも行う。
final class ThumbnailService {
    static let shared = ThumbnailService()

    /// URL と時間（秒）を結合したキーでキャッシュ
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "awesomevideoplayer.thumbnail", qos: .userInitiated)

    func thumbnail(
        for url: URL,
        targetSize: CGSize = .init(width: 320, height: 180),
        completion: @escaping (NSImage?) -> Void
    ) {
        thumbnail(for: url, at: nil, targetSize: targetSize, completion: completion)
    }

    func thumbnail(
        for url: URL,
        at timeSeconds: Double?,
        targetSize: CGSize = .init(width: 320, height: 180),
        completion: @escaping (NSImage?) -> Void
    ) {
        let seconds = timeSeconds ?? 1
        // 時間は 0.1 秒単位に丸めてキーを安定させる
        let bucketed = (seconds * 10).rounded() / 10
        let key = "\(url.absoluteString)#t=\(bucketed)" as NSString

        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        queue.async { [weak self] in
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = targetSize
            let time = CMTime(seconds: seconds, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let image = NSImage(cgImage: cgImage, size: targetSize)
                self?.cache.setObject(image, forKey: key)

                DispatchQueue.main.async {
                    completion(image)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
