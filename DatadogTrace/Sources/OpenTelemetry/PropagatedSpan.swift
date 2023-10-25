//
//  File.swift
//
//
//  Created by Ganesh Jangir on 25/10/2023.
//

import Foundation
import DatadogInternal
import OpenTelemetryApi

struct ConversionHelper {
    static func ToUInt64(from spanId: SpanId) -> UInt64 {
        var data = Data(count: 8)
        spanId.copyBytesTo(dest: &data, destOffset: 0)
        return UInt64(bigEndian: data.withUnsafeBytes { $0.load(as: UInt64.self) })
    }

    static func ToUInt64(from traceId: TraceId) -> UInt64 {
        var data = Data(count: 16)
        traceId.copyBytesTo(dest: &data, destOffset: 0)
        return UInt64(bigEndian: data.withUnsafeBytes { $0.load(as: UInt64.self) })
    }
}

extension SpanId {
    func toLong() -> UInt64 {
        var data = Data(count: 8)
        self.copyBytesTo(dest: &data, destOffset: 0)
        return UInt64(bigEndian: data.withUnsafeBytes { $0.load(as: UInt64.self) })
    }

    func toDatadogSpanID() -> DatadogInternal.SpanID {
        .init(integerLiteral: toLong())
    }
}


extension TraceId {
    func toLong() -> UInt64 {
        var data = Data(count: 16)
        self.copyBytesTo(dest: &data, destOffset: 0)
        return UInt64(bigEndian: data.withUnsafeBytes { $0.load(as: UInt64.self) })
    }

    func toDatadogTraceID() -> DatadogInternal.TraceID {
        .init(integerLiteral: toLong())
    }
}

class WrapperSpan: OpenTelemetryApi.Span {
    var kind: OpenTelemetryApi.SpanKind
    var context: OpenTelemetryApi.SpanContext
    var name: String
    var nestedSpan: DDSpan

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        nestedSpan.finish(at: time)
    }

    /// Creates an instance of this class with the SpanContext, Span kind and name
    /// - Parameters:
    ///   - context: the SpanContext
    ///   - kind: the SpanKind
    init(name: String, context: SpanContext, kind: SpanKind, tracer: DatadogTracer) {
        self.nestedSpan = .init(tracer: tracer,
                                context: .init(traceID: context.traceId.toDatadogTraceID(),
                                               spanID: context.spanId.toDatadogSpanID(),
                                               parentSpanID: nil,
                                               baggageItems: .init()),
                                operationName: name,
                                startTime: Date(),
                                tags: [:])
        self.kind = .client
        self.context = context
        self.name = name
    }

    var isRecording: Bool {
        return false
    }

    var status: Status {
        get {
            return Status.ok
        }
        set {}
    }

    var description: String {
        return "PropagatedSpan"
    }

    func updateName(name: String) {
        self.nestedSpan.setOperationName(name)
        self.name = name
    }

    func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue?) {
        self.nestedSpan.setTag(key: key, value: value)
    }

    func addEvent(name: String) {
        self.nestedSpan.log(fields: [name: ""])
    }

    func addEvent(name: String, timestamp: Date) {
        self.nestedSpan.log(fields: [name: ""], timestamp: timestamp)
    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue]) {
        self.nestedSpan.log(fields: attributes)
    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue], timestamp: Date) {
        self.nestedSpan.log(fields: attributes, timestamp: timestamp)
    }
}
