import AppKit
import Foundation

enum SpriteSequence: CaseIterable {
    case walkDown
    case walkRight
    case walkUp
    case walkLeft
    case idle
    case groom
}

enum SpriteSheetRowOrder {
    case topToBottom
    case bottomToTop
}

struct SpriteSheetAnimationMapping {
    let walkDownRow: Int
    let walkRightRow: Int
    let walkUpRow: Int
    let walkLeftRow: Int
    let idleRow: Int
    let groomRow: Int

    static let `default` = SpriteSheetAnimationMapping(
        walkDownRow: 0,
        walkRightRow: 1,
        walkUpRow: 2,
        walkLeftRow: 3,
        idleRow: 4,
        groomRow: 5
    )

    func rowIndex(for sequence: SpriteSequence) -> Int {
        switch sequence {
        case .walkDown:
            return walkDownRow
        case .walkRight:
            return walkRightRow
        case .walkUp:
            return walkUpRow
        case .walkLeft:
            return walkLeftRow
        case .idle:
            return idleRow
        case .groom:
            return groomRow
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
        let rowIndex = configuration.animationMapping.rowIndex(for: sequence)
        guard framesByRow.indices.contains(rowIndex) else {
            return []
        }
        return framesByRow[rowIndex]
    }

    static func load(
        named preferredNames: [String] = ["cat-sprite-sheet", "CatSpriteSheet", "sprite-sheet"],
        configuration: SpriteSheetConfiguration = .default
    ) -> SpriteSheet {
        for name in preferredNames {
            if let spriteSheet = loadImage(named: name, configuration: configuration) {
                return spriteSheet
            }
        }

        for fallbackName in bundledImageNames() {
            if let spriteSheet = loadImage(named: fallbackName, configuration: configuration) {
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

    private static func loadImage(named name: String, configuration: SpriteSheetConfiguration) -> SpriteSheet? {
        guard let url = resourceURL(named: name),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

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
