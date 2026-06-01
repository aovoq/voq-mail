//
//  MailAttachment.swift
//  VoqMail
//
//  Metadata for a message attachment. The app can render a Quick Look preview
//  when `localFileURL` points to a downloaded file.
//

import Foundation

struct MailAttachment: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let byteCount: Int
    let contentType: String
    let localFileURL: URL?
}
