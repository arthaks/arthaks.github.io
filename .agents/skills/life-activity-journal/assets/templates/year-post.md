---
title: "__YEAR__ 生活轨迹｜运动 · 思考 · 阅读 · 娱乐"
date: __DATE__
categories: [Life]
tags: [运动, 思考, 阅读, 娱乐, 生活记录, 长期主义]
toc: false
comments: false
activity_year: __YEAR__
description: "记录 __YEAR__ 年的运动、思考、阅读和娱乐。"
---

{% assign activity_year_data = site.data.activity_log.years | where: "year", page.activity_year | first %}

<link rel="stylesheet" href="{{ '/assets/css/activity-journal.css' | relative_url }}">
{% include activity-journal.html year=activity_year_data %}
<script defer src="{{ '/assets/js/activity-journal.js' | relative_url }}"></script>
