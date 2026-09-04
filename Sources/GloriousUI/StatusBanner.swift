import SwiftUI

public struct StatusBanner: View {
  public init(message: String, detail: String? = nil) {
    self.message = message
    self.detail = detail
  }

  let message: String
  let detail: String?
  @State private var showingDetail = false

  public var body: some View {
    HStack(alignment: .top, spacing: 7) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 10))
        .foregroundStyle(Theme.danger)
        .padding(.top, 1)

      Text(message)
        .font(.system(size: 10))
        .foregroundStyle(Theme.danger)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)

      if detail != nil {
        Button {
          showingDetail.toggle()
        } label: {
          Image(systemName: "info.circle")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textDim)
        }
        .buttonStyle(.plain)
        .help(detail ?? "")
        .popover(isPresented: $showingDetail, arrowEdge: .top) {
          Text(detail ?? "")
            .font(.system(size: 11))
            .frame(width: 340)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
        }
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 7)
    .frame(maxWidth: 460, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: Theme.corner)
        .fill(Theme.danger.opacity(0.10))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.corner)
        .strokeBorder(Theme.danger.opacity(0.35), lineWidth: 1))
  }
}
