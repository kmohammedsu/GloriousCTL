import GloriousCore
import GloriousUI
import SwiftUI

// The action list runs to nearly forty entries. Presented as one flat menu it is
// taller than the window — and the window is a fixed size, so the menu spills off it
// and has to be scrolled blind. Categories become submenus instead: the top level
// stays at eight rows, and the largest submenu is nine, so nothing ever overflows.

/// A menu row that shows a checkmark when it is the current choice, matching how
/// macOS marks selection in a popup menu.
@ViewBuilder
func actionMenuItem(
  _ title: String, isSelected: Bool, action: @escaping () -> Void
) -> some View {
  Button(action: action) {
    if isSelected {
      Label(title, systemImage: "checkmark")
    } else {
      Text(title)
    }
  }
}

/// Chooses a plain `MacAction`, used where there are no custom (open / URL /
/// shortcut) choices to offer.
struct MacActionMenu: View {
  @Binding var selection: MacAction
  var width: CGFloat = 152

  var body: some View {
    Menu {
      actionMenuItem(MacAction.none.displayName, isSelected: selection == .none) {
        selection = .none
      }
      Divider()
      ForEach(MacAction.grouped(), id: \.category) { group in
        Menu {
          ForEach(group.actions, id: \.self) { action in
            actionMenuItem(action.displayName, isSelected: selection == action) {
              selection = action
            }
          }
        } label: {
          Label(group.category.rawValue, systemImage: group.category.symbolName)
        }
      }
    } label: {
      Text(selection.displayName)
        .font(.system(size: 10))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .controlSize(.small)
    .frame(width: width)
  }
}
