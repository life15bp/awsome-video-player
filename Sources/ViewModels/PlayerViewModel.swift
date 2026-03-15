import Foundation
import AVFoundation
import AppKit
import Combine
import VLCKitSPM

final class PlayerViewModel: ObservableObject {
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var viewport = ViewportState()
    @Published private(set) var favorites: [FavoriteSnapshot] = []
    @Published private(set) var isPlaying = false
    /// MKV 用 VLC プレイヤー。nil でないときは再生・シークは VLC に委譲
    private(set) var vlcPlayer: VLCMediaPlayer?
    @Published private(set) var vlcCurrentSeconds: Double = 0
    @Published private(set) var vlcDurationSeconds: Double = 0
    private var vlcTimeObserver: NSObjectProtocol?
    /// タグタブでの表示順（永続化済み）。未登録タグは末尾に辞書順で追加される。
    @Published private(set) var tagOrder: [String] = []
    /// 動画本体に付けたタグ（videoId → タグ一覧）
    @Published private(set) var videoTagMap: [UUID: [String]] = [:]

    private let playbackService: PlaybackService
    private let favoriteService: FavoriteService
    private var cancellables = Set<AnyCancellable>()

    init(playbackService: PlaybackService, favoriteService: FavoriteService) {
        self.playbackService = playbackService
        self.favoriteService = favoriteService
        self.favorites = favoriteService.loadFavorites()
        self.tagOrder = favoriteService.loadTagOrder()
        self.videoTagMap = favoriteService.loadVideoTags()

        playbackService.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        playbackService.$playbackError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// VLC ビューからプレイヤーが準備できたときに呼ぶ（MKV 再生用）
    func setVLCPlayer(_ p: VLCMediaPlayer?) {
        if let observer = vlcTimeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        vlcTimeObserver = nil
        vlcPlayer?.stop()
        vlcPlayer = p
        vlcCurrentSeconds = 0
        vlcDurationSeconds = 0
        if p != nil {
            isPlaying = true
        }
        if let player = p {
            if let len = player.media?.length.value?.doubleValue, len > 0 {
                vlcDurationSeconds = len / 1000
            }
            vlcTimeObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("VLCMediaPlayerTimeChanged"),
                object: player,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let t = player.time.value?.doubleValue {
                    self.vlcCurrentSeconds = t / 1000
                }
                if self.vlcDurationSeconds <= 0, let len = player.media?.length.value?.doubleValue, len > 0 {
                    self.vlcDurationSeconds = len / 1000
                }
                self.objectWillChange.send()
            }
        }
        objectWillChange.send()
    }

    /// 再生失敗時のメッセージ（nil ならエラーなし）。Phase1: AVPlayer 失敗時。Phase2 で MKV 別エンジンに切り替える前提。
    var playbackError: String? {
        playbackService.playbackError
    }

    /// 現在のファイルをデフォルトのアプリ（VLC / IINA など）で開く。再生失敗時や MKV で利用。
    func openCurrentFileInDefaultApp() {
        guard let file = currentFile else { return }
        NSWorkspace.shared.open(file.url)
    }

    func load(file: VideoFile) {
        setVLCPlayer(nil)
        currentFile = file
        playbackService.load(file: file)
        player = playbackService.player
        viewport = ViewportState()
        isPlaying = false
        if player != nil {
            play()
        }
    }

    var favoritesForCurrentFile: [FavoriteSnapshot] {
        guard let currentFile else { return [] }
        return favorites
            .filter { $0.videoId == currentFile.id }
            .sorted { $0.timeSeconds < $1.timeSeconds }
    }

    var currentSeconds: Double {
        if vlcPlayer != nil { return vlcCurrentSeconds }
        guard CMTIME_IS_NUMERIC(playbackService.currentTime) else { return 0 }
        return CMTimeGetSeconds(playbackService.currentTime)
    }

    var durationSeconds: Double {
        if vlcPlayer != nil { return vlcDurationSeconds }
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
        if let vlc = vlcPlayer {
            vlc.time = VLCTime(number: NSNumber(value: Int(seconds * 1000)))
            return
        }
        playbackService.seek(to: seconds)
    }

    func play() {
        if let vlc = vlcPlayer {
            vlc.play()
            isPlaying = true
            return
        }
        playbackService.play()
        isPlaying = true
    }

