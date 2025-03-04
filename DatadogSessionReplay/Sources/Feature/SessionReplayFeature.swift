/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternal

internal class SessionReplayFeature: DatadogRemoteFeature {
    static let name: String = "session-replay"
    let requestBuilder: FeatureRequestBuilder
    let messageReceiver: FeatureMessageReceiver
    let performanceOverride: PerformancePresetOverride?

    // MARK: - Main Components

    /// Orchestrates the process of capturing next snapshots on the main thread.
    let recordingCoordinator: RecordingCoordinator
    /// Processes each new snapshot on a background thread and transforms it into records.
    let processor: Processing
    /// Writes records to sdk core.
    let writer: Writing
    /// Sends telemetry through sdk core.
    let telemetry: Telemetry

    // MARK: - Initialization

    init(
        core: DatadogCoreProtocol,
        configuration: SessionReplay.Configuration
    ) throws {
        let writer = Writer()
        let telemetry = TelemetryCore(core: core)

        let processor = Processor(
            queue: BackgroundAsyncQueue(named: "com.datadoghq.session-replay.processor"),
            writer: writer,
            srContextPublisher: SRContextPublisher(core: core),
            telemetry: telemetry
        )

        let scheduler = MainThreadScheduler(interval: 0.1)
        let messageReceiver = RUMContextReceiver()

        let recorder = try Recorder(
            processor: processor,
            telemetry: telemetry
        )
        let recordingCoordinator = RecordingCoordinator(
            scheduler: scheduler,
            privacy: configuration.defaultPrivacyLevel,
            rumContextObserver: messageReceiver,
            srContextPublisher: SRContextPublisher(core: core),
            recorder: recorder,
            sampler: Sampler(samplingRate: configuration.debugSDK ? 100 : configuration.replaySampleRate)
        )

        self.messageReceiver = messageReceiver
        self.recordingCoordinator = recordingCoordinator
        self.processor = processor
        self.writer = writer
        self.requestBuilder = RequestBuilder(
            customUploadURL: configuration.customEndpoint,
            telemetry: telemetry
        )
        self.performanceOverride = PerformancePresetOverride(
            maxFileSize: UInt64(10).MB,
            maxObjectSize: UInt64(10).MB,
            meanFileAge: 2, // vs 5s with `batchSize: .small` - see `DatadogCore.PerformancePreset`
            uploadDelay: (
                initial: 2, // vs 5s with `uploadFrequency: .frequent`
                range: 0.6..<6, // vs 1s ..< 10s with `uploadFrequency: .frequent`
                changeRate: 0.75 // vs 0.1 with `uploadFrequency: .frequent`
            )
        )
        self.telemetry = telemetry
    }
}
