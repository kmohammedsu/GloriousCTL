import AppKit
import GloriousCore
import GloriousUI
import SwiftUI

@MainActor
func renderPanel(to path: String) throws {
  let stages: [DPIStageTable.Stage] = [
    .init(id: 0, dpi: 400, color: .init(red: 255, green: 255, blue: 0)),
    .init(id: 1, dpi: 800, color: .init(red: 0, green: 0, blue: 255)),
    .init(id: 2, dpi: 1600, color: .init(red: 255, green: 0, blue: 0)),
    .init(id: 3, dpi: 3200, color: .init(red: 0, green: 255, blue: 0)),
    .init(id: 4, dpi: 5000, color: .init(red: 255, green: 0, blue: 255)),
    .init(id: 5, dpi: 10000, color: .init(red: 255, green: 255, blue: 255)),
  ]
  let view = DPIStageTable(
    stages: stages, enabledCount: 6, activeStage: 4,
    selectedStage: .constant(3)
  )
  .padding(14)
  .frame(width: 232)
  .background(Theme.panel)
  .padding(16)
  .background(Theme.background)

  let renderer = ImageRenderer(content: view)
  renderer.scale = 2
  renderer.isOpaque = true
  guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
  else {
    FileHandle.standardError.write(Data("render failed\n".utf8))
    exit(1)
  }
  try png.write(to: URL(fileURLWithPath: path))
  print("wrote \(path)")
}

@MainActor
func renderBanner(to path: String) throws {
  let view = VStack(alignment: .leading, spacing: 12) {
    StatusBanner(message: Messages.writeRejected, detail: Messages.writeRejectedDetail)
    StatusBanner(message: Messages.partialWrite(landed: 12, rejected: 3, collateral: 1))
    StatusBanner(message: HIDError.permissionDenied.localizedDescription)
  }
  .padding(18)
  .frame(width: 520, alignment: .leading)
  .background(Theme.background)

  let renderer = ImageRenderer(content: view)
  renderer.scale = 2
  renderer.isOpaque = true
  guard let image = renderer.nsImage,
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
  else {
    FileHandle.standardError.write(Data("render failed\n".utf8))
    exit(1)
  }
  try png.write(to: URL(fileURLWithPath: path))
  print("wrote \(path)")
}

@MainActor
func render(to path: String) throws {
  let view = ZStack {
    Theme.background
    MouseDiagram(
      actions: [
        .left: .mouseButton(.left), .right: .mouseButton(.right),
        .middle: .mouseButton(.middle),
        .back: .keyboard(modifiers: .leftControl, keyCode: 0x19),
        .forward: .keyboard(modifiers: .leftControl, keyCode: 0x06),
        .dpi: .dpiAction(.cycleUp),
      ],
      underglow: Color(red: 0.24, green: 0.55, blue: 1.0)
    )
    .padding(26)
  }
  .frame(width: 340, height: 500)

  let renderer = ImageRenderer(content: view)
  renderer.scale = 2
  renderer.isOpaque = true

  guard let image = renderer.nsImage,
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
  else {
    FileHandle.standardError.write(Data("render failed\n".utf8))
    exit(1)
  }
  try png.write(to: URL(fileURLWithPath: path))
  print("wrote \(path)")
}

@MainActor
func renderActionRing(to path: String) throws {
  let ring = ActionRingConfiguration.defaultConfiguration(for: .middle)
  guard let png = ActionRingPreviewRenderer.png(items: ring.items, selectedIndex: 2) else {
    FileHandle.standardError.write(Data("ring render failed\n".utf8))
    exit(1)
  }
  try png.write(to: URL(fileURLWithPath: path))
  print("wrote \(path)")
}

MainActor.assumeIsolated {
  let args = CommandLine.arguments
  let path = args.count > 1 ? args[1] : "mouse-preview.png"
  do {
    if args.contains("--banner") {
      try renderBanner(to: path)
    } else if args.contains("--panel") {
      try renderPanel(to: path)
    } else if args.contains("--ring") {
      try renderActionRing(to: path)
    } else {
      try render(to: path)
    }
  } catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
  }
}
