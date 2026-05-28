// App/Sources/Views/Components/PaneHeader.swift

import SwiftUI

struct PaneHeader: View {
    let title: String
    let accent: String
    let subtitle: String
    var primary: (label: String, action: () -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                (Text(title) + Text(" ") + Text(accent).italic())
                    .font(PareFont.display(30))
                    .foregroundStyle(PareColor.ink)
                Text(subtitle)
                    .font(PareFont.body(13))
                    .foregroundStyle(PareColor.ink3)
            }
            Spacer()
            if let p = primary {
                Button(p.label, action: p.action)
                    .controlSize(.large)
            }
        }
        Divider()
    }
}
