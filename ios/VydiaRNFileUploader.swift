import Foundation
import MobileCoreServices
import Photos
import React
import UniformTypeIdentifiers

@objc(VydiaRNFileUploader)
class VydiaRNFileUploader: RCTEventEmitter, URLSessionTaskDelegate, URLSessionDataDelegate {

    static var uploadId = 0
    static let BackgroundSessionId = "ReactNativeBackgroundUpload"
    var urlSession: URLSession?
    var responsesData = [Int: Data]()

    override class func requiresMainQueueSetup() -> Bool {
        return false
    }

    override func supportedEvents() -> [String]! {
        return [
            "RNFileUploader-progress",
            "RNFileUploader-error",
            "RNFileUploader-cancelled",
            "RNFileUploader-completed",
        ]
    }

    @objc
    func getFileInfo(
        _ path: String, resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            guard
                let escapedPath = path.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed)
            else {
                reject("RN Uploader", "Invalid characters in path", nil)
                return
            }

            guard let fileUri = URL(string: escapedPath) else {
                reject("RN Uploader", "Invalid URL string", nil)
                return
            }

            let pathWithoutProtocol = fileUri.path
            let name = fileUri.lastPathComponent
            let extensionStr = fileUri.pathExtension
            let exists = FileManager.default.fileExists(atPath: pathWithoutProtocol)

            var params: [String: Any] = [
                "name": name,
                "extension": extensionStr,
                "exists": exists,
            ]

