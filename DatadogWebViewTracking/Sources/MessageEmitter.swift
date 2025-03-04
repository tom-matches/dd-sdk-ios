/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import DatadogInternal

/// Datadog implementation of `MessageEmitter`.
internal final class MessageEmitter: InternalExtension<WebViewTracking>.AbstractMessageEmitter {
    enum MessageKeys {
        static let browserLog = "browser-log"
        static let browserRUMEvent = "browser-rum-event"
    }

    private weak var core: DatadogCoreProtocol?

    init(core: DatadogCoreProtocol) {
        self.core = core
    }

    /// Sends a bag of data to the message bus
    /// - Parameter body: The data to send, it must be parsable to `WebViewMessage`
    override func send(body: Any) throws {
        let message = try WebViewMessage(body: body)
        try send(message: message)
    }

    /// Sends a message to the message bus
    /// - Parameter message: The message to send
    func send(message: WebViewMessage) throws {
        if core == nil {
            DD.logger.debug("Core must not be nil when using WebViewTracking")
        }
        switch message {
        case let .log(event):
            core?.send(message: .custom(key: MessageKeys.browserLog, baggage: .init(event)), else: {
                DD.logger.warn("A WebView log is lost because Logging is disabled in the SDK")
            })
        case let .rum(event):
            core?.send(message: .custom(key: MessageKeys.browserRUMEvent, baggage: .init(event)), else: {
                DD.logger.warn("A WebView RUM event is lost because RUM is disabled in the SDK")
            })
        }
    }
}
