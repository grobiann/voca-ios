# 첫 공개 출시 점검표

2026-11-07 저장소 및 App Store Connect 기준. 1.0(2)가 심사 대기 중이다. 승인 후 수동 출시한다.

## 구현 및 정리

- [x] 알림 설정, 테스트 알림, 예약기, 알림 진입 경로 제거.
- [x] App Intents/단축어 및 폐기된 1-3-3 학습 동작 제거.
- [x] 시간 민감 알림 entitlement 및 AlarmKit 권한 설명 제거.
- [x] 기존 설치에서 예약된 로컬 알림·배지를 정리. 이미 권한이 있는 과거 AlarmKit 알람만 취소. 권한 요청·신규 예약은 없음.
- [x] 사용하지 않는 TTS 코드 제거.
- [x] 로그인 기능이 없는 계정 탭을 설정으로 변경.
- [x] 앱 내 개인정보 안내 및 데이터 출처·라이선스 화면 추가.
- [x] UserDefaults 앱 자체 설정 저장 목적(CA92.1) PrivacyInfo.xcprivacy 추가 및 앱 리소스 등록.
- [x] 비면제 암호화 미사용 선언. 현재 네트워크는 OS HTTPS 기능만 사용한다.
- [x] 이전 저장 파일 호환을 위해 과거 1-3-3 데이터 필드는 보존. 새 학습 동작은 없음.
- [x] 가짜 서버 게시 버튼과 동작 제거. 공개 Google Sheets 목록과 Google Form 신청 방식으로 대체. AWS 배포 설정은 제거.
- [x] CardVoca / 운영자 장진석 / 지원 grobiann0@gmail.com. 무료·한국 우선 출시.
- [x] GitHub Pages 활성화 및 gh-pages에 개인정보·지원 페이지 게시.
  - https://grobiann.github.io/voca-ios/privacy.html
  - https://grobiann.github.io/voca-ios/support.html
- [x] App Store Connect App Privacy 게시. Google Form 신청의 이메일 주소와 신청 내용을 앱 기능 목적으로 신고하고 신원 연결·추적 없음 여부를 설정. 앱 코드에 광고/분석/추적 SDK 없음.

## 검증

- [x] 핵심 모델 테스트 22개 통과(알림 동작 테스트 제거 후).
- [x] Release 시뮬레이터 빌드 통과.
- [x] iPhone 현재 UI에 맞춘 회귀 테스트(9개 통과): 학습, 반복 학습 승급, 검색 항목 삭제, 제보 수정, 스택 제거, 라이브러리 등록, 저장 후 재시작.
- [ ] iOS 17 및 최신 iOS 실기기: 작은 화면, 큰 글자, VoiceOver, 동작 줄이기, 다크 모드.
- [x] iPad 시뮬레이터 설정·학습·가로 회전 테스트 2개 통과. iPad 회전 메타데이터 수정. 실기기 검증은 남음.
- [ ] 기존 버전에서 업데이트 후 학습 이력·수정·제외 카드·반복 학습 완료 목록 유지 확인.
- [ ] 이전 예약 알림 취소 및 권한 팝업이 없는지 실기기 확인.
- [x] 공개 Google Sheets 실제 가져오기 → 스택 등록 → 학습 풀 검증 통과. 원본 시트 수정 없음.
- [x] JLPT CSV 7,811개 필수 값 및 카드 ID 중복 검사 통과(뜻의 정확성 검수와 다름).
- [ ] 비공개 시트 거부·네트워크 단절·긴 단어·다량의 검색 버튼은 추가 수동 검증 필요.
- [ ] 최신 공개 시트 데이터 전수 전문 검수. 자동번역 미검수 사실 명시, 공식 JLPT 전체 출제 목록으로 광고하지 않음.

## 제출과 운영

- [x] 공개 앱 이름, 부제, 설명, 키워드, 카테고리, 가격 및 출시 국가 초안 작성.
- [x] Apple Developer Program/계약, App Store Connect 앱 레코드 및 Bundle ID 확인.
- [x] 실기기용 Release 무서명 Archive 생성 및 개인정보 매니페스트 포함 확인.
- [x] 배포 서명 Archive → App Store Connect 업로드. 1.0(2)은 검증·심사 제출 완료.
- [x] 버전 1.0 / 빌드 2로 증가.
- [x] 앱 아이콘 1024×1024, 알파 없음. iPhone 현재 UI 캡처 6장 및 iPad 가로 캡처 1장 준비(docs/release/screenshots).
- [x] 최신 Release 빌드의 iPhone 6.9인치·iPad 13인치 스크린샷 후보 촬영. 알파 없는 JPG와 규격 확인. 제출 전 내용 최종 확인.
- [x] 연령 등급 설문 완료(13+), 개인정보 답변 게시, 암호화 미사용 선언.
- [x] 심사 연락처, 공개 지원 URL 및 개인정보 URL 등록. 로그인 없이 학습 가능하다는 심사 메모 작성.
- [ ] 데이터 출처·CC BY-SA 변경 고지 및 재배포 조건 유지.
- [ ] EU 배포 시 해당되는 trader 정보/지역 의무 확인. 유료일 경우 세금·은행·계약 설정 확인.
- [x] App Store 심사 제출: `4b302660-6f09-4e74-a9d5-749bd23a79c1` (2026-11-07 02:14 KST).
- [ ] Apple 승인 후 사용자가 App Store Connect의 수동 출시 버튼을 누른다. 실기기 TestFlight 검증은 별도 권장 품질 점검.

## 기준 문서

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/

## 공개 라이브러리 (2026-11-06)

- [x] 공개 목록: Google Sheets의 그룹 이름·링크·TRUE/FALSE 상태·설명·닉네임.
- [x] Google Form 신청: 기존 시트에 응답 저장, 새 응답 이메일 알림, 계정당 1회 제한.
- [x] 앱 둘러보기: TRUE 행만 표시하고 그룹 선택 시 설명·등록자 표시.
- [x] 핵심 모델 테스트 28개 및 Debug 시뮬레이터 빌드 통과.
- [x] 라이브러리·덱 용어와 새 학습 설정을 반영한 iPhone/iPad 스크린샷 다시 촬영·업로드.
- [x] 공개 파일에 문장 예시 덱 추가, 언어 코드 열 및 기존 card_id 공개 CSV 확인.
- [x] App Store Connect 로그인, 앱 레코드, 팀·배포 인증서 확인 후 서명 Archive 업로드.
- [x] GitHub Pages의 개인정보·지원 페이지를 현재 내용으로 갱신하고 공개 URL 반영 확인.
