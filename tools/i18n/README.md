# English translation pipeline — school content

The pipeline is: `build_work.dart` → translate the work files → `validate.dart`
→ `merge.dart` (→ `verify.dart`). Shipped results are
`data/i18n/en/titles.json`, `data/i18n/en/outlines.json`, and
`data/srt_en/*.srt`; the app falls back to Vietnamese when a key is missing.

Generated work files and diagnostics are written to `data/i18n/work/`,
`data/i18n/validation-*.txt`, `data/i18n/inspect-*.txt`, and
`data/i18n/dump-*.txt` and are git-ignored, because they can be recreated from
the source data. Only the tooling in this folder and the shipped results are
committed.

---

# Translation instructions — school content

The work files described here cover the school app's **titles, outlines and
subtitles**, generated into `data/i18n/work/` (git-ignored). All data is from
`data/json/` and `data/srt/`.

| Folder | Files | Contents |
|---|---:|---|
| `titles.json` | 1 | 150 lesson titles |
| `outlines/part-*.json` | 3 | 871 section headings, grouped by lesson |
| `subtitles/part-*.json` | 44 | 7,098 cues from 751 videos |

Each file is already filled with Vietnamese. Replace the Vietnamese with
American English; keep every key and the exact shape.

The finished sidecars (`data/i18n/en/titles.json`,
`data/i18n/en/outlines.json`, `data/srt_en/*.srt`) are generated later from
these files — do not edit those by hand.

**Not included:** 7 segments have no Vietnamese SRT (`TVL2KB07_07`,
`TVL2KB12_01`…`TVL2KB12_05`, `TVL5KB07_05`), and 2 unused SRTs were skipped
(`TVL4KB04_04`, `TVL5KB06_06`). No action needed.

---

## How to run one file

1. Open a fresh chat (or a new message in the same chat) with the AI.
2. Paste the matching prompt below.
3. Attach or paste **one** file.
4. Save the AI's JSON answer over the same file (UTF-8, no BOM).
5. Continue.

Feed order: `titles.json` → `outlines/part-01..03` → `subtitles/part-01..44`.
If an answer is cut off, reply `continue from the last complete key` and append
the rest.

---

## Glossary (use consistently)

| Vietnamese | English |
|---|---|
| Toán (subject) | **Math** |
| Tiếng Việt (subject label) | **Literature** |
| tiếng Việt (the language, in speech) | Vietnamese |
| lớp / Lớp 1 | Grade / Grade 1 |
| bài / Bài 1 | Lesson / Lesson 1 |
| Ký hiệu Việt Nam | Vietnamese Sign Language (VSL) |
| phép cộng / phép trừ | addition / subtraction |
| so sánh | compare |
| đếm / đọc / viết | count / read / write |
| trong phạm vi 10 | within 10 |
| dấu >, <, = | greater-than, less-than, equals sign |
| số / chữ số | number / digit |
| hình | shape |
| đoạn thẳng / góc | line segment / angle |
| chu vi / diện tích | perimeter / area |
| phân số / hỗn số | fraction / mixed number |
| luyện tập / ôn tập | practice / review |
| ví dụ / bài giải | example / solution |
| tập đọc / chính tả | reading / spelling |
| kể chuyện / tập làm văn | storytelling / writing |
| dấu thanh / vần / âm | tone mark / rhyme / sound |

---

## Prompt A — lesson titles (`titles.json`)

```text
You are translating Vietnamese primary-school lesson titles into American
English.

The attached JSON is a map: lesson id -> Vietnamese title. Replace each value
with an English title.

RULES
1. Output the same JSON object: same keys, same order, same number of entries.
2. Never translate keys, ids, or the "_note" field.
3. Use Title Case: "Numbers within 10", "Comparing Numbers within 100".
4. Keep it short and natural. No trailing period. Do not add "Lesson" unless the
   Vietnamese has "Bài".
5. American English. Use "Math" for Toán and "Literature" for Tiếng Việt when it
   is the subject name. "lớp" -> "Grade"; keep numbers ("Lớp 1" -> "Grade 1").
6. Keep names of people and places in Vietnamese.
7. Output valid JSON only. No markdown fences, no explanations.
```

---

## Prompt B — lesson outlines (`outlines/part-*.json`)

```text
You are translating Vietnamese primary-school lesson outlines into American
English.

The attached JSON is a map: lesson id -> an ordered array of section headings.
Replace every heading with English.

RULES
1. Output the same JSON object: same keys, same order, same number of lessons.
2. Every array must keep its exact length and order. Do not add, remove, merge
   or split headings.
3. Keep the leading numbering exactly as written: "2.", "2.1.", "a.", "III.".
   Translate only the text after it.
4. Use sentence case after the number: "2. Numbers 0–5", "2.1. Comparing two
   numbers".
5. American English. Use "Math" for Toán and "Literature" for Tiếng Việt as a
   subject name; translate "tiếng Việt" as "Vietnamese" when it means the
   language.
6. Keep numbers, symbols (>, <, =, +, -), and names of people and places.
7. Never translate keys, ids, or the "_note" field.
8. Output valid JSON only. No markdown fences, no explanations.
```

---

## Prompt C — subtitles (`subtitles/part-*.json`)

```text
You are translating Vietnamese primary-school lesson subtitles into American
English.

The attached JSON is a map: video name -> { cue number: Vietnamese text }.
Replace every cue text with English.

RULES
1. Output the same JSON object: same video keys, same cue numbers, same order,
   same number of cues. Do not add, remove or renumber anything.
2. Never translate keys, video names, cue numbers, or the "_note" field.
3. These are spoken classroom lines. Use short, natural, present-tense American
   English ("Let's count together", "Look at the picture").
4. Translate meaning, not word for word. Keep the teacher's tone. Do not add
   information or explanations. Keep each line about as long as the Vietnamese;
   shorter is better.
5. Keep digits and symbols exactly: "0, 1, 2, 3, 4, 5" stays the same. Keep
   names of people and places in Vietnamese.
6. Keep inline tags in place: <i>, </i>, <b>, </b>, <sup>, </sup>,
   <color=orange>, </color>. Translate only the words around them.
7. No period at the end unless the Vietnamese has one. Use a question mark for
   questions.
8. "Toán" -> "Math"; "Tiếng Việt" -> "Vietnamese" (the language). The subject
   label "Literature" is not used in subtitles.
9. Output valid JSON only. No markdown fences, no explanations.
```

---

## Check before moving on

- [ ] Same keys and same item count as the input.
- [ ] Outlines: every array length unchanged; leading numbers intact.
- [ ] Subtitles: digits and `<tags>` preserved.
- [ ] No Vietnamese left, except proper names.
