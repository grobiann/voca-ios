# voca-ios

일본어를 한국어로 학습하는 개인용 SwiftUI iOS 앱. iOS 17 이상, 외부 패키지 의존성 없음.

## 실행

1. `voca-ios.xcodeproj`를 Xcode에서 연다.
2. `voca-ios` scheme과 iPhone 시뮬레이터를 선택하고 Run.
3. 실제 iPhone에서는 Signing & Capabilities에서 본인의 Apple 개발 팀을 선택한다. Bundle Identifier는 필요하면 본인 값으로 변경한다.

프로젝트 파일이 포함되어 있어 XcodeGen 설치 없이 실행할 수 있다. 프로젝트 설정 변경 후 재생성하려면 `xcodegen generate`를 실행한다.

## 기능

- **학습**: 스택 생성, 카드 추가/삭제, 양방향 카드, 진행률 저장, 완료 후 재학습.
- 앞면은 일본어와 예문, 뒷면은 한국어 뜻을 강조한다. 한국어→일본어 방향에서는 정답을 노출하지 않도록 일본어 예문과 음성을 뒷면에서 제공한다.
- 뒷면에서만 좌우 스와이프 가능. 손가락 추적, 회전, 속도 기반 판정, 스프링 복귀, 판정 배지, 햅틱과 버튼 대안 제공. 시스템 동작 줄이기 설정을 반영한다.
- 모르는 방향은 최대 세 장 뒤에 다시 등장한다. 모든 단어의 양방향을 맞히면 스택 완료. 직전 응답 한 번 취소 가능.
- **라이브러리**: 직접 생성, 스택/카드 구성, JSON/CSV/Google Sheets 가져오기, 스택별 내 학습 목록에 복사, 중복 등록 방지.
- **가짜 서버**: 업로드한 라이브러리를 기기 내 별도 목록에 보관하고 둘러보기에 표시한다. 동일 라이브러리 재업로드는 해당 서버 사본을 갱신한다. 다른 기기에는 전송하지 않는다.
- **계정**: 언어/완료 기준 표시, 햅틱 설정. 로그인·결제·구독은 미구현이며 이를 화면에 명시한다.
- 일본어 음성은 iOS의 AVSpeechSynthesizer 사용. 음성 가용성은 기기 설정에 따라 달라진다.

## 가져오기

[JSON 예제](Samples/japanese.json), [CSV 예제](Samples/japanese.csv)를 참고한다.

JSON:
```json
{
  "title": "여행 일본어",
  "stacks": [{
    "title": "카페에서",
    "cards": [{
      "japanese": "おすすめ",
      "korean": "추천",
      "example": "おすすめは何ですか。"
    }]
  }]
}
```

CSV는 UTF-8, 필수 헤더 `japanese,korean,example`, 선택 헤더 `stack`을 사용한다. `stack` 값별로 그룹화한다. 쉼표, 줄바꿈, 따옴표를 포함한 필드는 표준 CSV 따옴표 규칙을 따른다. 모든 카드 필드는 필수이며 잘못된 파일은 전체 가져오기를 거부한다.

Google Sheets는 같은 열 구성을 사용한다. ‘링크가 있는 모든 사용자: 뷰어’로 공유하거나 웹에 게시한 시트 링크를 라이브러리 > 만들기 또는 가져오기 > Google Sheets 링크에 입력한다. 일반 편집 링크와 게시 링크를 지원하며 `gid`로 선택한 탭을 가져온다. 로그인 전용 시트와 자동 동기화는 지원하지 않는다. 공개 시트의 실제 네트워크 가져오기는 사용자 시트로 추가 검증이 필요하다.

## 저장과 구조

- `Sources/VocaCore`: Codable 모델, 학습 큐, CSV/JSON 검증, 시트 URL 변환. 향후 서버 교체 시 UI와 분리해서 재사용할 수 있다.
- `VocaApp`: SwiftUI 화면, 로컬 저장, TTS, Google Sheets 다운로드.
- `Tests`: Foundation 기반 핵심 로직 테스트.
- `UITests`: 시뮬레이터의 스와이프/되돌리기/라이브러리 등록 테스트.

앱 Documents의 `voca-data.json`에 원자적으로 저장한다. 학습 목록과 라이브러리는 독립 사본이며 원본 라이브러리 변경은 이미 등록한 스택에 자동 반영하지 않는다. 학습 언어는 현재 일본어/한국어 고정이며, 다른 언어를 제공하려면 모델 필드와 UI 설정을 확장해야 한다. 앱 삭제 시 로컬 데이터가 없어질 수 있다.

## 검증

```sh
swift test
xcodebuild -project voca-ios.xcodeproj -scheme voca-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

UI 테스트의 `--uitesting` 인자는 Debug에서만 별도 임시 저장 파일을 사용한다. 일반 사용자 저장 파일은 변경하지 않는다.

## 화면 미리보기

| 학습 | 카드 뒷면 | 라이브러리 |
| --- | --- | --- |
| ![학습](docs/screenshots/learn.png) | ![카드](docs/screenshots/study.png) | ![라이브러리](docs/screenshots/library.png) |
