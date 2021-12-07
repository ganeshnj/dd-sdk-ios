/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import WebKit

// TODO: RUMM-1794 rename the methods
public extension WKUserContentController {
    func addDatadogMessageHandler(allowedWebViewHosts: Set<String>) {
        __addDatadogMessageHandler(allowedWebViewHosts: allowedWebViewHosts, hostsSanitizer: HostsSanitizer())
    }

    internal func __addDatadogMessageHandler(allowedWebViewHosts: Set<String>, hostsSanitizer: HostsSanitizing) {
        let bridgeName = DatadogMessageHandler.name

        let messageHandler = DatadogMessageHandler(
            eventBridge: WebEventBridge(
                logEventConsumer: WebLogEventConsumer(),
                rumEventConsumer: WebRUMEventConsumer()
            )
        )
        add(messageHandler, name: bridgeName)

        // WebKit installs message handlers with the given name format below
        // We inject a user script to forward `window.{bridgeName}` to WebKit's format
        let webkitMethodName = "window.webkit.messageHandlers.\(bridgeName).postMessage"
        // `WKScriptMessageHandlerWithReply` returns `Promise` and `browser-sdk` expects immediate values.
        // We inject a user script to return `allowedWebViewHosts` instead of using `WKScriptMessageHandlerWithReply`
        let sanitizedHosts = hostsSanitizer.sanitized(
            hosts: allowedWebViewHosts,
            warningMessage: "The allowed WebView host configured for Datadog SDK is not valid"
        )
        let allowedWebViewHostsString = sanitizedHosts
            .map { return "\"\($0)\"" }
            .joined(separator: ",")

        let js = """
        window.\(bridgeName) = {
          send(msg) {
            \(webkitMethodName)(msg)
          },
          getAllowedWebViewHosts() {
            return '[\(allowedWebViewHostsString)]'
          }
        }
        """
        addUserScript(
            WKUserScript(
                source: js,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
    }
}

private class DatadogMessageHandler: NSObject, WKScriptMessageHandler {
    static let name = "DatadogEventBridge"
    private let eventBridge: WebEventBridge
    private let queue = DispatchQueue(
        label: "com.datadoghq.JSEventBridge",
        target: .global(qos: .userInteractive)
    )

    init(eventBridge: WebEventBridge) {
        self.eventBridge = eventBridge
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        queue.async {
            do {
                try self.eventBridge.consume(message.body)
            } catch {
                userLogger.error("🔥 Web Event Error: \(error)")
            }
        }
    }
}
