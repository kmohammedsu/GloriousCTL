import GloriousCore
import GloriousUI
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
  @EnvironmentObject private var controller: DeviceController
  @State private var showingExporter = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        readLengthBanner

        if let path = controller.diagnosticsPath {
          HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
              Text("Diagnostics written").font(.callout.weight(.medium))
              Text(path).font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            Button("Reveal") {
              NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.10)))
        }

        if let validator = controller.validator {
          confidenceHeader(validator)
          checksTable(validator)
        }

        snapshotSection

        if let config = controller.deviceConfig {
          hexDumpSection(config)
        }

        if !controller.interfaces.isEmpty {
          interfacesSection
        }
      }
      .padding(20)
    }
    .navigationTitle("Protocol Inspector")
    .toolbar {
      Button {
        controller.runReadDiagnostics()
      } label: {
        Label("Run Read Diagnostics", systemImage: "stethoscope")
      }
      .disabled(!controller.state.isConnected)
      .help("Try every config read strategy and write the results to a file")

      Button {
        showingExporter = true
      } label: {
        Label("Export Dump", systemImage: "square.and.arrow.up")
      }
      .disabled(controller.deviceConfig == nil)
    }
    .fileExporter(
      isPresented: $showingExporter,
      document: TextDocument(text: dumpText),
      contentType: .plainText,
      defaultFilename: "glorious-config-dump"
    ) { _ in }
  }

  @ViewBuilder
  private var readLengthBanner: some View {
    if controller.lastReadLength > 0 {
      let expected = ConfigBlock.allCases.reduce(0) { $0 + $1.length }
      let full = controller.lastReadLength >= expected
      HStack(spacing: 10) {
        Image(systemName: full ? "checkmark.circle.fill" : "info.circle.fill")
          .foregroundStyle(full ? .green : .blue)
        VStack(alignment: .leading, spacing: 2) {
          Text(
            "Device returned \(controller.lastReadLength) of \(expected) bytes "
              + "across \(ConfigBlock.allCases.count) blocks"
          )
          .font(.callout.weight(.medium))
          if !full {
            Text(
              """
              A short control read is legal on USB — the mouse sends only as much \
              as it has. Bytes beyond this point are shown as zero and are never \
              written back.
              """
            )
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer()
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill((full ? Color.green : Color.blue).opacity(0.10)))
    }
  }

  private var snapshotSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Snapshot & Diff").font(.headline)
      Text(
        """
        To identify an unmapped byte: take a snapshot, change one setting on the mouse \
        itself (pressing the DPI button changes the active stage), then diff. Any offset \
        that moved is that setting.
        """
      )
      .font(.caption).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack {
        Button("Take Snapshot") { controller.captureSnapshot() }
          .disabled(!controller.state.isConnected)
        Button("Diff Against Snapshot") { controller.diffAgainstSnapshot() }
          .disabled(controller.snapshot == nil)
        Button("Scan Blocks") { controller.scanForBlocks() }
          .disabled(!controller.state.isConnected)
          .help("Probe every latch command for config blocks this app does not know about")
        if let takenAt = controller.snapshotTakenAt {
          Text("baseline \(takenAt, format: .dateTime.hour().minute().second())")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
      }

      if let diff = controller.lastDiff {
        ScrollView(.horizontal) {
          Text(diff)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
        }
        .frame(maxHeight: 180)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05)))
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
  }

  private var dumpText: String {
    guard let config = controller.deviceConfig else { return "" }
    var text = ConfigBlock.allCases.map {
      "--- block 0x\(String($0.rawValue, radix: 16)) (\($0.displayName)) ---\n"
        + config.hexDump($0)
    }.joined(separator: "\n\n")
    if let validator = controller.validator {
      text += "\n\nValidation: \(validator.passedCount)/\(validator.checks.count)\n"
      for check in validator.checks {
        text += String(
          format: "[%@] 0x%03X %@ = %@ -> %@\n",
          check.passed ? "ok" : "WARN", check.offset,
          check.field, check.rawValue, check.interpretation)
      }
    }
    return text
  }

  private func confidenceHeader(_ validator: LayoutValidator) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Field decoding")
          .font(.headline)
        Spacer()
        Text("\(validator.passedCount) of \(validator.checks.count) plausible")
          .font(.callout).foregroundStyle(.secondary)
      }
      ProgressView(value: validator.confidence)
        .tint(validator.allPassed ? .green : .orange)
      Text(
        """
        Each check asks whether the byte at a mapped offset decodes to something the \
        hardware could actually mean. Warnings point at offsets that need correcting \
        in ConfigLayout.swift; they do not put the mouse at risk, because writes only \
        touch mapped bytes and every other byte is passed through unchanged.
        """
      )
      .font(.caption).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
  }

  private func checksTable(_ validator: LayoutValidator) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(validator.checks) { check in
        HStack(spacing: 12) {
          Image(
            systemName: check.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
          )
          .foregroundStyle(check.passed ? .green : .orange)
          Text(
            String(
              format: "%@ 0x%02X", check.block.displayName.prefix(3).uppercased() as NSString,
              check.offset)
          )
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .frame(width: 78, alignment: .leading)
          Text(check.field).frame(width: 150, alignment: .leading)
          Text(check.rawValue)
            .font(.system(.caption, design: .monospaced))
            .frame(width: 54, alignment: .leading)
          Text(check.interpretation).foregroundStyle(.secondary)
          Spacer()
          if let note = check.note {
            Text(note).font(.caption).foregroundStyle(.orange)
          }
        }
        .padding(.vertical, 5).padding(.horizontal, 12)
        .background(check.passed ? Color.clear : Color.orange.opacity(0.07))
        Divider()
      }
    }
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
  }

  private func hexDumpSection(_ config: MouseConfig) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Raw blocks — feature report 0x04, selected by command")
        .font(.headline)

      if controller.hasUnsavedChanges {
        ForEach(controller.pendingChanges, id: \.block) { change in
          Text(
            "\(change.block.displayName): "
              + change.offsets.prefix(12)
              .map { String(format: "0x%02X", $0) }
              .joined(separator: ", ")
          )
          .font(.caption).foregroundStyle(.orange)
        }
      }

      ForEach(ConfigBlock.allCases, id: \.self) { block in
        VStack(alignment: .leading, spacing: 5) {
          Text(
            "block 0x\(String(block.rawValue, radix: 16)) — \(block.displayName), \(block.length) bytes"
          )
          .font(.callout.weight(.medium))
          ScrollView(.horizontal) {
            Text(config.hexDump(block))
              .font(.system(size: 11, design: .monospaced))
              .textSelection(.enabled)
              .padding(12)
          }
          .frame(height: block == .settings ? 190 : 140)
          .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05)))
        }
      }
    }
  }

  private var interfacesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("HID interfaces").font(.headline)
      ForEach(controller.interfaces.indices, id: \.self) { index in
        let info = controller.interfaces[index]
        Text(
          String(
            format: "PID 0x%04X · usagePage 0x%02X · usage 0x%02X · feature %d · input %d",
            info.productID, info.usagePage, info.usage,
            info.maxFeatureReportSize, info.maxInputReportSize)
        )
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
  }
}

struct TextDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  var text: String

  init(text: String) { self.text = text }

  init(configuration: ReadConfiguration) throws {
    text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}
