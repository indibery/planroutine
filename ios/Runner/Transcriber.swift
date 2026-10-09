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

  /// 구독마다 올린다. 취소 확인과 메인 큐 전달 사이에 실린 문단이 다음 구독으로 가지 않게,
  /// 싱크에 닿기 직전(메인 스레드)에 자기 세대인지 본다. onListen·onCancel도 메인 스레드라 경합이 없다.
  private var generation = 0

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
    generation += 1
    let mine = generation
    let guarded: FlutterEventSink = { [weak self] value in
      guard let self, self.generation == mine else { return }
      events(value)
    }
    task = Task { await KoreanTranscriber.run(path: path, sink: guarded) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // 화면을 떠나면 Dart가 구독을 끊는다 → 전사를 멈추고, 이미 실린 문단도 버린다.
    generation += 1
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

  /// NaN·무한(잘못된 CMTime)을 Int로 바꾸면 앱이 멈춘다 — 그때는 0으로 둔다.
  private static func milliseconds(_ time: CMTime) -> Int {
    let seconds = time.seconds
    return seconds.isFinite ? Int(seconds * 1000) : 0
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
            "startMs": milliseconds(result.range.start),
            "endMs": milliseconds(result.range.end),
            "text": String(result.text.characters),
          ])
        }
      }
      do {
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
      } catch {
        // 취소 처리기는 취소될 때만 돈다 — 분석기가 던지면(손상된 녹음 등) 여기서 정리한다.
        collector.cancel()
        await analyzer.cancelAndFinishNow()
        throw error
      }
      send(FlutterEndOfEventStream)
    } catch is CancellationError {
      return
    } catch {
      fail("failed")
    }
  }
}
