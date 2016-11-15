import Foundation

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

    return Arguments(input_folder: arguments[0],
                     framework_name: arguments[1],
                     output_dir: arguments[2])
}

let arguments = parse_argv(CommandLine.arguments)

Exit.with(.success)

