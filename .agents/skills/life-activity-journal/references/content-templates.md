# Content templates

All fields except `date`, `kind`, and `title` are optional. Keep writing concise and omit empty fields.

## 运动 (`sport`)

Use for swimming, running, walking, cycling, strength training, and similar activity.

Preferred metrics, maximum 5:

1. Distance
2. Duration
3. Active calories
4. Average pace
5. Activity type or stroke

Example:

```json
{
  "date": "2026-07-16",
  "kind": "sport",
  "title": "泳池游泳",
  "emoji": "🏊",
  "metrics": [
    {"value": "1,000 米", "label": "距离"},
    {"value": "33:23", "label": "时长"},
    {"value": "474 kcal", "label": "活动消耗"},
    {"value": "3'20\"", "label": "平均配速"},
    {"value": "蛙泳", "label": "泳姿"}
  ]
}
```

Do not add device, App, source-image, lap-count, or stroke-count text unless the user explicitly requests it.

## 思考 (`thought`)

```json
{
  "date": "2026-07-16",
  "kind": "thought",
  "title": "今天想到的一件事",
  "lead": "事情或背景。",
  "quote": "可选的一句话。",
  "note": "自己的理解。"
}
```

Do not invent a conclusion merely to fill the card.

## 阅读 (`reading`)

```json
{
  "date": "2026-07-16",
  "kind": "reading",
  "title": "《书名》阅读记录",
  "book": "书名",
  "status": "reading",
  "lead": "阅读进度或主题。",
  "metrics": [
    {"value": "42 页", "label": "本次阅读"},
    {"value": "35 分钟", "label": "阅读时长"}
  ],
  "quote": "真正有感触的原文或摘要。",
  "note": "自己的理解。"
}
```

Use `status: completed` only when the book has been finished. The yearly goal counts unique completed `book` values.

## 娱乐 (`entertainment`)

```json
{
  "date": "2026-07-16",
  "kind": "entertainment",
  "title": "看了一部电影",
  "metrics": [
    {"value": "112 分钟", "label": "片长"},
    {"value": "8.4 / 10", "label": "个人评分"}
  ],
  "note": "一两句真实感受。"
}
```