            if exists {
                params["mimeType"] = guessMIMETypeFromFileName(fileName: name)
                let attributes = try FileManager.default.attributesOfItem(
                    atPath: pathWithoutProtocol)
                if let fileSize = attributes[.size] as? NSNumber {
                    params["size"] = fileSize
                }
            }
            resolve(params)
        } catch {
            reject("RN Uploader", error.localizedDescription, error)
        }
    }

    private func guessMIMETypeFromFileName(fileName: String) -> String {
        // Get file extension
        let fileExtension = (fileName as NSString).pathExtension

        // Get UTType from file extension
        if let utType = UTType(filenameExtension: fileExtension) {
            // Return the preferred MIME type, if available
            if let mimeType = utType.preferredMIMEType {
                return mimeType
            }
        }

        // Fallback
        return "application/octet-stream"
    }

    private func copyAssetToFile(
        assetUrl: String, completionHandler: @escaping (String?, Error?) -> Void
    ) {
        // Convert string URL to URL object
        guard let url = URL(string: assetUrl) else {
            completionHandler(
                nil,
                NSError(
                    domain: "RNUploader", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid asset URL"]))
            return
        }

        // Fetch PHAsset using the "localIdentifier" instead of ALAsset URL
        // If you have only a file URL (from camera roll export), you might need to map it to a PHAsset via `PHAsset.fetchAssets(with:)` with options

        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1

        // This assumes the last path component of your URL contains the local identifier
        let localIdentifier = url.lastPathComponent
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier], options: fetchOptions)

        guard let asset = fetchResult.firstObject else {
            completionHandler(
                nil,
                NSError(
                    domain: "RNUploader", code: 5,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Asset could not be fetched. Are you missing permissions?"
                    ]))
            return
        }

        guard let assetResource = PHAssetResource.assetResources(for: asset).first else {
            completionHandler(
                nil,
                NSError(
                    domain: "RNUploader", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Asset resource not found"]))
            return
        }

        let pathToWrite = NSTemporaryDirectory().appending(UUID().uuidString)
        let pathUrl = URL(fileURLWithPath: pathToWrite)
        let fileURI = pathUrl.path  // Use .path instead of .absoluteString for local file paths

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().writeData(
            for: assetResource, toFile: pathUrl, options: options
        ) { error in
            if let error = error {
                completionHandler(nil, error)
            } else {
                completionHandler(fileURI, nil)
            }
        }
    }

    @objc
    func startUpload(
        _ options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        let thisUploadId: Int
        objc_sync_enter(VydiaRNFileUploader.self)
        thisUploadId = VydiaRNFileUploader.uploadId
        VydiaRNFileUploader.uploadId += 1
        objc_sync_exit(VydiaRNFileUploader.self)

        guard let uploadUrl = options["url"] as? String else {
            reject("RN Uploader", "Missing url", nil)
            return
        }

        var fileURI = options["path"] as? String ?? ""
        let method = options["method"] as? String ?? "POST"
        let uploadType = options["type"] as? String ?? "raw"
        let fieldName = options["field"] as? String ?? ""
        let customUploadId = options["customUploadId"] as? String
        let appGroup = options["appGroup"] as? String
        let headers = options["headers"] as? [String: Any] ?? [:]
        let parameters = options["parameters"] as? [String: Any] ?? [:]

        guard let requestUrl = URL(string: uploadUrl) else {
            reject("RN Uploader", "URL not compliant with RFC 2396", nil)
            return
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = method

        for (key, val) in headers {
            if let strVal = val as? String {
                request.setValue(strVal, forHTTPHeaderField: key)
            } else if let numVal = val as? NSNumber {
                request.setValue(numVal.stringValue, forHTTPHeaderField: key)
            }
        }

        if fileURI.hasPrefix("assets-library") {
            let group = DispatchGroup()
            group.enter()
            var copyError: Error?

            self.copyAssetToFile(assetUrl: fileURI) { tempFileUrl, error in
                if let error = error {
                    copyError = error
                } else if let tempFileUrl = tempFileUrl {
                    fileURI = tempFileUrl
                }
                group.leave()
            }

            group.wait()

            if let error = copyError {
                reject("RN Uploader", "Asset could not be copied to temp file.", error)
                return
            }
        }

        var uploadTask: URLSessionDataTask?

        if uploadType == "multipart" {
            let uuidStr = UUID().uuidString
            request.setValue(
                "multipart/form-data; boundary=\(uuidStr)", forHTTPHeaderField: "Content-Type")

            guard
                let httpBody = self.createBody(
                    withBoundary: uuidStr, path: fileURI, parameters: parameters,
                    fieldName: fieldName)
            else {
                reject("RN Uploader", "Failed to create multipart body", nil)
                return
            }

            request.httpBodyStream = InputStream(data: httpBody)
            request.setValue("\(httpBody.count)", forHTTPHeaderField: "Content-Length")

            uploadTask = self.getSession(appGroup: appGroup).uploadTask(
                withStreamedRequest: request)
        } else {
            if !parameters.isEmpty {
                reject("RN Uploader", "Parameters supported only in multipart type", nil)
                return
            }
            guard let fileURL = URL(string: fileURI) else {
                reject("RN Uploader", "Invalid file URI", nil)
                return
            }
            uploadTask = self.getSession(appGroup: appGroup).uploadTask(
                with: request, fromFile: fileURL)
        }

        let taskIdStr = customUploadId ?? String(thisUploadId)
        uploadTask?.taskDescription = taskIdStr
        uploadTask?.resume()

        resolve(taskIdStr)
    }

    @objc
    func cancelUpload(
        _ cancelUploadId: String, resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        self.urlSession?.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            for uploadTask in uploadTasks {
                if uploadTask.taskDescription == cancelUploadId {
                    uploadTask.cancel()
                }
            }
        }
        resolve(true)
    }

    private func createBody(
        withBoundary boundary: String, path: String, parameters: [String: Any], fieldName: String
    ) -> Data? {
        var httpBody = Data()

        guard let escapedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let fileUri = URL(string: escapedPath)
        else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileUri, options: .mappedIfSafe)
        } catch {
            print("Failed to read file: \(error)")
            data = Data()
        }

        let filename = fileUri.lastPathComponent
        let mimetype = guessMIMETypeFromFileName(fileName: path)

        for (parameterKey, parameterValue) in parameters {
            let valStr = "\(parameterValue)"
            httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            httpBody.append(
                "Content-Disposition: form-data; name=\"\(parameterKey)\"\r\n\r\n".data(
                    using: .utf8)!)
            httpBody.append("\(valStr)\r\n".data(using: .utf8)!)
        }

        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!)
        httpBody.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
        httpBody.append(data)
        httpBody.append("\r\n".data(using: .utf8)!)
        httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return httpBody
    }

    private func getSession(appGroup: String?) -> URLSession {
        if let session = urlSession {
            return session
        }

        let sessionConfiguration = URLSessionConfiguration.background(
            withIdentifier: VydiaRNFileUploader.BackgroundSessionId)
        if let appGroup = appGroup, !appGroup.isEmpty {
            sessionConfiguration.sharedContainerIdentifier = appGroup
        }

        let session = URLSession(
            configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        urlSession = session
        return session
    }

    // MARK: - URLSessionTaskDelegate & URLSessionDataDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        var data: [String: Any] = ["id": task.taskDescription ?? ""]

        if let response = task.response as? HTTPURLResponse {
            data["responseCode"] = response.statusCode
        }

        if let responseData = responsesData[task.taskIdentifier] {
            responsesData.removeValue(forKey: task.taskIdentifier)
            if let responseString = String(data: responseData, encoding: .utf8) {
                data["responseBody"] = responseString
            } else {
                data["responseBody"] = NSNull()
            }
        } else {
            data["responseBody"] = NSNull()
        }

        if let error = error {
            data["error"] = error.localizedDescription
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                self.sendEvent(withName: "RNFileUploader-cancelled", body: data)
            } else {
                self.sendEvent(withName: "RNFileUploader-error", body: data)
            }
        } else {
            self.sendEvent(withName: "RNFileUploader-completed", body: data)
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        var progress: Float = -1.0
        if totalBytesExpectedToSend > 0 {
            progress = 100.0 * Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        }
        self.sendEvent(
            withName: "RNFileUploader-progress",
            body: [
                "id": task.taskDescription ?? "",
                "progress": progress,
            ])
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if data.isEmpty { return }
        if responsesData[dataTask.taskIdentifier] != nil {
            responsesData[dataTask.taskIdentifier]?.append(data)
        } else {
            responsesData[dataTask.taskIdentifier] = data
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        completionHandler(task.originalRequest?.httpBodyStream)
    }
}
