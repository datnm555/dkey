import Foundation

/// Một mục trong lịch sử clipboard: văn bản (kèm HTML nếu có) hoặc ảnh (lưu PNG ra file).
/// Ghim (pinned) thì luôn nằm trên đầu và không bị cắt/xoá khi dọn.
struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let isImage: Bool
    let text: String        // nội dung text, hoặc nhãn kiểu "Hình ảnh 1920×1080"
    let htmlText: String?   // nội dung HTML cho rich text
    let imageFile: String?  // tên file PNG (trong thư mục clipboard) cho mục ảnh
    let filePath: String?   // đường dẫn gốc của file ảnh được copy
    let filePaths: [String]? // đường dẫn gốc của các file được copy
    let date: Date          // thời điểm chụp
    let sourceApp: String?  // app đang giữ clipboard lúc chụp
    var pinned: Bool        // mục ghim ở trên đầu, sống sót qua trim/clear

    init(text: String, htmlText: String? = nil, source: String? = nil) {
        id = UUID(); isImage = false; self.text = text; self.htmlText = htmlText
        imageFile = nil; filePath = nil; filePaths = nil; date = Date(); sourceApp = source; pinned = false
    }

    init(imageFile: String, label: String, filePath: String? = nil, source: String? = nil) {
        id = UUID(); isImage = true; text = label; self.imageFile = imageFile; self.filePath = filePath
        filePaths = nil; date = Date(); sourceApp = source; htmlText = nil; pinned = false
    }

    init(id: UUID, isImage: Bool, text: String, htmlText: String?, imageFile: String?,
         filePath: String?, filePaths: [String]?, date: Date, sourceApp: String?, pinned: Bool = false) {
        self.id = id; self.isImage = isImage; self.text = text; self.htmlText = htmlText
        self.imageFile = imageFile; self.filePath = filePath; self.filePaths = filePaths
        self.date = date; self.sourceApp = sourceApp; self.pinned = pinned
    }

    // Decode tương thích ngược với dữ liệu lưu trước khi có các field mới.
    enum CodingKeys: String, CodingKey {
        case id, isImage, text, htmlText, imageFile, filePath, filePaths, date, sourceApp, pinned
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        isImage = try c.decode(Bool.self, forKey: .isImage)
        text = try c.decode(String.self, forKey: .text)
        htmlText = try c.decodeIfPresent(String.self, forKey: .htmlText)
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        filePath = try c.decodeIfPresent(String.self, forKey: .filePath)
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
}
