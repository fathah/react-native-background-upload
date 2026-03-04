# react-native-bg-upload

> Fork of `react-native-background-upload` package with support to latest React Native versions

The only React Native http post file uploader with android and iOS background support. If you are uploading large files like videos, use this so your users can background your app during a long upload.

NOTE: Use major version 4 with RN 47.0 and greater. If you have RN less than 47, use 3.0. To view all available versions:
`npm show @fathah_cr/react-native-bg-upload versions`

# Installation

```sh
npm install --save @fathah_cr/react-native-bg-upload
```

or

```sh
yarn add @fathah_cr/react-native-bg-upload
```

# Usage

```js
import Upload from '@fathah_cr/react-native-bg-upload';

const options = {
  url: 'https://myservice.com/path/to/post',
  path: 'file://path/to/file/on/device',
  method: 'POST',
  type: 'raw',
  maxRetries: 2, // set retry count (Android only). Default 2
  headers: {
    'content-type': 'application/octet-stream', // Customize content-type
    'my-custom-header': 's3headervalueorwhateveryouneed',
  },
  // Below are options only supported on Android
  notification: {
    enabled: true,
  },
  useUtf8Charset: true,
};

Upload.startUpload(options)
  .then((uploadId) => {
    console.log('Upload started');
    Upload.addListener('progress', uploadId, (data) => {
      console.log(`Progress: ${data.progress}%`);
    });
    Upload.addListener('error', uploadId, (data) => {
      console.log(`Error: ${data.error}%`);
    });
    Upload.addListener('cancelled', uploadId, (data) => {
      console.log(`Cancelled!`);
    });
    Upload.addListener('completed', uploadId, (data) => {
      // data includes responseCode: number and responseBody: Object
      console.log('Completed!');
    });
  })
  .catch((err) => {
    console.log('Upload error!', err);
  });
```

## Multipart Uploads

Just set the `type` option to `multipart` and set the `field` option. Example:

```
const options = {
  url: 'https://myservice.com/path/to/post',
  path: 'file://path/to/file%20on%20device.png',
  method: 'POST',
  field: 'uploaded_media',
  type: 'multipart'
}
```

Note the `field` property is required for multipart uploads.

# API

## Top Level Functions

All top-level methods are available as named exports or methods on the default export.

### startUpload(options)

The primary method you will use, this starts the upload process.

Returns a promise with the string ID of the upload. Will reject if there is a connection problem, the file doesn't exist, or there is some other problem.

`options` is an object with following values:

_Note: You must provide valid URIs. @fathah_cr/react-native-bg-upload does not escape the values you provide._

| Name             | Type                            | Required                        | Default                                                                                                                                                                                                      | Description                                                                                                                                                                                                                     | Example                                                               |
| ---------------- | ------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `url`            | string                          | Required                        |                                                                                                                                                                                                              | URL to upload to                                                                                                                                                                                                                | `https://myservice.com/path/to/post`                                  |
| `path`           | string                          | Required                        |                                                                                                                                                                                                              | File path on device                                                                                                                                                                                                             | `file://something/coming/from%20the%20device.png`                     |
| `type`           | 'raw' or 'multipart'            | Optional                        | `raw`                                                                                                                                                                                                        | Primary upload type.                                                                                                                                                                                                            |                                                                       |
| `method`         | string                          | Optional                        | `POST`                                                                                                                                                                                                       | HTTP method                                                                                                                                                                                                                     |                                                                       |
| `customUploadId` | string                          | Optional                        |                                                                                                                                                                                                              | `startUpload` returns a Promise that includes the upload ID, which can be used for future status checks. By default, the upload ID is automatically generated. This parameter allows a custom ID to use instead of the default. |                                                                       |
| `headers`        | object                          | Optional                        |                                                                                                                                                                                                              | HTTP headers                                                                                                                                                                                                                    | `{ 'Accept': 'application/json' }`                                    |
| `field`          | string                          | Required if `type: 'multipart'` |                                                                                                                                                                                                              | The form field name for the file. Only used when `type: 'multipart`                                                                                                                                                             | `uploaded-file`                                                       |
| `parameters`     | object                          | Optional                        |                                                                                                                                                                                                              | Additional form fields to include in the HTTP request. Only used when `type: 'multipart`                                                                                                                                        |                                                                       |
| `notification`   | Notification object (see below) | Optional                        |                                                                                                                                                                                                              | Android only.                                                                                                                                                                                                                   | `{ enabled: true, onProgressTitle: "Uploading...", autoClear: true }` |
| `useUtf8Charset` | boolean                         | Optional                        |                                                                                                                                                                                                              | Android only. Set to true to use `utf-8` as charset.                                                                                                                                                                            |                                                                       |
| `appGroup`       | string                          | Optional                        | iOS only. App group ID needed for share extensions to be able to properly call the library. See: https://developer.apple.com/documentation/foundation/nsfilemanager/1412643-containerurlforsecurityapplicati |

### Notification Object (Android Only)

