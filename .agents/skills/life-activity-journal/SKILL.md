---
name: life-activity-journal
description: Maintains this Jekyll blog's yearly “生活轨迹” journal from screenshots or text. Use when adding, correcting, validating, summarizing, or creating yearly records for 运动、思考、阅读、娱乐. Merges content into one card per day, never publishes source screenshots, and verifies the generated page.
compatibility: Requires Ruby with standard-library YAML/JSON and the blog's Bundler/Jekyll environment.
disable-model-invocation: true
---

# Life Activity Journal

Maintain one yearly journal page with one card per day. A day may contain any combination of `运动`、`思考`、`阅读`、`娱乐`.

This skill is command-only. Run it only after the user explicitly invokes `/skill:life-activity-journal`. Never update the journal merely because the user shares a screenshot, writes another blog post, or publishes a book.

## Fixed project paths

- Data: `_data/activity_log.yml`
- Year page: `_drafts/YYYY-life-activity-journal.md` or `_posts/YYYY-MM-DD-YYYY-life-activity-journal.md`
- Shared renderer: `_includes/activity-journal.html`
- Shared styles: `assets/css/activity-journal.css`
- Shared behavior: `assets/js/activity-journal.js`
- Import directory: `temp/` (temporary and excluded from Jekyll output)
- Helper: `scripts/journal.rb`, resolved relative to this skill directory

## Workflow

1. Inspect every supplied screenshot or text record.
2. Extract only visible or explicitly supplied facts. Never infer missing values.
3. Normalize each item using [content templates](references/content-templates.md) and [extraction rules](references/extraction-rules.md).
4. Write a temporary JSON payload matching `assets/templates/batch.json`.
5. Run a dry run:
   ```bash
   ruby .agents/skills/life-activity-journal/scripts/journal.rb import /tmp/activity-records.json
   ```
6. Review dates, actions, category counts, duplicate warnings, and metric limits.
7. Apply atomically:
   ```bash
   ruby .agents/skills/life-activity-journal/scripts/journal.rb import /tmp/activity-records.json --apply
   ```
8. Validate:
   ```bash
   ruby .agents/skills/life-activity-journal/scripts/journal.rb validate
   ```
9. Build with drafts and verify the journal URL returns HTTP 200.
10. Remove processed files from `temp/`. Never copy screenshots into `assets/`.
11. Never publish a draft unless the user explicitly asks to publish it.

## Content rules

- Allowed categories only: `sport`, `thought`, `reading`, `entertainment`.
- Merge by date. Never create two day cards for one date.
- All newly added content is treated as a real record. Do not add demo or sample content.
- Sport metrics: at most 5, ordered as distance, duration, calories, pace, activity type.
- Omit App names, devices, account IDs, screenshot provenance, and boilerplate such as “来自某某长图”.
- Keep metrics on one compact row; omit secondary metrics rather than creating horizontal scrolling.
- Screenshots are transient input and may contain account IDs, maps, or private routes.
- Reading records use `status: reading|completed`; only unique books marked `completed` count toward the 5-book goal.

## Commands

```bash
ruby .agents/skills/life-activity-journal/scripts/journal.rb validate
ruby .agents/skills/life-activity-journal/scripts/journal.rb stats 2026
ruby .agents/skills/life-activity-journal/scripts/journal.rb import payload.json
ruby .agents/skills/life-activity-journal/scripts/journal.rb import payload.json --apply
ruby .agents/skills/life-activity-journal/scripts/journal.rb new-year 2027
ruby .agents/skills/life-activity-journal/scripts/journal.rb new-year 2027 --apply
ruby .agents/skills/life-activity-journal/scripts/journal.rb publish 2026
ruby .agents/skills/life-activity-journal/scripts/journal.rb publish 2026 --apply
ruby .agents/skills/life-activity-journal/tests/journal_test.rb
```

Mutating commands are dry-run by default. Never use `--apply` until their output has been reviewed.
