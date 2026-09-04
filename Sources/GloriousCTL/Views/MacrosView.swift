import GloriousCore
import GloriousUI
import SwiftUI

struct MacrosView: View {
  @EnvironmentObject private var controller: DeviceController
  @StateObject private var recorder = MacroRecorder()
  @State private var selection: Macro.ID?

  var body: some View {
    HSplitView {
      macroList
        .frame(minWidth: 210, idealWidth: 240, maxWidth: 320)
      macroDetail
        .frame(minWidth: 420, maxWidth: .infinity)
    }
    .navigationTitle("Macros")
    .onDisappear { recorder.stop() }
  }

  private var macroList: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        ForEach(controller.macros) { macro in
          VStack(alignment: .leading, spacing: 2) {
            Text(macro.name).font(.body.weight(.medium))
            Text("\(macro.events.count) events · \(macro.totalDurationMilliseconds) ms")
              .font(.caption).foregroundStyle(.secondary)
          }
          .tag(macro.id)
        }
        .onDelete { indexSet in
          controller.macros.remove(atOffsets: indexSet)
        }
      }

      Divider()

      HStack {
        Button {
          let slot = UInt8(controller.macros.count)
          let macro = Macro(name: "Macro \(controller.macros.count + 1)", slot: slot)
          controller.macros.append(macro)
          selection = macro.id
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
        .disabled(controller.macros.count >= 8)

        Button {
          if let selection,
            let index = controller.macros.firstIndex(where: { $0.id == selection })
          {
            controller.macros.remove(at: index)
          }
        } label: {
          Image(systemName: "minus")
        }
        .buttonStyle(.borderless)
        .disabled(selection == nil)

        Spacer()
      }
      .padding(.horizontal, 10).padding(.vertical, 7)
    }
  }

  @ViewBuilder
  private var macroDetail: some View {
    if let selection,
      let index = controller.macros.firstIndex(where: { $0.id == selection })
    {
      MacroEditor(macro: $controller.macros[index], recorder: recorder)
    } else {
      VStack(spacing: 10) {
        Image(systemName: "record.circle")
          .font(.system(size: 34)).foregroundStyle(.tertiary)
        Text("Select or create a macro").font(.headline)
        Text("Macros are saved with your profiles and can be bound to any button.")
          .font(.callout).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(40)
    }
  }
}

struct MacroEditor: View {
  @Binding var macro: Macro
  @ObservedObject var recorder: MacroRecorder

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        TextField("Macro name", text: $macro.name)
          .textFieldStyle(.roundedBorder)
          .font(.title3)

        HStack(spacing: 10) {
          Button {
            if recorder.isRecording {
              macro.events = recorder.finish()
            } else {
              recorder.start()
            }
          } label: {
            Label(
              recorder.isRecording ? "Stop Recording" : "Record",
              systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
          }
          .buttonStyle(.borderedProminent)
          .tint(recorder.isRecording ? .red : .accentColor)

          Button("Clear") { macro.events.removeAll() }
            .disabled(macro.events.isEmpty)

          Spacer()

          if recorder.isRecording {
            Label("\(recorder.events.count) captured", systemImage: "dot.radiowaves.left.and.right")
              .font(.callout).foregroundStyle(.red)
          }
        }

        if recorder.isRecording {
          Text(
            "Type now — keystrokes are captured until you press Stop. Recording needs Input Monitoring."
          )
          .font(.caption).foregroundStyle(.secondary)
        }

        if !macro.isWithinDeviceLimits {
          Label(
            "Longer than the mouse's \(Macro.maxEvents)-event bank; extra events will be dropped when written.",
            systemImage: "exclamationmark.triangle"
          )
          .font(.caption).foregroundStyle(.orange)
        }
      }
      .padding(16)

      Divider()

      Table(macro.events) {
        TableColumn("Step") { event in
          Text(event.displayName)
        }
        TableColumn("Delay") { event in
          Text("\(event.delayMilliseconds) ms")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

@MainActor
final class MacroRecorder: ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var events: [MacroEvent] = []

  private var monitor: Any?
  private var lastTimestamp: Date?

  func start() {
    events.removeAll()
    lastTimestamp = Date()
    isRecording = true
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      self?.capture(event)
      return nil
    }
  }

  @discardableResult
  func finish() -> [MacroEvent] {
    stop()
    return events
  }

  func stop() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    isRecording = false
  }

  private func capture(_ event: NSEvent) {
    let now = Date()
    let elapsed = lastTimestamp.map { now.timeIntervalSince($0) * 1000 } ?? 0
    lastTimestamp = now

    guard let usage = HIDUsageMapping.usage(forVirtualKeyCode: event.keyCode) else { return }
    events.append(
      MacroEvent(
        kind: event.type == .keyDown ? .keyDown : .keyUp,
        code: usage,
        delayMilliseconds: UInt16(min(max(elapsed, 0), 60000))))
  }
}

enum HIDUsageMapping {
  private static let table: [UInt16: UInt8] = [
    0x00: 0x04, 0x0B: 0x05, 0x08: 0x06, 0x02: 0x07, 0x0E: 0x08, 0x03: 0x09,
    0x05: 0x0A, 0x04: 0x0B, 0x22: 0x0C, 0x26: 0x0D, 0x28: 0x0E, 0x25: 0x0F,
    0x2E: 0x10, 0x2D: 0x11, 0x1F: 0x12, 0x23: 0x13, 0x0C: 0x14, 0x0F: 0x15,
    0x01: 0x16, 0x11: 0x17, 0x20: 0x18, 0x09: 0x19, 0x0D: 0x1A, 0x07: 0x1B,
    0x10: 0x1C, 0x06: 0x1D,
    0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21, 0x17: 0x22, 0x16: 0x23,
    0x1A: 0x24, 0x1C: 0x25, 0x19: 0x26, 0x1D: 0x27,
    0x24: 0x28, 0x35: 0x29, 0x33: 0x2A, 0x30: 0x2B, 0x31: 0x2C,
    0x1B: 0x2D, 0x18: 0x2E, 0x21: 0x2F, 0x1E: 0x30, 0x2A: 0x31,
    0x29: 0x33, 0x27: 0x34, 0x32: 0x35, 0x2B: 0x36, 0x2F: 0x37, 0x2C: 0x38,
    0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D, 0x60: 0x3E, 0x61: 0x3F,
    0x62: 0x40, 0x64: 0x41, 0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45,
    0x73: 0x4A, 0x74: 0x4B, 0x77: 0x4D, 0x79: 0x4E,
    0x7C: 0x4F, 0x7B: 0x50, 0x7D: 0x51, 0x7E: 0x52,
  ]

  static func usage(forVirtualKeyCode code: UInt16) -> UInt8? { table[code] }
}
