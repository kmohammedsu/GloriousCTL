import Foundation
import GloriousCore

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
  print(
    """
    usage: gloriousctl-capture <capture.json> [output.txt]

    Expects a Wireshark JSON packet dissection:
      File > Export Packet Dissections > As JSON

    Prints every HID feature-report transfer on reports 0x04 and 0x05, then
    reports which command bytes bracket a write and how a block the host writes
    differs from the one the device last handed out.
    """)
  exit(1)
}

let inputPath = arguments[1]
guard let data = FileManager.default.contents(atPath: inputPath) else {
  FileHandle.standardError.write(Data("cannot read \(inputPath)\n".utf8))
  exit(1)
}

do {
  let transfers = try CaptureAnalyzer.transfers(fromWiresharkJSON: data)
  let report = CaptureAnalyzer.report(transfers)
  print(report)
  if arguments.count > 2 {
    try report.write(
      to: URL(fileURLWithPath: arguments[2]),
      atomically: true, encoding: .utf8)
    print("\nwritten to \(arguments[2])")
  }
} catch {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  exit(1)
}
