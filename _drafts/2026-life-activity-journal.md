---
title: "2026 生活轨迹｜运动 · 思考 · 阅读 · 娱乐"
date: 2026-07-16 19:49:39 +0800
categories: [Life]
tags: [运动, 思考, 阅读, 娱乐, 生活记录, 长期主义]
toc: false
comments: false
activity_year: 2026
description: "记录 2026 年的运动、思考、阅读和娱乐。"
---

{% assign activity_year_data = site.data.activity_log.years | where: "year", page.activity_year | first %}

<link rel="stylesheet" href="{{ '/assets/css/activity-journal.css' | relative_url }}">
{% include activity-journal.html year=activity_year_data %}
<script defer src="{{ '/assets/js/activity-journal.js' | relative_url }}"></script>
