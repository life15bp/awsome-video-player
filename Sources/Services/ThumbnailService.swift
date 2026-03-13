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
        // キャッシュキーは要求した時刻をそのまま使う（丸めない）。近い時刻で別サムネイルの画像が表示されるズレを防ぐ
        let timeKey = String(format: "%.3f", seconds)
        let key = "\(url.absoluteString)#t=\(timeKey)" as NSString

        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        queue.async { [weak self] in
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = targetSize
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.requestedTimeToleranceAfter = .zero
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
