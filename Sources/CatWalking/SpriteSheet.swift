import AppKit
import Foundation

enum SpriteSequence: String, CaseIterable, Codable {
    case walkDown
    case walkRight
    case walkUp
    case walkLeft
    case idle
    case groom
    case layDown
    case sleep
    case extraTwo
}

enum SpriteSheetRowOrder {
    case topToBottom
    case bottomToTop
}

extension SpriteSheetRowOrder: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "topToBottom":
            self = .topToBottom
        case "bottomToTop":
            self = .bottomToTop
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported rowOrder: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .topToBottom:
            try container.encode("topToBottom")
        case .bottomToTop:
            try container.encode("bottomToTop")
        }
    }
}

struct SpriteSequenceSelection {
    let row: Int
    let startColumn: Int
    let endColumn: Int?

    init(row: Int, startColumn: Int = 0, endColumn: Int? = nil) {
        self.row = row
        self.startColumn = startColumn
        self.endColumn = endColumn
    }

    func slice(frames: [NSImage]) -> [NSImage] {
        guard !frames.isEmpty else {
            return []
        }

        let lowerBound = min(max(0, startColumn), frames.count - 1)
        let upperBound = min(max(endColumn ?? (frames.count - 1), lowerBound), frames.count - 1)
        return Array(frames[lowerBound ... upperBound])
    }
}

extension SpriteSequenceSelection: Codable {
    enum CodingKeys: String, CodingKey {
        case row
        case startColumn
        case endColumn
    }

    init(from decoder: Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer(),
           let row = try? singleValueContainer.decode(Int.self) {
            self.init(row: row)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            row: try container.decode(Int.self, forKey: .row),
            startColumn: try container.decodeIfPresent(Int.self, forKey: .startColumn) ?? 0,
            endColumn: try container.decodeIfPresent(Int.self, forKey: .endColumn)
        )
    }

    func encode(to encoder: Encoder) throws {
        if startColumn == 0, endColumn == nil {
            var singleValueContainer = encoder.singleValueContainer()
            try singleValueContainer.encode(row)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(row, forKey: .row)
        try container.encode(startColumn, forKey: .startColumn)
        try container.encodeIfPresent(endColumn, forKey: .endColumn)
    }
}

struct SpriteSheetAnimationMapping {
    private let selections: [SpriteSequence: SpriteSequenceSelection]

    init(selections: [SpriteSequence: SpriteSequenceSelection]) {
        self.selections = selections
    }

    static let `default` = SpriteSheetAnimationMapping(
        selections: [
            .walkDown: SpriteSequenceSelection(row: 0),
            .walkRight: SpriteSequenceSelection(row: 1),
            .walkUp: SpriteSequenceSelection(row: 2),
            .walkLeft: SpriteSequenceSelection(row: 3),
            .idle: SpriteSequenceSelection(row: 4),
            .groom: SpriteSequenceSelection(row: 5)
        ]
    )

    func selection(for sequence: SpriteSequence) -> SpriteSequenceSelection? {
        selections[sequence]
    }
}

extension SpriteSheetAnimationMapping: Codable {
    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var selections: [SpriteSequence: SpriteSequenceSelection] = [:]

        for key in container.allKeys {
            guard let sequence = SpriteSequence(rawValue: key.stringValue) else {
                continue
            }

            if let selection = try? container.decode(SpriteSequenceSelection.self, forKey: key) {
                selections[sequence] = selection
            }
        }

        self.init(selections: selections)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for sequence in SpriteSequence.allCases {
            guard let selection = selections[sequence],
                  let key = DynamicCodingKey(stringValue: sequence.rawValue)
            else {
                continue
            }

            try container.encode(selection, forKey: key)
        }
    }
}

struct SpriteSheetConfiguration {
    let rows: Int
    let columns: Int
    let rowOrder: SpriteSheetRowOrder
    let animationMapping: SpriteSheetAnimationMapping

    static let `default` = SpriteSheetConfiguration(
        rows: 6,
        columns: 4,
        rowOrder: .topToBottom,
        animationMapping: .default
    )
}

extension SpriteSheetConfiguration: Codable {}

