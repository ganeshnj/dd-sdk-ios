//
//  File.swift
//
//
//  Created by Ganesh Jangir on 25/10/2023.
//

import Foundation
import OpenTelemetryApi

class WrapperSpanBuilder: SpanBuilder {
    private var tracer: DatadogTracer
    private var isRootSpan: Bool = false
    private var spanContext: SpanContext?
    private var spanName: String

    init(tracer: DatadogTracer, spanName: String) {
        self.tracer = tracer
        self.spanName = spanName
    }

    @discardableResult public func startSpan() -> Span {
        if spanContext == nil, !isRootSpan {
            spanContext = OpenTelemetry.instance.contextProvider.activeSpan?.context
        }
        return WrapperSpan(name: spanName,
                           context: spanContext ?? SpanContext.create(traceId: TraceId.random(),
                                                                      spanId: SpanId.random(),
                                                                      traceFlags: TraceFlags(),
                                                                      traceState: TraceState()),
                              kind: .client,
                              tracer: tracer)
    }

    @discardableResult public func setParent(_ parent: Span) -> Self {
        spanContext = parent.context
        return self
    }

    @discardableResult public func setParent(_ parent: SpanContext) -> Self {
        spanContext = parent
        return self
    }

    @discardableResult public func setNoParent() -> Self {
        isRootSpan = true
        return self
    }

    @discardableResult public func addLink(spanContext: SpanContext) -> Self {
        return self
    }

    @discardableResult public func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self {
        return self
    }

    @discardableResult public func setSpanKind(spanKind: SpanKind) -> Self {
        return self
    }

    @discardableResult public func setStartTime(time: Date) -> Self {
        return self
    }

    public func setAttribute(key: String, value: AttributeValue) -> Self {
        
        return self
    }

    func setActive(_ active: Bool) -> Self {
        return self
    }
}
