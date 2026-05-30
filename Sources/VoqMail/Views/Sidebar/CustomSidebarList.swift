//
//  CustomSidebarList.swift
//  VoqMail
//
//  The scrollable list of mailboxes in the sidebar. Tapping a row updates the
//  bound selection. Built from a ScrollView + plain buttons (rather than a native
//  List) so the rows and the custom split-view background can be styled freely.
//

import SwiftUI

struct CustomSidebarList: View {
    @Binding var selection: Mailbox.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mailboxes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    // Extra top padding clears the window's traffic-light buttons.
                    .padding(.top, Metrics.sidebarHeaderTopPadding)
                    .padding(.bottom, 6)

                ForEach(Mailbox.samples) { mailbox in
                    Button {
                        selection = mailbox.id
                    } label: {
                        CustomSidebarRow(mailbox: mailbox, isSelected: selection == mailbox.id)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container, edges: .top)
    }
}
