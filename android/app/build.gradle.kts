import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// [C3] 업로드 키는 리포 밖에 둔다(iOS `.p8`과 같은 규칙).
// android/key.properties(이미 .gitignore 처리됨)가 keystore 경로와 비밀번호를 가리킨다.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) keystorePropertiesFile.inputStream().use { load(it) }
}

// [C5] flutter가 넘긴 dart-define를 되읽는다.
// `flutter build`는 `-Pdart-defines=<base64("KEY=VALUE")>,<…>` 형태로 넘기고
// (flutter_tools/lib/src/build_info.dart:368 `toGradleConfig`, 인코딩은 :1081·:1095
//  `utf8 → base64`, 구분자는 `,`), Flutter Gradle 플러그인이 같은 이름으로 읽는다
// (FlutterPlugin.kt:597 `project.findProperty("dart-defines")`).
val dartDefines: Map<String, String> =
    ((project.findProperty("dart-defines") as String?) ?: "")
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
                ?.split("=", limit = 2)
                ?.takeIf { it.size == 2 }
                ?.let { it[0] to it[1] }
        }
        .toMap()
val hasTagoKey = dartDefines["TAGO_KEY"].orEmpty().isNotEmpty()

android {
    namespace = "com.planroutine.app"          // [C2]
    compileSdk = flutter.compileSdkVersion     // 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // [C1] flutter_local_notifications 18.0.1이 AAR 메타데이터로 :app에도 요구한다.
        // 없으면 :app:checkDebugAarMetadata / :app:checkReleaseAarMetadata에서 죽는다.
        // AGP는 이 요구를 "전파"하지 않는다 — 검사해서 실패시킨다.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.planroutine.app"  // [C2] iOS 번들과 통일. 영구 확정
        minSdk = flutter.minSdkVersion         // 24
        // ⚠️ 하드코딩으로 내리지 말 것 — 2026-08-31부터 Play 신규/업데이트는 API 36 하한이다.
        targetSdk = flutter.targetSdkVersion   // 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // [C3] key.properties가 있을 때만 release 서명 설정을 만든다.
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // [C3] debug 키 고정 → release 키. 없으면 debug로 떨어지되 아래 가드가
            // release 태스크를 막는다(디버그 빌드는 계속 돌아간다).
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // [C1] 2.1.5로 실측 통과. 플러그인 README의 1.2.2는 AGP 7.3.1 시절 문구다.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// [C3][C5] release 산출물이 **서명 키 없이** 또는 **TAGO 인증키 없이** 나가는 것을 막는다.
// CLAUDE.md의 "키 빠진 IPA가 조용히 심사에 오른다" 함정의 Android판 예방이고, iOS와 달리
// **빌드 자체가 막힌다** — 레인을 우회해 손으로 쳐도 걸린다(그것이 관통 원칙 ①의 실효다).
gradle.taskGraph.whenReady {
    if (allTasks.none { it.name.endsWith("Release") }) return@whenReady

    if (!hasReleaseKeystore) {
        throw GradleException(
            "android/key.properties가 없습니다. 업로드 키 없이 release를 만들 수 없습니다.\n" +
                "  keystore: ~/.android/keystores/planroutine-upload.jks",
        )
    }
    if (!hasTagoKey) {
        throw GradleException(
            "TAGO_KEY dart-define가 비어 있습니다. 버스 기능이 죽은 release를 만들 수 없습니다.\n" +
                "  ./android/bin/fastlane.sh build_aab 으로 빌드하십시오" +
                "(레인이 ~/.planroutine/tago.env 를 읽어 --dart-define-from-file로 넘깁니다).",
        )
    }
}

flutter {
    source = "../.."
}