    func pause() {
        if let vlc = vlcPlayer {
            vlc.pause()
            isPlaying = false
            return
        }
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

    /// スペースホールド用: 2倍速に切り替え（離したときに exitSpeedHold で元に戻す）
    func enterSpeedHold() {
        savedPlaybackRateForHold = playbackService.currentRate
        playbackService.setRate(2.0)
        isSpeedHoldActive = true
    }

    /// スペースホールド終了: 元の再生速度に戻す
    func exitSpeedHold() {
        playbackService.setRate(savedPlaybackRateForHold)
        isSpeedHoldActive = false
    }

    private(set) var isSpeedHoldActive = false
    private var savedPlaybackRateForHold: Float = 1.0
    private var spaceHoldWorkItem: DispatchWorkItem?

    /// スペース keyDown 時に View から呼ぶ（短押しなら後で keyUp でトグル、長押しなら 0.2s で 2倍速）
    func onSpaceKeyDown() {
        spaceHoldWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.enterSpeedHold()
        }
        spaceHoldWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            item.perform()
        }
    }

    /// スペース keyUp 時に View から呼ぶ（ホールド中なら元の速度に、短押しなら再生/一時停止トグル）
    func onSpaceKeyUp() {
        spaceHoldWorkItem?.cancel()
        spaceHoldWorkItem = nil
        if isSpeedHoldActive {
            exitSpeedHold()
        } else {
            togglePlayPause()
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

    /// 1コマ戻る（一時停止してからシーク）
    func stepBackwardFrame() {
        let duration = durationSeconds
        guard duration > 0 else { return }
        pause()
        let step = playbackService.frameDurationInSeconds
        let newSeconds = max(currentSeconds - step, 0)
        playbackService.seek(to: newSeconds)
    }

    /// 1コマ進む（一時停止してからシーク）
    func stepForwardFrame() {
        let duration = durationSeconds
        guard duration > 0 else { return }
        pause()
        let step = playbackService.frameDurationInSeconds
        let newSeconds = min(currentSeconds + step, duration)
        playbackService.seek(to: newSeconds)
    }

    /// 5秒戻る
    func stepBackward5Sec() {
        let duration = durationSeconds
        guard duration > 0 else { return }
        let newSeconds = max(currentSeconds - 5, 0)
        playbackService.seek(to: newSeconds)
    }

    /// 5秒進む
    func stepForward5Sec() {
        let duration = durationSeconds
        guard duration > 0 else { return }
        let newSeconds = min(currentSeconds + 5, duration)
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

    /// 指定動画に紐づくお気に入りをすべて削除（動画ファイル削除時に呼ぶ）
    func removeFavoritesForVideo(videoId: UUID) {
        favorites.removeAll { $0.videoId == videoId }
        favoriteService.saveFavorites(favorites)
        objectWillChange.send()
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

    /// 動画に紐づくタグ一覧（お気に入りスナップショット上のタグのみ。重複排除＋ソート）
    func tagsForVideo(_ video: VideoFile) -> [String] {
        let all = favorites
            .filter { $0.videoId == video.id }
            .flatMap { $0.tags }
        return Array(Set(all)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// 動画本体に付けたタグ一覧
    func videoTags(for video: VideoFile) -> [String] {
        (videoTagMap[video.id] ?? []).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// 動画にタグを追加（動画本体）
    func addVideoTag(_ tag: String, to video: VideoFile) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var tags = videoTagMap[video.id] ?? []
        guard !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tags.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        videoTagMap[video.id] = tags
        favoriteService.saveVideoTags(videoTagMap)
        objectWillChange.send()
    }

    /// 動画からタグを削除（動画本体）
    func removeVideoTag(_ tag: String, from video: VideoFile) {
        guard var tags = videoTagMap[video.id] else { return }
        tags.removeAll { $0 == tag }
        if tags.isEmpty {
            videoTagMap.removeValue(forKey: video.id)
        } else {
            videoTagMap[video.id] = tags
        }
        favoriteService.saveVideoTags(videoTagMap)
        objectWillChange.send()
    }

    /// 指定動画の動画タグをすべて削除（動画削除時に呼ぶ）
    func removeVideoTagsForVideo(videoId: UUID) {
        videoTagMap.removeValue(forKey: videoId)
        favoriteService.saveVideoTags(videoTagMap)
        objectWillChange.send()
    }

    /// お気に入りが1つ以上ある動画の videoId 一覧（タグタブ「お気に入り」フィルタ用）
    var videoIdsWithAtLeastOneFavorite: Set<UUID> {
        Set(favorites.map(\.videoId))
    }

    /// 指定タグが付いた動画の videoId 一覧（お気に入りタグ or 動画タグのどちらかで一致）
    func videoIdsWithTag(_ tag: String) -> Set<UUID> {
        let fromFavorites = Set(favorites.filter { $0.tags.contains(tag) }.map(\.videoId))
        let fromVideoTags = Set(videoTagMap.filter { $0.value.contains(tag) }.map(\.key))
        return fromFavorites.union(fromVideoTags)
    }

    /// 全タグ一覧（お気に入り＋動画本体。重複排除・辞書順）
    var allTags: [String] {
        let fromFavorites = favorites.flatMap(\.tags)
        let fromVideos = videoTagMap.flatMap(\.value)
        return Array(Set(fromFavorites + fromVideos)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
