import Cocoa

func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}


protocol PathExporter {
    var currentPoint: CGPoint { get }

    func initialize() -> [String]
    func fill() -> [String]

    func move(to: CGPoint) -> [String]
    func line(to: CGPoint) -> [String]
    func horizontal(x: CGFloat) -> [String]
    func vertical(y: CGFloat) -> [String]
    func cubic(control1: CGPoint, control2: CGPoint, end: CGPoint) -> [String]
    func shorthandCurve(control: CGPoint, end: CGPoint) -> [String]

    func relativeMove(to: CGPoint) -> [String]
    func relativeLine(to: CGPoint) -> [String]
    func relativeHorizontal(dx: CGFloat) -> [String]
    func relativeVertical(dy: CGFloat) -> [String]
    func relativeCubic(control1: CGPoint, control2: CGPoint, end: CGPoint) -> [String]
    func relativeShorthandCurve(control: CGPoint, end: CGPoint) -> [String]

    func closePath() -> [String]
}

extension PathExporter {
    func pointRelativeToCurrentPoint(point: CGPoint) -> CGPoint {
        return CGPoint(x: currentPoint.x + point.x, y: currentPoint.y + point.y)
    }

    func xRelativeToCurrentPoint(x: CGFloat) -> CGFloat {
        return currentPoint.x + x
    }

    func yRelativeToCurrentPoint(y: CGFloat) -> CGFloat {
        return currentPoint.y + y
    }

    func exportPoint(_ point: CGPoint) -> String {
        return "CGPoint(x: \(point.x), y: \(point.y))"
    }
}

extension PathExporter {
    func horizontal(x: CGFloat) -> [String] {
        let point = CGPoint(x: x, y: yRelativeToCurrentPoint(y: 0))
        return line(to: point)
    }

    func vertical(y: CGFloat) -> [String] {
        let point = CGPoint(x: xRelativeToCurrentPoint(x: 0), y: y)
        return line(to: point)
    }

    func relativeMove(to point: CGPoint) -> [String] {
        let absolute = pointRelativeToCurrentPoint(point: point)
        return move(to: absolute)
    }

    func relativeLine(to point: CGPoint) -> [String] {
        let absolute = pointRelativeToCurrentPoint(point: point)
        return line(to: absolute)
    }

    func relativeHorizontal(dx: CGFloat) -> [String] {
        let x = xRelativeToCurrentPoint(x: dx)
        return horizontal(x: x)
    }

    func relativeVertical(dy: CGFloat) -> [String] {
        let y = yRelativeToCurrentPoint(y: dy)
        return vertical(y: y)
    }

    func relativeCubic(control1: CGPoint, control2: CGPoint, end: CGPoint) -> [String] {
        let absolute1 = pointRelativeToCurrentPoint(point: control1)
        let absolute2 = pointRelativeToCurrentPoint(point: control2)
        let absoluteEnd = pointRelativeToCurrentPoint(point: end)
        return cubic(control1: absolute1, control2: absolute2, end: absoluteEnd)
    }

    func relativeShorthandCurve(control: CGPoint, end: CGPoint) -> [String] {
        let absoluteControl = pointRelativeToCurrentPoint(point: control)
        let absoluteEnd = pointRelativeToCurrentPoint(point: end)
        return shorthandCurve(control: absoluteControl, end: absoluteEnd)
    }
}

class CGPathExporter: PathExporter {
    var currentPoint: CGPoint {
        return path.currentPoint
    }

    private let path = CGMutablePath()
    private var lastCmd = ""
    private var lastControlPoint = CGPoint.zero
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }

    func initialize() -> [String] {
        return ["let \(identifier) = CGMutablePath()"]
    }

    func fill() -> [String] {
        return ["context.addPath(\(identifier))"]
    }

    func move(to point: CGPoint) -> [String] {
        lastCmd = "move"
        path.move(to: point)
        return ["\(identifier).move(to: \(exportPoint(point)))"]
    }

    func line(to point: CGPoint) -> [String] {
        lastCmd = "line"
        path.addLine(to: point)
        return ["\(identifier).addLine(to: \(exportPoint(point)))"]
    }

    func cubic(control1: CGPoint, control2: CGPoint, end: CGPoint) -> [String] {
        lastCmd = "cubic"
        lastControlPoint = control2
        path.addCurve(to: end, control1: control1, control2: control2)
        return ["\(identifier).addCurve(to: \(exportPoint(end)), control1: \(exportPoint(control1)), control2: \(exportPoint(control2)))"]
    }

    func shorthandCurve(control control2: CGPoint, end: CGPoint) -> [String] {
        let previousControl = lastCmd == "cubic" ? lastControlPoint : currentPoint
        let control1 = currentPoint + (currentPoint - previousControl)
        return cubic(control1: control1, control2: control2, end: end)
    }

    func closePath() -> [String] {
        path.closeSubpath()
        return ["\(identifier).closeSubpath()"]
    }
}

func parsePoint(arguments: [CGFloat]) -> CGPoint {
    precondition(arguments.count == 2, "Arguments: \(arguments)")
    let x = arguments[0]
    let y = arguments[1]
    return CGPoint(x: x, y: y)
}

