// Flutter UI 기본 패키지 (버튼, 텍스트 등 모든 위젯)
import 'package:flutter/material.dart';
// 앱 안에서 웹사이트를 보여주는 WebView 패키지
import 'package:webview_flutter/webview_flutter.dart';
// Flutter ↔ Android 네이티브 통신 패키지
import 'package:flutter/services.dart';
// 플랫폼 감지용 (Android인지 iOS인지 확인)
import 'dart:io' show Platform;

// Android 전용 import (Android에서만 로드됨)
import 'package:webview_flutter_android/webview_flutter_android.dart'
    if (dart.library.html) 'package:webview_flutter/webview_flutter.dart';

// 앱 시작점 - 앱을 실행시키는 함수
void main() {
  runApp(const MyApp()); // MyApp 위젯을 실행
}

// 앱 전체 설정을 담당하는 위젯 (테마, 앱 이름 등)
// StatelessWidget = 상태가 없는 위젯 (한번 그려지면 변하지 않음)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake Detector',            // 앱 이름
      debugShowCheckedModeBanner: false,  // 우측 상단 DEBUG 배너 숨김
      theme: ThemeData(
        // 앱 전체 색상 테마를 파란색 계열로 설정
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const WebViewPage(), // 앱 시작시 보여줄 첫 화면
    );
  }
}

// 실제 WebView 화면을 담당하는 위젯
// StatefulWidget = 상태가 있는 위젯 (로딩 상태가 변하기 때문에 사용)
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

// WebViewPage의 실제 동작을 구현하는 클래스
class _WebViewPageState extends State<WebViewPage> {
  // WebView를 제어하는 컨트롤러 (나중에 초기화됨)
  late final WebViewController _controller;
  // 로딩 중인지 여부 (true = 로딩중, false = 로딩완료)
  bool _isLoading = true;

  // Flutter ↔ Android 통신 채널 (이름이 Kotlin쪽이랑 똑같아야 함)
  static const MethodChannel _channel = MethodChannel('file_picker_channel');

  @override
  void initState() {
    super.initState();

    // 플랫폼별 User-Agent 설정
    // iOS는 Safari, Android는 Chrome 브라우저인 척 해서 웹사이트가 모바일 버전으로 응답하게 함
    final String userAgent = Platform.isIOS
        ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
        : 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36';

    // WebViewController 초기화 및 설정
    _controller = WebViewController()
      // JavaScript 완전 허용 (웹사이트 정상 동작을 위해 필요)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 플랫폼에 맞는 User-Agent 설정
      ..setUserAgent(userAgent)
      // 페이지 로딩 관련 이벤트 처리
      ..setNavigationDelegate(
        NavigationDelegate(
          // 페이지 로딩 완료시 로딩 스피너 숨기기
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          // 페이지 로딩 오류시도 로딩 스피너 숨기기
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      // 열고 싶은 웹사이트 URL 로드
      ..loadRequest(Uri.parse('https://securemachineslab.com:25000/'));

    // Android 플랫폼인지 확인 후 파일 업로드 설정
    if (Platform.isAndroid && _controller.platform is AndroidWebViewController) {
      // 디버깅 모드 활성화 (개발 중 오류 확인용)
      AndroidWebViewController.enableDebugging(true);
      // 파일 선택 버튼 클릭시 _androidFilePicker 함수 호출하도록 연결
      (_controller.platform as AndroidWebViewController)
          .setOnShowFileSelector(_androidFilePicker);
    }
  }

  // 파일 선택창을 여는 함수 (Android 전용)
  // FileSelectorParams = 어떤 파일 타입을 받을지 정보 (이미지/비디오 등)
  // Future<List<String>> = 선택된 파일 경로 목록을 비동기로 반환
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      // Kotlin쪽에 'pickFile' 신호 보내고 선택된 파일 경로 받아오기
      final List<dynamic>? result = await _channel.invokeMethod('pickFile', {
        'acceptTypes': params.acceptTypes, // 허용할 파일 타입 전달
      });
      // 결과를 String 리스트로 변환해서 반환 (없으면 빈 리스트)
      return result?.cast<String>() ?? [];
    } catch (e) {
      // 오류 발생시 빈 리스트 반환
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // 노치, 상태바 등 피해서 안전하게 배치
        child: Stack( // 여러 위젯을 겹쳐서 표시
          children: [
            // WebView 화면 (웹사이트가 보이는 부분)
            WebViewWidget(controller: _controller),
            // 로딩 중일때만 파란 빙글빙글 스피너 표시
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}