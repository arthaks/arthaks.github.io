---
name: blog-maintainer
description: Maintain this Chirpy Jekyll blog when creating or editing ordinary posts, drafts, pages, assets, diagrams, site configuration, or build tooling, and when validating the site before publication. Do not use for life-activity journal changes; route those only after explicit invocation of life-activity-journal.
---

# Maintain the Jekyll Blog

Operate the blog repository without assuming the session starts in its directory. Preserve unrelated changes and keep publication separate from content creation.

## Establish context

1. Resolve the repository from this skill's location:

   ```bash
   BLOG_ROOT="$(git -C "${HERMES_SKILL_DIR}" rev-parse --show-toplevel)"
   cd "$BLOG_ROOT"
   ```

   For runtimes that do not expand `${HERMES_SKILL_DIR}`, derive the Git root from the loaded `SKILL.md` path.

2. Read `AGENTS.md` completely before changing files. Treat it as authoritative for templates, front matter, dynamic SVG, and content boundaries.
3. Run `git status --short --branch`. Preserve all pre-existing changes and never overwrite unrelated work.

## Route the request

- For ordinary technical or life writing, use the matching template under `_drafts/` and obey `AGENTS.md`.
- Default new content to `_drafts/` unless the user explicitly asks to publish it.
- Put published posts in `_posts/` with `YYYY-MM-DD-title.md` naming and valid front matter.
- Put images under the dated `assets/img/YYYY-MM-DD/` directory and follow the dynamic SVG rules in `AGENTS.md`.
- For pages, navigation, styling, configuration, or tooling, edit the established project files rather than creating parallel systems.
- Never change `_data/activity_log.yml`, a yearly life-activity page, or its renderer in response to ordinary content. Require an explicit `/life-activity-journal`, `/skill:life-activity-journal`, or “更新生活轨迹” request, then load that skill.

## Work safely

1. Inspect relevant templates and neighboring content before drafting.
2. Make the smallest coherent change that satisfies the request.
3. Do not place private screenshots, account identifiers, credentials, routes, or transient imports in published assets.
4. Do not edit generated `_site/` output as source; regenerate it through Jekyll when verification needs it.
5. Do not commit, push, publish a draft, or force-push unless the user explicitly requests that action. Never force-push.

## Verify

Choose checks proportional to the change:

- Run the dedicated script or test for changed functionality.
- For life-activity logic, use the commands and dry-run/apply boundary in `life-activity-journal`.
- For a full production check, run:

  ```bash
  bundle check || bundle install
  bash tools/test.sh
  ```

- When validating drafts, build with drafts and confirm the target page and referenced assets resolve.
- Review `git diff --check`, `git status --short`, and the final diff before reporting completion.
- If the user explicitly requests publication, verify first, then commit/push only the intended files. GitHub Actions performs the Pages deployment after a push to `main`.
