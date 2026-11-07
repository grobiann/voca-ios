# App Review 2.1 응답 준비

심사 요청: 2026-11-07, CardVoca 1.0 (build 2). 이 요청은 TestFlight 테스터 초대 여부가 아니라 심사 정보의 누락에 관한 것이다. 새 바이너리를 요구하는 버그 지적은 없다.

## App Store Connect → App Review Information → Notes

아래 영문을 붙여 넣고, **실기기 녹화 파일을 첨부한 후** 다시 제출한다. 녹화 파일명과 iOS 버전은 실제 파일에 맞춰 확인한다.

```text
CardVoca 1.0 (build 2) — response to Guideline 2.1

1. Physical-device recording: Please see the attached CardVoca app demonstration, recorded on an iPhone running the latest available iOS. It begins with launching the app and shows the normal study flow, card flip, retry/known swipes, adding a word to repetition study, repetition study, browsing a public library, and adding a deck's stack. The app has no in-app account, account deletion, paid features, or automatic publication of user content, so there are no such flows to demonstrate.

2. Purpose and audience: CardVoca is a free Japanese vocabulary flashcard app for Korean-speaking individual learners. It helps learners retain words by keeping an active study pool, revisiting unknown cards, and optionally moving selected words through repetition-study stages. It also offers a kana-only study mode. It is a general consumer education app, not restricted to any business or organization.

3. Access and test instructions: No account, login, credentials, subscription, or sample-file upload is needed. Launch the app, open the Study tab, tap the main study button, tap a card to reveal the answer, then swipe left for retry or right for known. Use the button on a study card to add a word to repetition study; start repetition study from the Study tab. In Library > Browse, select a public library, choose a deck, and add a stack to My Stacks. The built-in grouped-word cards can be studied offline. A public read-only example of a Google Sheets library is https://docs.google.com/spreadsheets/d/1CZiD8VuxZ6iqrMeBGREO-MAhStjL-dOIJQsj2SiP-Q4/edit . Importing a user's own sheet is optional and requires a publicly readable Google Sheets link with columns stack, card_id, ja-JP, reading, and ko-KR. The optional request to list a library opens an external Google Form; it is not required for studying.

4. External services: Google Sheets supplies the operator-reviewed public library catalog and optional read-only library imports. Google Forms receives optional library listing requests, which the operator reviews manually before publication. A user-initiated search opens the selected external search website in a browser. There is no app account provider, developer-operated backend, runtime AI service, advertising SDK, or payment processor. Study progress and error reports are stored on the device unless the user explicitly shares a report.

5. Regions: The initial App Store release is in South Korea. The same app features and content are available to all users in that storefront. The interface is in Korean and the study content is Japanese/Korean. Internet access is needed for Google Sheets and optional external searches, but not for the bundled grouped-word cards.

6. Rights and regulation: This is an education app, not a regulated service. The JLPT vocabulary library is an unofficial community dataset derived from OpenJLPT under CC BY-SA 4.0, with source attribution, license link, and changes disclosed in the app under Settings > Data Sources and License. OpenJLPT source/notice: https://github.com/evanclan/OpenJLPT/blob/main/NOTICE.md . CardVoca's dataset and attribution details: https://github.com/grobiann/voca-ios/blob/main/Data/JLPT/README.md . Japanese exam authorities do not publish an official complete level-by-level vocabulary list; the app does not claim official JLPT endorsement. Other public libraries are added to the catalog only after operator review; users cannot directly publish content to all users from the app.
```

## 실기기 녹화 및 검증

1. 실제 iPhone을 최신 공개 iOS로 업데이트하고, App Store에 제출한 **동일한 1.0 (2) 빌드**를 TestFlight에서 설치한다. 설정 → 일반 → 정보에서 iOS 버전을 확인한다.
2. iPhone 화면 기록을 켠 다음 홈 화면에서 CardVoca를 실행한다. 첫 실행 화면부터 학습 시작, 카드 탭, 좌우 스와이프, 반복 학습에 담기, 반복 학습 시작, 라이브러리 둘러보기, 덱과 스택 추가를 한 흐름으로 보여준다. 비밀번호·개인 시트 링크·민감한 알림은 녹화에 넣지 않는다.
3. 녹화한 `.mov`를 Mac에 전달하고, App Store Connect의 App Review Information 파일 첨부에 올린다. Notes의 기기/OS/빌드 설명을 실제 녹화와 맞춘다.
4. 같은 실기기에서 앱 재실행, 학습 진행 저장, 라이브러리 열기, 네트워크가 없을 때 기본 카드 학습, 카드 답변 후 크래시 여부를 확인한다.
5. Notes 저장과 첨부 파일이 App Store Connect에 표시되는지 확인한 뒤 심사에 다시 제출한다. 승인 후 수동 출시 설정은 유지한다.

## 심사 질의 응답

심사팀이 동일한 질문을 메시지로 남겼다면, Notes 및 영상 첨부 후 App Store Connect의 심사 메시지에 아래처럼 답한다.

```text
Thank you for the review. We have updated the App Review Information notes with the app's purpose, access steps, external services, regional availability, and content rights. We have also attached a physical-device screen recording of build 1.0 (2) showing the typical user flow. No account or payment is required to use the app. Please continue the review.
```