| Name                  | Type    | Required | Description                                                                                                                                                                                        | Example                                                          |
| --------------------- | ------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `enabled`             | boolean | Optional | Enable or diasable notifications. Works only on Android version < 8.0 Oreo. On Android versions >= 8.0 Oreo is required by Google's policy to display a notification when a background service run | `{ enabled: true }`                                              |
| `autoClear`           | boolean | Optional | Autoclear notification on complete                                                                                                                                                                 | `{ autoclear: true }`                                            |
| `notificationChannel` | string  | Optional | Sets android notificaion channel                                                                                                                                                                   | `{ notificationChannel: "My-Upload-Service" }`                   |
| `enableRingTone`      | boolean | Optional | Sets whether or not to enable the notification sound when the upload gets completed with success or error                                                                                          | `{ enableRingTone: true }`                                       |
| `onProgressTitle`     | string  | Optional | Sets notification progress title                                                                                                                                                                   | `{ onProgressTitle: "Uploading" }`                               |
| `onProgressMessage`   | string  | Optional | Sets notification progress message                                                                                                                                                                 | `{ onProgressMessage: "Uploading new video" }`                   |
| `onCompleteTitle`     | string  | Optional | Sets notification complete title                                                                                                                                                                   | `{ onCompleteTitle: "Upload finished" }`                         |
| `onCompleteMessage`   | string  | Optional | Sets notification complete message                                                                                                                                                                 | `{ onCompleteMessage: "Your video has been uploaded" }`          |
| `onErrorTitle`        | string  | Optional | Sets notification error title                                                                                                                                                                      | `{ onErrorTitle: "Upload error" }`                               |
| `onErrorMessage`      | string  | Optional | Sets notification error message                                                                                                                                                                    | `{ onErrorMessage: "An error occured while uploading a video" }` |
| `onCancelledTitle`    | string  | Optional | Sets notification cancelled title                                                                                                                                                                  | `{ onCancelledTitle: "Upload cancelled" }`                       |
| `onCancelledMessage`  | string  | Optional | Sets notification cancelled message                                                                                                                                                                | `{ onCancelledMessage: "Video upload was cancelled" }`           |

### getFileInfo(path)

Returns some useful information about the file in question. Useful if you want to set a MIME type header.

`path` is a string, such as `file://path.to.the.file.png`

Returns a Promise that resolves to an object containing:

| Name        | Type    | Required    | Description                         | Example      |
| ----------- | ------- | ----------- | ----------------------------------- | ------------ |
| `name`      | string  | Required    | The file name within its directory. | `image2.png` |
| `exists`    | boolean | Required    | Is there a file matching this path? |              |
| `size`      | number  | If `exists` | File size, in bytes                 |              |
| `extension` | string  | If `exists` | File extension                      | `mov`        |
| `mimeType`  | string  | If `exists` | The MIME type for the file.         | `video/mp4`  |

### cancelUpload(uploadId)

Cancels an upload.

`uploadId` is the result of the Promise returned from `startUpload`

Returns a Promise that resolves to an boolean indicating whether the upload was cancelled.

### addListener(eventType, uploadId, listener)

Adds an event listener, possibly confined to a single upload.

`eventType` Event to listen for. Values: 'progress' | 'error' | 'completed' | 'cancelled'

`uploadId` The upload ID from `startUpload` to filter events for. If null, this will include all uploads.

`listener` Function to call when the event occurs.

Returns an [EventSubscription](https://github.com/facebook/react-native/blob/master/Libraries/vendor/emitter/EmitterSubscription.js). To remove the listener, call `remove()` on the `EventSubscription`.

## Events

### progress

Event Data

| Name       | Type   | Required | Description           |
| ---------- | ------ | -------- | --------------------- |
| `id`       | string | Required | The ID of the upload. |
| `progress` | 0-100  | Required | Percentage completed. |

### error

Event Data

| Name    | Type   | Required | Description           |
| ------- | ------ | -------- | --------------------- |
| `id`    | string | Required | The ID of the upload. |
| `error` | string | Required | Error message.        |

### completed

Event Data

| Name              | Type   | Required | Description                     |
| ----------------- | ------ | -------- | ------------------------------- |
| `id`              | string | Required | The ID of the upload.           |
| `responseCode`    | string | Required | HTTP status code received       |
| `responseBody`    | string | Required | HTTP response body              |
| `responseHeaders` | string | Required | HTTP response headers (Android) |

### cancelled

Event Data

| Name | Type   | Required | Description           |
| ---- | ------ | -------- | --------------------- |
| `id` | string | Required | The ID of the upload. |

# Customizing Android Build Properties

You may want to customize the `compileSdk, buildToolsVersion, and targetSdkVersion` versions used by this package. For that, add this to `android/build.gradle`:

```
ext {
    targetSdkVersion = 23
    compileSdkVersion = 23
    buildToolsVersion = '23.0.2'
}
```

Add it above `allProjects` and you're good. Your `android/build.gradle` might then resemble:

```
buildscript {
    repositories {
        jcenter()
    }
}

ext {
    targetSdkVersion = 27
    compileSdkVersion = 27
    buildToolsVersion = '23.0.2'
}

allprojects {

```

# FAQs

Does it support iOS camera roll assets?

> Yes, as of version 4.3.0.

Does it support multiple file uploads?

> Yes and No. It supports multiple concurrent uploads, but only a single upload per request. That should be fine for 90%+ of cases.

Why should I use this file uploader instead of others that I've Googled like [react-native-uploader](https://github.com/aroth/react-native-uploader)?

> This package has two killer features not found anywhere else (as of 12/16/2016). First, it works on both iOS and Android. Others are iOS only. Second, it supports background uploading. This means that users can background your app and the upload will continue. This does not happen with other uploaders.

# Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

# Common Issues

## BREAKING CHANGE IN 3.0

This is for 3.0 only. This does NOT apply to 4.0, as recent React Native versions have upgraded the `okhttp` dependencies. Anyway...

In 3.0, you need to add

```gradle
    configurations.all { resolutionStrategy.force 'com.squareup.okhttp3:okhttp:3.4.1' }
```

to your app's app's `android/app/build.gradle` file.

Just add it above (not within) `dependencies` and you'll be fine.

## Gratitude

Thanks to:

- [android-upload-service](https://github.com/gotev/android-upload-service) It made Android dead simple to support.

- [MIME type from path on iOS](http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database) Thanks for the answer!
