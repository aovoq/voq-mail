//
//  MessageList.swift
//  VoqMail
//
//  A list of message previews (sender, subject, snippet) with a bound selection.
//  Used by both the running three-pane mail layout and the reference demo views.
//

import SwiftUI

struct MessageList: View {
    let messages: [MailMessage]
    @Binding var selection: MailMessage.ID?
    /// Whether another page can be appended; shows the load-more footer when true.
    var canLoadMore: Bool = false
    /// True while the next page is being fetched (drives the footer spinner).
    var isLoadingMore: Bool = false
    /// Requests the next page (tapped, or auto-fired when the footer scrolls in).
    var onLoadMore: () -> Void = {}

    var body: some View {
        Group {
            if messages.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "tray")
            } else {
                List(selection: $selection) {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                            .tag(message.id)
                    }

                    if canLoadMore {
                        loadMoreFooter
                    }
                }
            }
        }
    }

    /// A footer that both auto-loads the next page when scrolled into view and
    /// offers an explicit tap, showing a spinner while the page is in flight.
    private var loadMoreFooter: some View {
        Button(action: onLoadMore) {
            HStack {
                Spacer()
                if isLoadingMore {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Load More").font(.callout)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoadingMore)
        .listRowSeparator(.hidden)
        .onAppear(perform: onLoadMore)
    }
}

private struct MessageRow: View {
    let message: MailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(message.sender)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(message.receivedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(message.subject)
                .fontWeight(message.isRead ? .regular : .semibold)
                .lineLimit(1)

            Text(message.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                // Reserve the dot's footprint (always, so read/unread don't
                // reflow) so the preview's trailing end never slides under it.
                .padding(.trailing, Metrics.unreadDotSize + Metrics.unreadDotInset * 2)
        }
        .padding(.vertical, 5)
        // Unread dot, tucked into the row's bottom-right corner. Faded out (not
        // removed) when read so the row's layout never shifts between states.
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: Metrics.unreadDotSize, height: Metrics.unreadDotSize)
                .padding(Metrics.unreadDotInset)
                .opacity(message.isRead ? 0 : 1)
                .accessibilityHidden(message.isRead)
                .accessibilityLabel("Unread")
        }
        .contentShape(Rectangle())
    }
}