struct SpriteSheet {
    static let defaultTemplateSelection = ""

    let configuration: SpriteSheetConfiguration
    let framesByRow: [[NSImage]]
    let frameSize: CGSize

    private struct TrimmedFrame {
        let cgImage: CGImage
        let size: CGSize
    }

    func frames(for sequence: SpriteSequence) -> [NSImage] {
        guard let selection = configuration.animationMapping.selection(for: sequence),
              framesByRow.indices.contains(selection.row)
        else {
            return []
        }

        return selection.slice(frames: framesByRow[selection.row])
    }

    static func load(
        named preferredNames: [String] = ["cat-sprite-sheet", "CatSpriteSheet", "sprite-sheet"],
        configuration: SpriteSheetConfiguration = .default
    ) -> SpriteSheet {
        for name in preferredNames {
            if let spriteSheet = loadImage(named: name, fallbackConfiguration: configuration) {
                return spriteSheet
            }
        }

        for fallbackName in bundledImageNames() {
            if let spriteSheet = loadImage(named: fallbackName, fallbackConfiguration: configuration) {
                return spriteSheet
            }
        }

        return placeholder(configuration: configuration)
    }

    static func load(templateName: String, configuration: SpriteSheetConfiguration = .default) -> SpriteSheet {
        let trimmedTemplateName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTemplateName.isEmpty {
            return load(configuration: configuration)
        }

        return load(named: [trimmedTemplateName], configuration: configuration)
    }

    static func availableTemplateNames() -> [String] {
        bundledImageNames()
    }

    static func displayName(for templateName: String) -> String {
        let trimmedTemplateName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTemplateName.isEmpty else {
            return "Automatic"
        }

        return trimmedTemplateName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
    }

    private static func loadImage(named name: String, fallbackConfiguration: SpriteSheetConfiguration) -> SpriteSheet? {
        guard let url = resourceURL(named: name),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let configuration = loadConfiguration(named: name) ?? fallbackConfiguration

        guard let frameRects = detectedFrameRects(in: cgImage, configuration: configuration)
            ?? evenlyDividedFrameRects(in: cgImage, configuration: configuration)
        else {
            return nil
        }

        let trimmedFramesByRow = frameRects.map { rowRects in
            rowRects.compactMap { cropRect in
                trimmedFrame(from: cgImage, cropRect: cropRect)
            }
        }

        let maxFrameWidth = frameRects
            .flatMap { $0 }
            .map { Int($0.width) }
            .max() ?? 0
        let maxFrameHeight = frameRects
            .flatMap { $0 }
            .map { Int($0.height) }
            .max() ?? 0

        guard maxFrameWidth > 0, maxFrameHeight > 0 else {
            return nil
        }

        var framesByRow: [[NSImage]] = []

        for trimmedRow in trimmedFramesByRow {
            var renderedRow: [NSImage] = []
            for trimmedFrame in trimmedRow {
                guard let frameImage = paddedFrameImage(
                    trimmedFrame: trimmedFrame,
                    canvasSize: CGSize(width: maxFrameWidth, height: maxFrameHeight)
                ) else {
                    continue
                }
                renderedRow.append(frameImage)
            }
            framesByRow.append(renderedRow)
        }

        return SpriteSheet(
            configuration: configuration,
            framesByRow: framesByRow,
            frameSize: CGSize(width: maxFrameWidth, height: maxFrameHeight)
        )
    }

    private static func resourceURL(named name: String) -> URL? {
        let candidateNames = [name, "\(name).png", "\(name).jpg", "\(name).jpeg"]

        for candidate in candidateNames {
            let nsName = candidate as NSString
            let baseName = nsName.deletingPathExtension
            let ext = nsName.pathExtension.isEmpty ? nil : nsName.pathExtension
            if let url = Bundle.module.url(forResource: baseName, withExtension: ext) {
                return url
            }
        }

        return nil
    }

