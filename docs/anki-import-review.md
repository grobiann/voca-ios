# JLPT 갤러리 공유 자료 가져오기

원본은 [JLPT 갤러리 공유 글](https://gall.dcinside.com/mgallery/board/view/?id=jlpt&no=70170)에서 받은 `.apkg` 파일입니다. `.apkg`는 파일 형식이며, 자료 출처를 뜻하지 않습니다. 이 문서는 파일 구조와 카드 수만 정리합니다. 이미지·음성·긴 설명은 가져오지 않았습니다.

| 원본 파일 | 노트 수 | 대표 입력 필드 |
|---|---:|---|
| [日本語__Core 2k_6k Vocabulary.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__Core 2k_6k Vocabulary.apkg>) | 5,999 | Vocabulary-Kanji, Vocabulary-Kana, Vocabulary-English, Expression, Reading |
| [日本語__JLPT 한끝 Voca.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__JLPT 한끝 Voca.apkg>) | 3,734 | kanji, kana, meaning |
| [日本語__NHK Easy Japanese.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__NHK Easy Japanese.apkg>) | 555 | Expression, Meaning |
| [日本語__일본어 무작정 따라하기__(2020) 완전판 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__일본어 무작정 따라하기__(2020) 완전판 단어장.apkg>) | 583 | Kanji, Meaning |
| [日本語__일본어 무작정 따라하기__(2020) 완전판 문형.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__일본어 무작정 따라하기__(2020) 완전판 문형.apkg>) | 1,417 | Expression, Meaning, Reading |
| [日本語__일본어 문법 무작정 따라하기__(2020) 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__일본어 문법 무작정 따라하기__(2020) 단어장.apkg>) | 2,229 | Kanji, Meaning, furigana |
| [日本語__일본어 문법 무작정 따라하기__(2023) 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__일본어 문법 무작정 따라하기__(2023) 단어장.apkg>) | 2,319 | Kanji, Meaning, furigana |
| [日本語__常用漢字.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__常用漢字.apkg>) | 2,647 | Expression, Meaning |
| [日本語__毎日の日本語文法.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/日本語__毎日の日本語文法.apkg>) | 4,969 | grammar_title, meaning, sentence_title |

## 입력 형식 제안

- 필수: `stack`, `ja-JP`, `ko-KR`
- 선택: `ja-JP-reading`, `en-US`, `card_id`, `type`
- Anki의 원본 note ID는 `card_id`로 사용할 수 있습니다. 앱이 파일·시트별로 범위를 묶어 충돌을 막습니다.
- 9개 파일을 각각 별도의 Google Sheets 파일로 만들고 공개 목록에 등록했습니다. 모든 탭의 공개 CSV를 읽어 필수 열과 카드 종류를 확인했습니다.
- Core 2k/6k의 영어 뜻은 `en-US`에 보존하고, `ko-KR`은 Google Sheets 자동 번역으로 채웠습니다. 번역 품질은 원본 한국어 뜻과 다를 수 있습니다.
- 파일명에 등장하는 출판사·방송사 명칭은 자료 내용에 대한 권리나 제휴를 보증하지 않습니다.

## 공개 Google Sheets

| 자료 | 카드 수 | 링크 |
|---|---:|---|
| Core 2k/6k 어휘 | 5,999 | [열기](https://docs.google.com/spreadsheets/d/1SCraTquMAANf5bfIY5VmsUFIfL5yQRzvp9ZJmJH3nCQ/edit) |
| JLPT 한끝 어휘 | 3,734 | [열기](https://docs.google.com/spreadsheets/d/1fgUwzPDGwfnFhm901Wj5tvsHysVpbWnoKiNrSfGqR98/edit) |
| NHK Easy Japanese | 555 | [열기](https://docs.google.com/spreadsheets/d/12IhkjnlVdozvsACebAr7bLHU-3g1XBaf7LBUUUtbUDk/edit) |
| 일본어 무작정 따라하기 완전판 단어장 | 583 | [열기](https://docs.google.com/spreadsheets/d/18hTFCSk4DAsQ1kXszPa4XACLARLIF9jO2d4uLpV7TMc/edit) |
| 일본어 무작정 따라하기 완전판 문형 | 1,417 | [열기](https://docs.google.com/spreadsheets/d/1RVk9YWHQPHwes4sdHBs8GmVFn1ZgpxA_K0Oei2hZ5no/edit) |
| 일본어 문법 무작정 따라하기 2020 | 2,229 | [열기](https://docs.google.com/spreadsheets/d/1XDHn2clx7IumjcpK83cj0Accupullpy3tKNNDXeD98o/edit) |
| 일본어 문법 무작정 따라하기 2023 | 2,319 | [열기](https://docs.google.com/spreadsheets/d/1jTMP-KjqiYNY91xaoeUGL5hDTad6mx4TcPRPv2jj7PI/edit) |
| 일본어 상용한자 | 2,323 | [열기](https://docs.google.com/spreadsheets/d/1PpiBiBTy7gToz-t-WBwg-BaGD-NmUkBbDPpM-KT5aU0/edit) |
| 매일의 일본어 문법 | 4,969 | [열기](https://docs.google.com/spreadsheets/d/13y_OVTqcElpy0J4SC7dz8Uzur5xY1DI6Ogy572kRzd0/edit) |

## Archive 폴더의 이전 파일

아래 4개는 별도 보관된 이전 버전으로 보이며, 위 목록과 중복 가능성이 있어 공개 자료로 처리하지 않았습니다.

- [(2020) 일본어 문법 무작정 따라하기 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/Archive/(2020) 일본어 문법 무작정 따라하기 단어장.apkg>)
- [(2022) 일본어 무작정 따라하기 완전판 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/Archive/(2022) 일본어 무작정 따라하기 완전판 단어장.apkg>)
- [(2023) 일본어 문법 무작정 따라하기 단어장.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/Archive/(2023) 일본어 문법 무작정 따라하기 단어장.apkg>)
- [일본어 상용한자 무작정 따라하기.apkg](</Users/jinseok/Downloads/JLPT Anki Decks/Archive/일본어 상용한자 무작정 따라하기.apkg>)