func parsePointPairs(arguments: [CGFloat], action: (CGPoint) -> [String]) -> [String] {
    precondition(arguments.count % 2 == 0)
    return stride(from: 0, to: arguments.count, by: 2)
        .map({
            return Array(arguments[$0...$0+1])
        })
        .map(parsePoint)
        .map(action)
        .reduce([], +)
}

func parseCubicArguments(arguments: [CGFloat]) -> (CGPoint, CGPoint, CGPoint) {
    precondition(arguments.count == 6)
    let control1 = CGPoint(x: arguments[0], y: arguments[1])
    let control2 = CGPoint(x: arguments[2], y: arguments[3])
    let endPoint = CGPoint(x: arguments[4], y: arguments[5])
    return (control1, control2, endPoint)
}

func parseShorthandArguments(arguments: [CGFloat]) -> (CGPoint, CGPoint) {
    precondition(arguments.count == 4)
    let control = CGPoint(x: arguments[0], y: arguments[1])
    let endPoint = CGPoint(x: arguments[2], y: arguments[3])
    return (control, endPoint)
}

func parseNumericArguments(string: String?) -> [CGFloat] {
    guard let string = string else { return [] }
    var result = [CGFloat]()
    let scanner = Scanner(string: string)
    var argument: Double = 0
    while scanner.scanDouble(&argument) {
        result.append(CGFloat(argument))
        scanner.scanCharacters(from: CharacterSet(charactersIn: " ,"), into: nil)
    }
    return result
}

func scanCommand(scanner: Scanner, exporter: PathExporter) -> [String] {
    let knownCommands = CharacterSet(charactersIn: "MmLlCcVvHhAaSsQqTtZz")
    var command: NSString? = ""
    var args: NSString? = ""
    guard scanner.scanCharacters(from: knownCommands, into: &command) else {
        return []
    }
    guard let cmdString = command else {
        return []
    }
    scanner.scanUpToCharacters(from: knownCommands, into: &args)
    let arguments = parseNumericArguments(string: args as String?)
    switch cmdString {
    case "M":
        return exporter.move(to: parsePoint(arguments: arguments))
    case "m":
        return exporter.relativeMove(to: parsePoint(arguments: arguments))
    case "L":
        return parsePointPairs(arguments: arguments, action: exporter.line)
    case "l":
        return parsePointPairs(arguments: arguments, action: exporter.relativeLine)
    case "H":
        return exporter.horizontal(x: arguments[0])
    case "h":
        return exporter.relativeHorizontal(dx: arguments[0])
    case "V":
        return exporter.vertical(y: arguments[0])
    case "v":
        return exporter.relativeVertical(dy: arguments[0])
    case "C":
        let (control1, control2, endPoint) = parseCubicArguments(arguments: arguments)
        return exporter.cubic(control1: control1, control2: control2, end: endPoint)
    case "c":
        let (control1, control2, endPoint) = parseCubicArguments(arguments: arguments)
        return exporter.relativeCubic(control1: control1, control2: control2, end: endPoint)
    case "S":
        let (control, end) = parseShorthandArguments(arguments: arguments)
        return exporter.shorthandCurve(control: control, end: end)
    case "s":
        let (control, end) = parseShorthandArguments(arguments: arguments)
        return exporter.relativeShorthandCurve(control: control, end: end)
    case "z","Z":
        return exporter.closePath()
    default:
        print("\(cmdString)(\(arguments))")
        return []
    }
}

func parsePath(path: String, id: String) -> [String] {
    var commands = [String]()
    let scanner = Scanner(string: path)
    let exporter = CGPathExporter(identifier: id)
    commands.append("// Path: \(path)")
    commands += exporter.initialize()
    while true {
        let command = scanCommand(scanner: scanner, exporter: exporter)
        guard !command.isEmpty else {
            break
        }
        commands += command
    }
    commands += exporter.fill()
    commands.append("")
    return commands
}

func parseRect(attributes: [String: String], id: String) -> [String] {
    guard let x = attributes["x"].flatMap(Double.init),
        let y = attributes["y"].flatMap(Double.init),
        let width = attributes["width"].flatMap(Double.init),
        let height = attributes["height"].flatMap(Double.init) else {
            preconditionFailure("Invalid rect: \(attributes)")
    }
    return [
        "// Rect: \(attributes)",
        "context.addRect(CGRect(x: \(x), y: \(y), width: \(width), height: \(height)))",
        ""
    ]
}

func parsePolygon(attributes: [String: String], id: String) -> [String] {
    guard let pointsString = attributes["points"] else {
        preconditionFailure("Invalid polygon: \(attributes)")
    }
    let points: [CGPoint] = pointsString
        .trimmingCharacters(in: .whitespaces)
        .components(separatedBy: .whitespaces)
        .map({
            return $0.components(separatedBy: ",")
            .flatMap(Double.init)
        })
        .map({ pair in
            precondition(pair.count == 2)
            return CGPoint(x: pair[0], y: pair[1])
        })

    guard let initialPoint = points.first else {
        // Possibly valid, but let's fail for debugging edge cases
        preconditionFailure("No points in polygon")
    }
    var commands = [String]()
    let exporter = CGPathExporter(identifier: id)
    commands += exporter.initialize()
    commands += exporter.move(to: initialPoint)
    for point in points.dropFirst() {
        commands += exporter.line(to: point)
    }
    commands += exporter.fill()
    return ["// Polygon: \(attributes)"] + commands + [""]
}

