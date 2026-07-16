# Extraction and validation rules

## Screenshot handling

- Read the activity date from the screenshot, not from the screenshot filename or export time.
- Read date, activity title, and only the metrics needed by the template.
- Use active calories consistently when both active and total calories are shown.
- Cross-check repeated fields when multiple screenshots describe the same activity.
- Inspect the full source when a map or another panel appears before the summary; a top crop may omit pace or other core metrics.
- Do not retain account IDs, QR codes, route maps, device names, or application names.
- Do not copy source screenshots into the published site.
- Delete processed temporary files only after import, validation, build, and HTTP checks succeed.

## Date merging

- The date is the identity of a day card.
- A new item on an existing date is appended to that day's `items`.
- An exact match on date + kind + title is updated rather than duplicated.
- All items are real records. Do not create demo/sample fields or content.

## Writing

- Prefer facts over filler.
- Do not write “一张截图显示……” or “数据来自某设备……”.
- Do not manufacture feelings, book opinions, or daily thoughts.
- Preserve user wording when supplied.

## Metric formatting

- Maximum 5 metrics per item.
- Use compact values such as `1,000 米`, `33:23`, `474 kcal`, `3'20"`.
- Keep labels short: `距离`, `时长`, `活动消耗`, `平均配速`, `泳姿`.
- Use consistent units within the same activity type.
