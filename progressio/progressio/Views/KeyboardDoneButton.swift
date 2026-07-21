import SwiftUI
import UIKit

extension View {
    /// Adds a keyboard accessory "Done" button that resigns first responder.
    /// Safe to chain alongside other `.toolbar` modifiers — SwiftUI merges them.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }
}
