//
//  DetailPaneHeader.swift
//  VoqMail
//
//  The detail pane's top bar, shared by the mailbox view and the settings panel
//  so they render a byte-identical seam: a content row exactly `mailboxHeaderHeight`
//  tall, with a 1pt hairline attached *below* that height (not carved out of it).
//  Callers supply the icon, title, the leading padding (which slides the content
//  clear of the traffic lights while the sidebar is collapsed), and a trailing
//  accessory.
//

import SwiftUI

struct DetailPaneHeader<Trailing: View>: View {
    let systemImage: String
    let title: String
    var leadingPadding: CGFloat = Metrics.mailboxHeaderHorizontalPadding
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                trailing()
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, Metrics.mailboxHeaderHorizontalPadding)
            .frame(height: Metrics.mailboxHeaderHeight)

            // The 1pt border is attached *below* the content row rather than carved
            // out of it, so the content stays a full `mailboxHeaderHeight`.
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: Metrics.mailboxHeaderBorderWidth)
        }
    }
}
