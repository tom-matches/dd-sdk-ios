/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import class DatadogInternal.HTTPHeadersWriter

@objc
public class DDHTTPHeadersWriter: NSObject {
    let swiftHTTPHeadersWriter: HTTPHeadersWriter

    @objc public var traceHeaderFields: [String: String] {
        swiftHTTPHeadersWriter.traceHeaderFields
    }

    @objc
    public init(samplingRate: Float = 20) {
        swiftHTTPHeadersWriter = HTTPHeadersWriter(samplingRate: samplingRate)
    }
}
