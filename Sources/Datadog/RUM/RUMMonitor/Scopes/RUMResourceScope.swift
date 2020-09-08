/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

internal class RUMResourceScope: RUMScope {
    // MARK: - Initialization

    let context: RUMContext
    private let dependencies: RUMScopeDependencies

    /// The name used to identify this Resource.
    internal let resourceName: String
    /// Resource attributes.
    private(set) var attributes: [AttributeKey: AttributeValue]

    /// The Resource url.
    private var resourceURL: String
    /// The start time of this Resource loading.
    private var resourceLoadingStartTime: Date
    /// The HTTP method used to load this Resource.
    private var resourceHTTPMethod: RUMHTTPMethod

    init(
        context: RUMContext,
        dependencies: RUMScopeDependencies,
        resourceName: String,
        attributes: [AttributeKey: AttributeValue],
        startTime: Date,
        url: String,
        httpMethod: RUMHTTPMethod
    ) {
        self.context = context
        self.dependencies = dependencies
        self.resourceName = resourceName
        self.attributes = attributes
        self.resourceURL = url
        self.resourceLoadingStartTime = startTime
        self.resourceHTTPMethod = httpMethod
    }

    // MARK: - RUMScope

    func process(command: RUMCommand) -> Bool {
        switch command {
        case let command as RUMStopResourceCommand where command.resourceName == resourceName:
            sendResourceEvent(on: command)
            return false
        case let command as RUMStopResourceWithErrorCommand where command.resourceName == resourceName:
            sendErrorEvent(on: command)
            return false
        default:
            break
        }
        return true
    }

    // MARK: - Sending RUM Events

    private func sendResourceEvent(on command: RUMStopResourceCommand) {
        attributes.merge(rumCommandAttributes: command.attributes)

        let eventData = RUMResource(
            date: resourceLoadingStartTime.timeIntervalSince1970.toInt64Milliseconds,
            application: .init(id: context.rumApplicationID),
            session: .init(id: context.sessionID.toRUMDataFormat, type: .user),
            view: .init(
                id: context.activeViewID.orNull.toRUMDataFormat,
                referrer: nil,
                url: context.activeViewURI ?? ""
            ),
            usr: dependencies.userInfoProvider.current,
            connectivity: dependencies.connectivityInfoProvider.current,
            dd: .init(),
            resource: .init(
                type: command.kind.toRUMDataFormat,
                method: resourceHTTPMethod.toRUMDataFormat,
                url: resourceURL,
                statusCode: command.httpStatusCode?.toInt64,
                duration: command.time.timeIntervalSince(resourceLoadingStartTime).toInt64Nanoseconds,
                size: command.size?.toInt64 ?? 0,
                redirect: nil,
                dns: nil,
                connect: nil,
                ssl: nil,
                firstByte: nil,
                download: nil
            ),
            action: context.activeUserActionID.flatMap { rumUUID in
                .init(id: rumUUID.toRUMDataFormat)
            }
        )

        let event = dependencies.eventBuilder.createRUMEvent(with: eventData, attributes: attributes)
        dependencies.eventOutput.write(rumEvent: event)
    }

    private func sendErrorEvent(on command: RUMStopResourceWithErrorCommand) {
        attributes.merge(rumCommandAttributes: command.attributes)

        let eventData = RUMError(
            date: command.time.timeIntervalSince1970.toInt64Milliseconds,
            application: .init(id: context.rumApplicationID),
            session: .init(id: context.sessionID.toRUMDataFormat, type: .user),
            view: .init(
                id: context.activeViewID.orNull.toRUMDataFormat,
                referrer: nil,
                url: context.activeViewURI ?? ""
            ),
            usr: dependencies.userInfoProvider.current,
            connectivity: dependencies.connectivityInfoProvider.current,
            dd: .init(),
            error: .init(
                message: command.errorMessage,
                source: command.errorSource.toRUMDataFormat,
                stack: command.stack,
                isCrash: false,
                resource: .init(
                    method: resourceHTTPMethod.toRUMDataFormat,
                    statusCode: command.httpStatusCode?.toInt64 ?? 0,
                    url: resourceURL
                )
            ),
            action: context.activeUserActionID.flatMap { rumUUID in
                .init(id: rumUUID.toRUMDataFormat)
            }
        )

        let event = dependencies.eventBuilder.createRUMEvent(with: eventData, attributes: attributes)
        dependencies.eventOutput.write(rumEvent: event)
    }
}
