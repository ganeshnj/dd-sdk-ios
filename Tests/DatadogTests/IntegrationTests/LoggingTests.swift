/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class LoggingTests: XCTestCase {
    private let serverMock = ServerMock()
    private var serverSession: ServerSession! // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        logsDirectory.delete()
        serverSession = serverMock.obtainUniqueRecordingSession()

        Datadog.initialize(
            appContext: AppContext(
                bundleIdentifier: "com.datadoghq.ios-sdk",
                bundleVersion: "1.0.0",
                bundleShortVersion: "1.0.0",
                executableName: "some-app",
                mobileDevice: nil
            ),
            configuration: Datadog.Configuration.builderUsing(clientToken: "abcd")
                .set(logsEndpoint: .custom(url: serverSession.recordingURL))
                .build()
        )
    }

    override func tearDown() {
        try! Datadog.deinitializeOrThrow()
        super.tearDown()
    }

    // swiftlint:disable trailing_closure
    func testLogsWithTagsAndAttributesAreUploadedToServer() throws {
        // Configure logger
        let logger = Logger.builder
            .printLogsToConsole(true)
            .set(serviceName: "service-name")
            .set(loggerName: "logger-name")
            .build()

        // Send logs
        logger.addTag(withKey: "tag1", value: "tag-value")
        logger.add(tag: "tag2")

        logger.addAttribute(forKey: "logger-attribute1", value: "string value")
        logger.addAttribute(forKey: "logger-attribute2", value: 1_000)

        logger.debug("debug message", attributes: ["attribute": "value"])
        logger.info("info message", attributes: ["attribute": "value"])
        logger.notice("notice message", attributes: ["attribute": "value"])
        logger.warn("warn message", attributes: ["attribute": "value"])
        logger.error("error message", attributes: ["attribute": "value"])
        logger.critical("critical message", attributes: ["attribute": "value"])

        // Wait for delivery
        Thread.sleep(forTimeInterval: 30)

        // Assert
        let logMatchers = try serverSession.getRecordedPOSTRequests()
            .flatMap { request in try request.httpBody.toArrayOfJSONObjects() }
            .map { jsonObject in LogMatcher(from: jsonObject) }

        logMatchers[0].assertStatus(equals: "DEBUG")
        logMatchers[0].assertMessage(equals: "debug message")

        logMatchers[1].assertStatus(equals: "INFO")
        logMatchers[1].assertMessage(equals: "info message")

        logMatchers[2].assertStatus(equals: "NOTICE")
        logMatchers[2].assertMessage(equals: "notice message")

        logMatchers[3].assertStatus(equals: "WARN")
        logMatchers[3].assertMessage(equals: "warn message")

        logMatchers[4].assertStatus(equals: "ERROR")
        logMatchers[4].assertMessage(equals: "error message")

        logMatchers[5].assertStatus(equals: "CRITICAL")
        logMatchers[5].assertMessage(equals: "critical message")

        logMatchers.forEach { matcher in
            matcher.assertDate(matches: { $0.isNotOlderThan(seconds: 60) })
            matcher.assertServiceName(equals: "service-name")
            matcher.assertLoggerName(equals: "logger-name")
            matcher.assertLoggerVersion(equals: sdkVersion)
            matcher.assertApplicationVersion(equals: "1.0.0")
            matcher.assertThreadName(equals: "main")
            matcher.assertAttributes(
                equal: [
                    "logger-attribute1": "string value",
                    "logger-attribute2": 1_000,
                    "attribute": "value",
                ]
            )
            matcher.assertTags(equal: ["tag1:tag-value", "tag2"])

            typealias LogJSONKeys = LogEncoder.StaticCodingKeys

            matcher.assertValue(
                forKeyPath: LogJSONKeys.networkReachability.rawValue,
                matches: { (value: String) -> Bool in
                    let validValues = NetworkConnectionInfo.Reachability.allCases.map { $0.rawValue }
                    return validValues.contains(value)
                }
            )
            matcher.assertValue(
                forKeyPath: LogJSONKeys.networkAvailableInterfaces.rawValue,
                matches: { (value: [String]) -> Bool in
                    let validValues = NetworkConnectionInfo.Interface.allCases.map { $0.rawValue }
                    return Set(value).isSubset(of: Set(validValues))
                }
            )
            matcher.assertValue(forKeyPath: LogJSONKeys.networkConnectionSupportsIPv4.rawValue, isTypeOf: Bool.self)
            matcher.assertValue(forKeyPath: LogJSONKeys.networkConnectionSupportsIPv6.rawValue, isTypeOf: Bool.self)
            matcher.assertValue(forKeyPath: LogJSONKeys.networkConnectionIsExpensive.rawValue, isTypeOf: Bool.self)
            matcher.assertValue(
                forKeyPath: LogJSONKeys.networkConnectionIsConstrained.rawValue,
                isTypeOf: Optional<Bool>.self
            )

            // Carrier info is empty both on macOS and iOS Simulator
            matcher.assertNoValue(forKey: LogJSONKeys.mobileNetworkCarrierName.rawValue)
            matcher.assertNoValue(forKey: LogJSONKeys.mobileNetworkCarrierISOCountryCode.rawValue)
            matcher.assertNoValue(forKey: LogJSONKeys.mobileNetworkCarrierRadioTechnology.rawValue)
            matcher.assertNoValue(forKey: LogJSONKeys.mobileNetworkCarrierAllowsVoIP.rawValue)
        }
    }
    // swiftlint:enable trailing_closure
}
