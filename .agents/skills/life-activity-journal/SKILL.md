---
name: life-activity-journal
description: Use only when the user explicitly invokes /life-activity-journal, invokes /skill:life-activity-journal in a compatible client, or explicitly asks to “更新生活轨迹”. Maintain this Jekyll blog's yearly journal for 运动、思考、阅读、娱乐; never infer invocation from screenshots or ordinary blog requests.
---

# Life Activity Journal

Maintain one yearly journal page with one card per day. A day may contain any combination of `运动`、`思考`、`阅读`、`娱乐`.

This skill is command-only. Run it only after the user explicitly invokes `/life-activity-journal`, invokes `/skill:life-activity-journal` in a compatible client, or explicitly says “更新生活轨迹”. Never update the journal merely because the user shares a screenshot, writes another blog post, or publishes a book.

## Project setup

Hermes expands `${HERMES_SKILL_DIR}` to this skill's absolute directory. Resolve the repository before reading or changing project-relative files:

```bash
BLOG_ROOT="$(git -C "${HERMES_SKILL_DIR}" rev-parse --show-toplevel)"
cd "$BLOG_ROOT"
```

For runtimes that do not expand this token, derive the Git root from the loaded `SKILL.md` location. Require Ruby plus the repository's Bundler/Jekyll environment.

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
   ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" import /tmp/activity-records.json
   ```
6. Review dates, actions, category counts, duplicate warnings, and metric limits.
7. Apply atomically:
   ```bash
   ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" import /tmp/activity-records.json --apply
   ```
8. Validate:
   ```bash
   ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" validate
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
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" validate
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" stats 2026
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" import payload.json
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" import payload.json --apply
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" new-year 2027
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" new-year 2027 --apply
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" publish 2026
ruby "${HERMES_SKILL_DIR}/scripts/journal.rb" publish 2026 --apply
ruby "${HERMES_SKILL_DIR}/tests/journal_test.rb"
```

Mutating commands are dry-run by default. Never use `--apply` until their output has been reviewed.
