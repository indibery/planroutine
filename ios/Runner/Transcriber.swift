import AVFoundation
import Flutter
import Foundation
import Speech

/// 지도 기록 '글로 보기' — 기기 안 전사(iOS 26+). 녹음은 기기 밖으로 나가지 않는다.
/// 표시 규칙(글 없음 구간·복사 형식)은 Dart가 진다. 여기는 엔진 결과를 그대로 넘긴다.
/// 이름은 `TranscriberContract`(Dart)와 같아야 한다 — `transcriber_wiring_test.dart`가 대조한다.
enum TranscriberChannels {
  static let method = "planroutine/transcriber"
  static let events = "planroutine/transcriber/segments"
  static let isAvailable = "isAvailable"
  static let preparing = "preparing"
  static let segment = "segment"

  private static let handler = TranscriberStreamHandler()

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: method, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == isAvailable else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          let ok = await KoreanTranscriber.isAvailable()
          DispatchQueue.main.async { result(ok) }
        }
      } else {
        result(false)
      }
    }
    FlutterEventChannel(name: events, binaryMessenger: messenger).setStreamHandler(handler)
  }
}

final class TranscriberStreamHandler: NSObject, FlutterStreamHandler {
  private var task: Task<Void, Never>?

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard let path = arguments as? String else {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
    guard #available(iOS 26.0, *) else {
      return FlutterError(code: "unsupported", message: nil, details: nil)
    }
    task?.cancel()
    task = Task { await KoreanTranscriber.run(path: path, sink: events) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // 화면을 떠나면 Dart가 구독을 끊는다 → 전사를 멈춘다.
    task?.cancel()
    task = nil
    return nil
  }
}

@available(iOS 26.0, *)
enum KoreanTranscriber {
  private static let wanted = Locale(identifier: "ko-KR")

  static func isAvailable() async -> Bool {
    guard SpeechTranscriber.isAvailable else { return false }
    return await SpeechTranscriber.supportedLocale(equivalentTo: wanted) != nil
  }

  static func run(path: String, sink: @escaping FlutterEventSink) async {
    // 취소된 뒤에는 아무것도 보내지 않는다. 메시지에 경로·내용을 넣지 않는다.
    func send(_ value: Any) {
      if Task.isCancelled { return }
      DispatchQueue.main.async { sink(value) }
    }
    func fail(_ code: String) { send(FlutterError(code: code, message: nil, details: nil)) }

    guard FileManager.default.fileExists(atPath: path) else { return fail("fileNotFound") }
    guard SpeechTranscriber.isAvailable,
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted)
    else { return fail("unsupported") }

    let transcriber = SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [],  // 확정 결과만
      attributeOptions: [.audioTimeRange]
    )
    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        send(["type": TranscriberChannels.preparing])
        do {
          try await request.downloadAndInstall()
        } catch {
          return fail("modelDownloadFailed")
        }
      }
      let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      let collector = Task {
        for try await result in transcriber.results {
          send([
            "type": TranscriberChannels.segment,
            "startMs": Int(result.range.start.seconds * 1000),
            "endMs": Int(result.range.end.seconds * 1000),
            "text": String(result.text.characters),
          ])
        }
      }
      try await withTaskCancellationHandler {
        if let last = try await analyzer.analyzeSequence(from: file) {
          try await analyzer.finalizeAndFinish(through: last)
        } else {
          await analyzer.cancelAndFinishNow()
        }
        try await collector.value
      } onCancel: {
        collector.cancel()
        Task { await analyzer.cancelAndFinishNow() }
      }
      send(FlutterEndOfEventStream)
    } catch is CancellationError {
      return
    } catch {
      fail("failed")
    }
  }
}