    private static func loadConfiguration(named name: String) -> SpriteSheetConfiguration? {
        guard let url = configurationURL(named: name) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SpriteSheetConfiguration.self, from: data)
        } catch {
            NSLog("Failed to load sprite configuration for %@: %@", name, error.localizedDescription)
            return nil
        }
    }

    private static func configurationURL(named name: String) -> URL? {
        let candidateNames = [name, "\(name).json"]

        for candidate in candidateNames {
            let nsName = candidate as NSString
            let baseName = nsName.deletingPathExtension
            let ext = nsName.pathExtension.isEmpty ? "json" : nsName.pathExtension
            if let url = Bundle.module.url(forResource: baseName, withExtension: ext) {
                return url
            }
        }

        return nil
    }

    private static func frameOriginY(
        for row: Int,
        frameHeight: Int,
        configuration: SpriteSheetConfiguration
    ) -> Int {
        switch configuration.rowOrder {
        case .topToBottom:
            return row * frameHeight
        case .bottomToTop:
            return (configuration.rows - 1 - row) * frameHeight
        }
    }

    private static func evenlyDividedFrameRects(
        in cgImage: CGImage,
        configuration: SpriteSheetConfiguration
    ) -> [[CGRect]]? {
        let frameWidth = cgImage.width / configuration.columns
        let frameHeight = cgImage.height / configuration.rows

        guard frameWidth > 0, frameHeight > 0 else {
            return nil
        }

        return (0 ..< configuration.rows).map { row in
            (0 ..< configuration.columns).map { column in
                CGRect(
                    x: column * frameWidth,
                    y: frameOriginY(for: row, frameHeight: frameHeight, configuration: configuration),
                    width: frameWidth,
                    height: frameHeight
                )
            }
        }
    }

    private static func detectedFrameRects(
        in cgImage: CGImage,
        configuration: SpriteSheetConfiguration
    ) -> [[CGRect]]? {
        guard let occupancy = occupancyMap(for: cgImage) else {
            return nil
        }

        let xRanges = contiguousRanges(from: occupancy.columns)
        let yRanges = contiguousRanges(from: occupancy.rows)

        guard xRanges.count == configuration.columns,
              yRanges.count == configuration.rows
        else {
            return nil
        }

        let xBoundaries = cellBoundaries(from: xRanges, totalLength: cgImage.width)
        let yBoundaries = cellBoundaries(from: yRanges, totalLength: cgImage.height)

        let rowIndices: [Int]
        switch configuration.rowOrder {
        case .topToBottom:
            rowIndices = Array(0 ..< configuration.rows)
        case .bottomToTop:
            rowIndices = Array((0 ..< configuration.rows).reversed())
        }

        return rowIndices.map { rowIndex in
            (0 ..< configuration.columns).map { columnIndex in
                CGRect(
                    x: xBoundaries[columnIndex],
                    y: yBoundaries[rowIndex],
                    width: xBoundaries[columnIndex + 1] - xBoundaries[columnIndex],
                    height: yBoundaries[rowIndex + 1] - yBoundaries[rowIndex]
                )
            }
        }
    }

    private static func occupancyMap(for cgImage: CGImage) -> (columns: [Bool], rows: [Bool])? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var occupiedColumns = [Bool](repeating: false, count: width)
        var occupiedRows = [Bool](repeating: false, count: height)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * 4
                let alpha = pixels[offset + 3]
                if alpha > 12 {
                    occupiedColumns[x] = true
                    occupiedRows[y] = true
                }
            }
        }

        return (occupiedColumns, occupiedRows)
    }

    private static func contiguousRanges(from occupied: [Bool]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var rangeStart: Int?

        for (index, isOccupied) in occupied.enumerated() {
            if isOccupied {
                rangeStart = rangeStart ?? index
                continue
            }

            if let start = rangeStart {
                ranges.append(start ..< index)
                rangeStart = nil
            }
        }

        if let start = rangeStart {
            ranges.append(start ..< occupied.count)
        }

        return ranges
    }

    private static func cellBoundaries(from ranges: [Range<Int>], totalLength: Int) -> [Int] {
        guard !ranges.isEmpty else {
            return [0, totalLength]
        }

        var boundaries = [0]

        for index in 1 ..< ranges.count {
            let previousUpper = ranges[index - 1].upperBound
            let nextLower = ranges[index].lowerBound
            boundaries.append((previousUpper + nextLower) / 2)
        }

        boundaries.append(totalLength)
        return boundaries
    }

    private static func paddedFrameImage(
        trimmedFrame: TrimmedFrame,
        canvasSize: CGSize
    ) -> NSImage? {
        let image = NSImage(size: canvasSize)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

        let destinationRect = CGRect(
            x: (canvasSize.width - trimmedFrame.size.width) / 2,
            y: 0,
            width: trimmedFrame.size.width,
            height: trimmedFrame.size.height
        )

        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: trimmedFrame.cgImage, size: trimmedFrame.size)
            .draw(in: destinationRect)

        image.unlockFocus()
        return image
    }

    private static func trimmedFrame(from cgImage: CGImage, cropRect: CGRect) -> TrimmedFrame? {
        let integralRect = CGRect(
            x: Int(cropRect.origin.x),
            y: Int(cropRect.origin.y),
            width: Int(cropRect.size.width),
            height: Int(cropRect.size.height)
        )

        guard let cropped = cgImage.cropping(to: integralRect) else {
            return nil
        }

        guard let opaqueBounds = opaqueBounds(in: cropped),
              let trimmedImage = cropped.cropping(to: opaqueBounds)
        else {
            return TrimmedFrame(cgImage: cropped, size: integralRect.size)
        }

        return TrimmedFrame(
            cgImage: trimmedImage,
            size: CGSize(width: opaqueBounds.width, height: opaqueBounds.height)
        )
    }

    private static func opaqueBounds(in cgImage: CGImage) -> CGRect? {
        guard let occupancy = occupancyMap(for: cgImage) else {
            return nil
        }

        let xRanges = contiguousRanges(from: occupancy.columns)
        let yRanges = contiguousRanges(from: occupancy.rows)

        guard let xRange = xRanges.first,
              let yRange = yRanges.first
        else {
            return nil
        }

        return CGRect(
            x: xRange.lowerBound,
            y: yRange.lowerBound,
            width: xRange.upperBound - xRange.lowerBound,
            height: yRange.upperBound - yRange.lowerBound
        )
    }

    private static func bundledImageNames() -> [String] {
        guard let resourceURL = Bundle.module.resourceURL,
              let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)
        else {
            return []
        }

        var entries: [(baseName: String, priority: Int)] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg"].contains(ext) else {
                continue
            }

            let priority: Int
            switch ext {
            case "png":
                priority = 0
            case "jpg", "jpeg":
                priority = 1
            default:
                priority = 2
            }

            entries.append((fileURL.deletingPathExtension().lastPathComponent, priority))
        }

        return entries
            .sorted {
                if $0.priority == $1.priority {
                    return $0.baseName.localizedStandardCompare($1.baseName) == .orderedAscending
                }
                return $0.priority < $1.priority
            }
            .map(\ .baseName)
    }

    private static func placeholder(configuration: SpriteSheetConfiguration) -> SpriteSheet {
        let frameSize = CGSize(width: 32, height: 32)
        let rowColors: [NSColor] = [
            .systemOrange,
            .systemBlue,
            .systemGreen,
            .systemPink,
            .systemYellow,
            .systemTeal
        ]

        let framesByRow = (0 ..< configuration.rows).map { row in
            (0 ..< configuration.columns).map { column in
                placeholderFrame(
                    size: frameSize,
                    color: rowColors[row % rowColors.count],
                    label: "\(row + 1)-\(column + 1)"
                )
            }
        }

        return SpriteSheet(
            configuration: configuration,
            framesByRow: framesByRow,
            frameSize: frameSize
        )
    }

    private static func placeholderFrame(size: CGSize, color: NSColor, label: String) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        let outerRect = CGRect(origin: .zero, size: size)
        let innerRect = outerRect.insetBy(dx: 2, dy: 2)

        color.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: innerRect, xRadius: 5, yRadius: 5).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: label, attributes: attributes)
        let textRect = CGRect(x: 4, y: size.height / 2 - 4, width: size.width - 8, height: 8)
        attributed.draw(in: textRect)

        image.unlockFocus()
        return image
    }
}
