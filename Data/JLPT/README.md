# JLPT 단어장 데이터

[Google Sheets 단어장](https://docs.google.com/spreadsheets/d/1CZiD8VuxZ6iqrMeBGREO-MAhStjL-dOIJQsj2SiP-Q4/edit)의 단어 데이터를 2026-10-25에 예문 없이 갱신한 CSV 백업이다. 앱 바이너리에 자동 포함되지 않는다. Google Sheets 또는 CSV로 가져온다.

같은 Google 파일의 [‘묶어서 외우는 일본어’ 탭](https://docs.google.com/spreadsheets/d/1CZiD8VuxZ6iqrMeBGREO-MAhStjL-dOIJQsj2SiP-Q4/edit?gid=2026102501)은 별도의 라이브러리이며, 아래 JLPT 합계에는 포함하지 않는다.

| 시트 | 단어 항목 | 스택 (최대 20단어) |
| --- | ---: | ---: |
| N5 | 674 | 34 |
| N4 | 630 | 32 |
| N3 | 1,659 | 83 |
| N2 | 1,778 | 89 |
| N1 | 3,070 | 154 |
| 합계 | 7,811 | 392 |

## 범위와 품질

OpenJLPT 커밋 `0d1d3410bec90bd4098a7c72de820543cb4f707c`의 `data/json/vocab/n5.json`부터 `n1.json`까지 모든 항목을 포함한다. 급수별 목록은 비공식 분류이고, 공식 시험의 모든 출제 단어를 보장하지 않는다. 동형이의어나 다른 읽기를 가진 항목은 원본 ID 그대로 유지한다.

- `korean`: 원본 영어 뜻을 Google Sheets의 GOOGLETRANSLATE로 한국어 번역한 후 값으로 저장했다. 표본에서 발견한 34개 뜻은 AI가 교정했다. 전체 전문 검수는 하지 않았으며 다의어, 품사, 문맥 및 원본 영어의 오류가 반영될 수 있다.
- 예문, 예문 출처, 예문 상태 열은 제거했다. `translation_status`로 한국어 뜻의 검수 상태를 표시한다.
- 자동번역은 학습용 최종 사전이 아니다. 의심되는 뜻은 일본어 사전과 대조해 시트에서 수정한 뒤 가져온다.

## 출처와 라이선스

Contains data from [OpenJLPT](https://github.com/evanclan/OpenJLPT), which uses [Jonathan Waller's JLPT lists](https://www.tanos.co.uk/jlpt/) and [JMdict / EDRDG](https://www.edrdg.org/jmdict/j_jmdict.html). 예문은 이 백업에 포함되지 않는다. [원본 데이터의 상세 출처](UPSTREAM-NOTICE.md).

이 파생 데이터셋은 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)이다. 변경 사항: 한국어 자동번역 및 34개 뜻 교정, 스택 분할, 앱용 CSV 필드 추가, 예문 관련 열 제거. 저장소 루트의 앱 코드 라이선스와 구분한다. 후속 배포에서도 이 출처·라이선스·변경 내역을 유지한다.

## 열 형식

`stack_id,stack,card_id,japanese,reading,korean,english,translation_status,source,license`

한 행이 한 단어다. 같은 `stack_id`를 가진 행들을 하나의 스택으로 묶는다. `stack`은 표시 이름이며, 이름이 같아도 ID가 다르면 별도 스택이다. `card_id`는 원본의 안정적인 ID다. 재가져오기 시 해당 파일/탭의 라이브러리를 갱신하며, 이미 내 학습 목록에 등록한 사본과 학습 진행은 유지한다.
