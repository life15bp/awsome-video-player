import Foundation
import AVFoundation
import Combine

final class PlayerViewModel: ObservableObject {
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var viewport = ViewportState()
    @Published private(set) var favorites: [FavoriteSnapshot] = []
    @Published private(set) var isPlaying = false
    /// タグタブでの表示順（永続化済み）。未登録タグは末尾に辞書順で追加される。
    @Published private(set) var tagOrder: [String] = []

    private let playbackService: PlaybackService
    private let favoriteService: FavoriteService
    private var cancellables = Set<AnyCancellable>()

    init(playbackService: PlaybackService, favoriteService: FavoriteService) {
        self.playbackService = playbackService
        self.favoriteService = favoriteService
        self.favorites = favoriteService.loadFavorites()
        self.tagOrder = favoriteService.loadTagOrder()

        playbackService.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func load(file: VideoFile) {
        currentFile = file
        playbackService.load(file: file)
        player = playbackService.player
        viewport = ViewportState()
        isPlaying = false
    }

    var favoritesForCurrentFile: [FavoriteSnapshot] {
        guard let currentFile else { return [] }
        return favorites
            .filter { $0.videoId == currentFile.id }
            .sorted { $0.timeSeconds < $1.timeSeconds }
    }

    var currentSeconds: Double {
        guard CMTIME_IS_NUMERIC(playbackService.currentTime) else { return 0 }
        return CMTimeGetSeconds(playbackService.currentTime)
    }

    var durationSeconds: Double {
        guard CMTIME_IS_NUMERIC(playbackService.duration) else { return 0 }
        return CMTimeGetSeconds(playbackService.duration)
    }

    var progress: Double {
        let duration = durationSeconds
        guard duration > 0 else { return 0 }
        return currentSeconds / duration
    }

    func seek(to progress: Double) {
        let duration = durationSeconds
        guard duration > 0 else { return }
        let seconds = duration * min(max(progress, 0), 1)
        playbackService.seek(to: seconds)
    }

    func play() {
        playbackService.play()
        isPlaying = true
    }

    func pause() {
        playbackService.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// お気に入りサムネイルから再生: 別動画の場合はロードしてからその時間へシークして再生
    func playSnapshot(_ snapshot: FavoriteSnapshot, video: VideoFile) {
        if currentFile?.id != video.id {
            load(file: video)
        }
        seek(to: snapshot)
        play()
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "00:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Viewport control

    func zoom(byScrollDelta deltaY: CGFloat) {
        // スクロール量をそのまま使うと変化が分かりにくいので、少し大きめに反映
        let sensitivity: CGFloat = -0.1
        let deltaScale = deltaY * sensitivity
        viewport.applyScale(delta: deltaScale)
    }

    func pan(by translation: CGSize) {
        viewport.applyPan(translation: translation)
    }

    func scrub(byHorizontalDelta deltaX: CGFloat) {
        let duration = durationSeconds
        guard duration > 0 else { return }

        let sensitivity: Double = 0.002
        let deltaSeconds = Double(deltaX) * sensitivity * duration
        let newSeconds = min(max(currentSeconds + deltaSeconds, 0), duration)
        playbackService.seek(to: newSeconds)
    }

    // MARK: - Favorites

    func addFavoriteAtCurrentTime() {
        guard let currentFile else { return }
        let seconds = currentSeconds
        let snapshot = FavoriteSnapshot(videoId: currentFile.id, timeSeconds: seconds)
        favorites.append(snapshot)
        favorites.sort { $0.timeSeconds < $1.timeSeconds }
        favoriteService.saveFavorites(favorites)
    }

    func seek(to snapshot: FavoriteSnapshot) {
        playbackService.seek(to: snapshot.timeSeconds)
    }

    func removeFavorite(_ snapshot: FavoriteSnapshot) {
        favorites.removeAll { $0.id == snapshot.id }
        favoriteService.saveFavorites(favorites)
    }

    // MARK: - Tags

    func addTag(_ tag: String, to snapshot: FavoriteSnapshot) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let index = favorites.firstIndex(where: { $0.id == snapshot.id }) else { return }
        if !favorites[index].tags.contains(trimmed) {
            favorites[index].tags.append(trimmed)
            favoriteService.saveFavorites(favorites)
            objectWillChange.send()
        }
    }

    func removeTag(_ tag: String, from snapshot: FavoriteSnapshot) {
        guard let index = favorites.firstIndex(where: { $0.id == snapshot.id }) else { return }
        favorites[index].tags.removeAll { $0 == tag }
        favoriteService.saveFavorites(favorites)
        objectWillChange.send()
    }

    /// 動画に紐づくタグ一覧（重複排除＋ソート）
    func tagsForVideo(_ video: VideoFile) -> [String] {
        let all = favorites
            .filter { $0.videoId == video.id }
            .flatMap { $0.tags }
        return Array(Set(all)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// お気に入りが1つ以上ある動画の videoId 一覧（タグタブ「お気に入り」フィルタ用）
    var videoIdsWithAtLeastOneFavorite: Set<UUID> {
        Set(favorites.map(\.videoId))
    }

    /// 指定タグが付いたお気に入りがある動画の videoId 一覧
    func videoIdsWithTag(_ tag: String) -> Set<UUID> {
        Set(favorites.filter { $0.tags.contains(tag) }.map(\.videoId))
    }

    /// 全お気に入りで使われているタグ一覧（重複排除・辞書順）
    var allTags: [String] {
        let tags = favorites.flatMap(\.tags)
        return Array(Set(tags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// タグタブ用の表示順。tagOrder をベースに、未登録タグは末尾に辞書順で追加。
    var orderedTagsForFilter: [String] {
        let used = allTags
        let ordered = tagOrder.filter { used.contains($0) }
        let rest = used.filter { !tagOrder.contains($0) }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return ordered + rest
    }

    /// タグの表示順を D&D で変更（orderedTagsForFilter 上のインデックス）
    func reorderTags(from sourceIndex: Int, to destinationIndex: Int) {
        var order = orderedTagsForFilter
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex <= order.count
        else { return }
        let item = order.remove(at: sourceIndex)
        let insertIndex = min(destinationIndex, order.count)
        order.insert(item, at: insertIndex)
        tagOrder = order
        favoriteService.saveTagOrder(tagOrder)
        objectWillChange.send()
    }

    // MARK: - お気に入り中のお気に入り（メインサムネイル）

    /// この動画でメインサムネイルに使うお気に入り（1本あたり1つまで）
    func primaryThumbnailSnapshot(for video: VideoFile) -> FavoriteSnapshot? {
        favorites.first { $0.videoId == video.id && $0.useAsVideoThumbnail }
    }

    /// メインサムネイルに使う時刻（未設定なら nil → デフォルトは先頭付近）
    func primaryThumbnailTime(for video: VideoFile) -> Double? {
        primaryThumbnailSnapshot(for: video)?.timeSeconds
    }

    /// 指定したお気に入りを「動画のメインサムネイル」に設定する（お気に入り中のお気に入り）。同一動画内でのみ切り替え、他動画には影響しない。
    func setAsMainThumbnail(_ snapshot: FavoriteSnapshot) {
        let videoId = snapshot.videoId
        for i in favorites.indices where favorites[i].videoId == videoId {
            favorites[i].useAsVideoThumbnail = (favorites[i].id == snapshot.id)
        }
        favoriteService.saveFavorites(favorites)
        objectWillChange.send()
    }

    /// 永続化済みのお気に入りをディスクから再読み込み（フォルダ切り替え後など表示の整合性用）
    func reloadFavoritesFromDisk() {
        favorites = favoriteService.loadFavorites()
        objectWillChange.send()
    }
}
