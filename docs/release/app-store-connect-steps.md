# App Store Connect 입력 순서

App Store Connect에 CardVoca iOS 앱 레코드를 생성했다. Apple ID는 `6831607066`, Bundle ID는 `com.grobiann.voca-ios`, SKU는 `cardvoca-ios-1`, 기본 언어는 한국어다. Apple Developer 웹 계정에서 확인한 유료 `JinSeok Jang` 팀 ID는 `JJU73FFK92`이다. 이전에 전달된 `XJDGH6TDX4`와 달라 프로젝트를 실제 앱 등록 팀으로 맞췄다. 버전 1.0의 설명·키워드·지원 URL·저작권·심사 메모를 저장했고, 심사 승인 후 수동 출시로 설정했다. 계정 소유자가 업데이트된 Apple Developer Program 계약에 동의했다고 확인했다.

1. 완료: 명시적 App ID `com.grobiann.voca-ios` 확인, Xcode 팀 일치, [App Store Connect 앱 레코드](https://appstoreconnect.apple.com/apps/6831607066/distribution/ios/version/inflight) 생성.
2. 완료: 계정 소유자가 업데이트된 Apple Developer Program 계약을 직접 검토·동의했다. 비밀번호나 인증 코드는 저장소·채팅에 남기지 않는다.
3. 완료: 교육 카테고리, 무료 가격, 대한민국 제공, 부제와 개인정보 URL을 저장했다. 버전 메타데이터는 [스토어 문구 초안](store-metadata.md)을 기준으로 저장했다.
4. 최신 스크린샷 후보: iPhone `01-Learn-6.9.jpg`, `02-Card-Front-6.9.jpg`, `03-Card-Back-6.9.jpg`, `04-Library-6.9.jpg`; iPad `06-iPad-13.jpg`. 경로는 `screenshots/` 아래다. 모두 알파 없는 Apple 규격 크기이며, 제3자 상표가 보이는 `05-Library-Detail-6.9.jpg`는 제외한다.
5. App Privacy 설문에서 앱의 로컬 학습 기록과 외부 Google Form 제출 흐름을 구분해 답한다. Form은 확인된 이메일·라이브러리 이름·설명·시트 링크·선택한 닉네임을 운영자가 받는다. 외부 검색은 사용자가 누를 때 해당 사이트로 검색어를 보낸다. 이 정보가 Apple의 수집 정의에 어떻게 분류되는지 최종 검토한다. [App Privacy 안내](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
6. 연령 등급 설문, 암호화 질문(앱은 비면제 암호화 미사용), 심사 연락처를 입력한다. [심사 메모](store-metadata.md)를 붙인다. 외부 공개 시트와 Form이 심사 시 열리는지 확인한다.
7. 완료: 실제 팀 ID `JJU73FFK92`로 서명된 Release Archive `/private/tmp/CardVoca-1.0-signed.xcarchive`를 만들고 App Store용 IPA로 내보냈다. 첫 업로드에서 `VocaCore.framework`의 버전 키 누락이 검출되어 프로젝트에 버전 `1.0`을 추가한 뒤 새 Archive로 재업로드했다. 2026-11-06 Xcode가 App Store Connect 업로드 성공과 빌드 처리 시작을 보고했다. TestFlight 목록에 빌드 `1.0 (1)`이 표시되는지 확인한 후 실기기에서 학습·시트 가져오기·공개 목록·Form·검색을 검증한다.
8. TestFlight 결과를 검토한 뒤 심사 제출과 출시를 결정한다. 제출 전 단어 데이터의 출처·라이선스와 자동번역의 정확성을 다시 확인한다.

스토어 제출용 지원 및 개인정보 페이지는 `gh-pages` 브랜치에 게시되어 있다. 정책 내용이 바뀌면 공개 페이지와 앱의 안내를 함께 갱신한다.