func tabulate(text: String) -> String {
    return String(repeating: " ", count: 4) + text
}

class SVGParser: NSObject {
    var commands: [String] = []
    var pathCounter = 1
    var rectCounter = 1

    func function(name: String) -> String {
        var output = [String]()

        output.append("func \(name)(context: CGContext) {")
        output += commands.map(tabulate)
        output.append("}")
        output.append("")

        return output.joined(separator: "\n")
    }
}

extension SVGParser: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "path":
            if let pathString = attributeDict["d"] {
                commands += parsePath(path: pathString, id: "path\(pathCounter)")
                pathCounter += 1
            }
        case "rect":
            commands += parseRect(attributes: attributeDict, id: "rect\(rectCounter)")
            rectCounter += 1
        case "polygon":
            commands += parsePolygon(attributes: attributeDict, id: "path\(pathCounter)")
            pathCounter += 1
        case "g":
            if let id = attributeDict["id"] {
                commands += [
                    "// Group ID: \(id)",
                    ""
                ]
            }
        default:
            break;
        }
    }
}

func usage() {
    let cmd = (CommandLine.arguments[0] as NSString).lastPathComponent
    print("Usage: \(cmd) icon_folder framework_name output_dir")
}

enum Exit: Int32 {
    case success = 0
    case invalidArguments

    static func with(_ code: Exit) -> Never {
        exit(code.rawValue)
    }
}

struct Arguments {
    let input_folder: String
    let framework_name: String
    let output_dir: String
}

func parse_argv(_ argv: [String]) -> Arguments {
    let arguments = argv.dropFirst()
    guard arguments.count == 3 else {
        usage()
        Exit.with(.invalidArguments)
    }

    return Arguments(input_folder: arguments[1],
                     framework_name: arguments[2],
                     output_dir: arguments[3])
}

func parseFile(url: URL, outputDir: String) throws -> String {
    let data = try! Data(contentsOf: url)
    let xmlParser = XMLParser(data: data)
    let parser = SVGParser()
    xmlParser.delegate = parser
    xmlParser.parse()
    let originalName = (url.lastPathComponent as NSString).deletingPathExtension
    let name = originalName.replacingOccurrences(of: "-", with: "").capitalized
    let function = parser.function(name: "draw\(name)")
    let outputFile = (outputDir as NSString).appendingPathComponent("\(originalName).png")

    let size = NSSize(width: 24, height: 24)
    var lines = [String]()
    lines.append("func render\(name)() {")
    lines.append("    let size = CGSize(width: \(size.width), height: \(size.height))")
    lines.append("    let colorSpace = CGColorSpaceCreateDeviceRGB()")
    lines.append("    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)")
    lines.append("    let context = CGContext(")
    lines.append("        data: nil,")
    lines.append("        width: Int(size.width),")
    lines.append("        height: Int(size.height),")
    lines.append("        bitsPerComponent: 8,")
    lines.append("        bytesPerRow: 0,")
    lines.append("        space: colorSpace,")
    lines.append("        bitmapInfo: bitmapInfo.rawValue)!")
    lines.append("    context.saveGState()")
    lines.append("    context.translateBy(x: 0, y: \(size.height))")
    lines.append("    context.scaleBy(x: 1, y: -1)")
    lines.append("    draw\(name)(context: context)")
    lines.append("    context.fillPath()")
    lines.append("    context.restoreGState()")
    lines.append("    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)")
    lines.append("    representation.size = size")
    lines.append("    let pngData = representation.representation(using: .PNG, properties: [:])!")
    lines.append("    try! pngData.write(to: URL(fileURLWithPath: \"\(outputFile)\"))")
    lines.append("}")
    lines.append("")
    lines.append("render\(name)()")
    lines.append("")

    return function + lines.joined(separator: "\n")
}

let arguments = parse_argv(CommandLine.arguments)

let fileManager = FileManager.default
try fileManager.createDirectory(atPath: arguments.output_dir, withIntermediateDirectories: true, attributes: nil)
var contents = [String]()
contents.append("import Cocoa")
contents.append("")
contents += try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: arguments.input_folder), includingPropertiesForKeys: nil, options: [])
    .filter({ $0.path.hasSuffix(".svg") })
    .map({ return try parseFile(url: $0, outputDir: arguments.output_dir) })

let render = contents.joined(separator: "\n\n")


let renderFile = URL(fileURLWithPath: arguments.output_dir, isDirectory: true).appendingPathComponent("render.swift")
try render.write(to: renderFile, atomically: true, encoding: .utf8)

Exit.with(.success)

