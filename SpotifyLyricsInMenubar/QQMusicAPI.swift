import Foundation

// QQ音乐API数据结构
struct QQMusicSearch: Decodable {
    let code: Int
    let data: SearchData?

    struct SearchData: Decodable {
        let song: SongData
    }

    struct SongData: Decodable {
        let list: [Song]
        let totalnum: Int
    }

    struct Song: Decodable {
        let songmid: String
        let songname: String
        let singer: [Singer]
        let albumname: String
        let interval: Int // 歌曲时长（秒）
        let strMediaMid: String?
    }

    struct Singer: Decodable {
        let name: String
    }
}

// QQ音乐歌词数据结构
struct QQMusicLyrics: Decodable {
    let code: Int
    let retcode: Int?
    let subcode: Int?
    let lyric: String? // 歌词内容（使用nobase64=1时为纯文本）
    let trans: String? // 翻译歌词
}

// QQ音乐API辅助类
class QQMusicAPI {
    static let shared = QQMusicAPI()
    private let decoder = JSONDecoder()

    // QQ音乐API基础URL
    private let searchBaseURL = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp"
    private let lyricBaseURL = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"

    // 搜索歌曲
    func searchSong(track: String, artist: String? = nil, album: String? = nil) async throws -> QQMusicSearch.Song? {
        // 构建搜索关键词
        var keywords = track
        if let artist = artist {
            keywords += " \(artist)"
        }

        guard let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        // 构建搜索URL
        let searchURL = "\(searchBaseURL)?format=json&p=1&n=5&w=\(encodedKeywords)"

        guard let url = URL(string: searchURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        // 直接解析JSON，QQ音乐新版API已经返回纯JSON格式
        let searchResult: QQMusicSearch
        do {
            searchResult = try decoder.decode(QQMusicSearch.self, from: data)
        } catch {
            print("QQ Music: 解析搜索结果失败 - \(error)")
            return nil
        }

        // 返回最匹配的结果
        guard let songs = searchResult.data?.song.list, !songs.isEmpty else {
            return nil
        }

        // 如果有艺术家名，进行匹配度检查
        if let artist = artist {
            for song in songs {
                let songArtists = song.singer.map { $0.name }.joined(separator: ", ")
                if songArtists.contains(artist) || artist.contains(songArtists) ||
                   songArtists.distance(between: artist) > 0.7 {
                    return song
                }
            }
        }

        // 返回第一个结果
        return songs.first
    }

    // 获取歌词
    func fetchLyrics(songmid: String) async throws -> (lyrics: [LyricLine], source: String) {
        // Try with nobase64=1 first (returns plain text lyrics)
        var lyricURL = "\(lyricBaseURL)?songmid=\(songmid)&format=json&nobase64=1"

        guard let url = URL(string: lyricURL) else {
            return ([], "")
        }

        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Debug log the response
        if let httpResponse = response as? HTTPURLResponse {
            print("QQ Music lyrics API status: \(httpResponse.statusCode)")
        }

        // Log raw response for debugging
        if let rawString = String(data: data, encoding: .utf8) {
            print("QQ Music lyrics raw response: \(rawString)")
        }

        // 直接解析JSON响应
        var lyricString: String? = nil

        // Try parsing as JSON
        do {
            let lyricResult = try decoder.decode(QQMusicLyrics.self, from: data)

            // Check if we got an error code
            if lyricResult.code != 0 {
                print("QQ Music: API returned error code \(lyricResult.code)")
                return ([], "")
            }

            // With nobase64=1, lyrics should be in plain text
            if let plainLyrics = lyricResult.lyric {
                lyricString = plainLyrics
            } else {
                // If no plain lyrics, might need to decode base64
                print("QQ Music: No plain lyrics found, response might need base64 decoding")
                return ([], "")
            }
        } catch {
            print("QQ Music: 解析歌词失败 - \(error)")
            if let rawString = String(data: data, encoding: .utf8) {
                print("QQ Music raw response (first 200 chars): \(String(rawString.prefix(200)))")
            }

            // Try alternative encoding (GBK/GB18030)
            if lyricString == nil {
                let cfEncoding = CFStringEncodings.GB_18030_2000
                let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
                if let gbkString = String(data: data, encoding: String.Encoding(rawValue: encoding)) {
                    print("QQ Music: Trying GBK encoding")
                    lyricString = gbkString
                }
            }

            if lyricString == nil {
                return ([], "")
            }
        }

        guard let finalLyricString = lyricString else {
            return ([], "")
        }

        // 解析LRC格式歌词
        let lyrics = parseLRCLyrics(finalLyricString)

        return (lyrics, "QQ Music")
    }

    // 解析LRC格式歌词
    private func parseLRCLyrics(_ lrcString: String) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        let lines = lrcString.components(separatedBy: .newlines)

        let timeRegex = try? NSRegularExpression(pattern: "\\[([0-9]+):([0-9]+)\\.([0-9]+)\\]", options: [])

        for line in lines {
            guard let timeRegex = timeRegex else { continue }

            let nsLine = line as NSString
            let matches = timeRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))

            for match in matches {
                if match.numberOfRanges == 4 {
                    let minutesString = nsLine.substring(with: match.range(at: 1))
                    let secondsString = nsLine.substring(with: match.range(at: 2))
                    let millisecondsString = nsLine.substring(with: match.range(at: 3))

                    if let minutes = Int(minutesString),
                       let seconds = Int(secondsString),
                       let milliseconds = Int(millisecondsString) {

                        let totalMilliseconds = (minutes * 60 + seconds) * 1000 + milliseconds * 10

                        // 提取歌词文本
                        let lyricStartIndex = match.range.location + match.range.length
                        if lyricStartIndex < nsLine.length {
                            let lyricText = nsLine.substring(from: lyricStartIndex).trimmingCharacters(in: .whitespaces)

                            if !lyricText.isEmpty {
                                let lyricLine = LyricLine(startTime: Double(totalMilliseconds), words: lyricText)
                                lyrics.append(lyricLine)
                            }
                        }
                    }
                }
            }
        }

        // 按时间排序
        lyrics.sort { $0.startTimeMS < $1.startTimeMS }

        return lyrics
    }
}
