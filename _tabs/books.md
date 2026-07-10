---
icon: fas fa-book
order: 3
title: 书架
---

这里陈列了我编写的技术书籍与工程实践指南。每本书都围绕特定主题，沉淀我在开发与架构设计中的思考与实践。

<div class="bookshelf-container">

  <!-- 电子书卡片 1 -->
  <div class="book-card">
    <div class="book-card-cover">
      <a href="/assets/img/books/anthropic-engineering-cover-full.jpg" class="popup">
        <img src="/assets/img/books/anthropic-engineering-cover.jpg" alt="Anthropic Engineering 学习指南" class="book-cover-img" />
      </a>
    </div>
    <div class="book-card-content">
      <h3 class="book-title">《Anthropic Engineering 学习指南》</h3>
      <p class="book-desc">AI Agent 工程实践与企业架构设计。本书面向软件工程师、架构师和企业 Agent 平台 builder，系统剖析从 Prompt 到 Workflow 乃至 Managed Agents 的演进路径，并基于 Java/Spring Boot 设计企业级运行时架构。</p>
      <div class="book-meta">
        <span class="badge badge-status">在线阅读</span>
        <span class="badge badge-lang">中文版</span>
      </div>
      <div class="book-links">
        <a href="https://arthaks.github.io/anthropic-engineering-guide/" target="_blank" class="btn btn-primary-book">开始阅读</a>
        <a href="https://github.com/arthaks/anthropic-engineering-guide" target="_blank" class="btn btn-secondary-book"><i class="fab fa-github"></i> 源码</a>
      </div>
    </div>
  </div>

  <!-- 占位卡片 (将来写新书时复制上面的结构即可) -->
  <div class="book-card book-card-placeholder">
    <div class="book-card-cover">
      <div class="book-cover-inner">
        <span class="book-cover-title">下一本书</span>
        <span class="book-cover-subtitle">规划中...</span>
      </div>
    </div>
    <div class="book-card-content">
      <h3 class="book-title">下一本技术书籍</h3>
      <p class="book-desc">下一部关于分布式系统架构、性能调优或云原生落地的书籍正在筹备中。敬请期待！</p>
      <div class="book-meta">
        <span class="badge badge-waiting">筹备中</span>
      </div>
    </div>
  </div>

</div>

<style>
/* 书架卡片流式布局 */
.bookshelf-container {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  margin-top: 2rem;
}

.book-card {
  display: flex;
  border: 1px solid var(--card-border-color, #e9ecef);
  border-radius: 8px;
  background-color: var(--card-bg, #ffffff);
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.04);
  overflow: hidden;
  transition: transform 0.2s, box-shadow 0.2s;
}

.book-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 15px rgba(0, 0, 0, 0.08);
}

/* 书籍立体封面模拟 */
.book-card-cover {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  width: 160px;
  min-height: 220px;
  padding: 0;
  background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  color: #ffffff;
  position: relative;
  box-shadow: inset -5px 0 10px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}

.book-cover-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 4px;
  padding: 1.5rem 0.5rem;
  height: 100%;
  width: 100%;
  justify-content: center;
}

.book-cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.book-cover-title {
  font-size: 1.1rem;
  font-weight: bold;
  letter-spacing: 0.05em;
  color: #f8fafc;
}

.book-cover-subtitle {
  font-size: 0.8rem;
  color: #94a3b8;
  margin-top: 0.5rem;
}

/* 卡片内容区 */
.book-card-content {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex-grow: 1;
}

.book-title {
  margin-top: 0 !important;
  margin-bottom: 0.75rem !important;
  font-size: 1.3rem !important;
  border-bottom: none !important;
  padding-bottom: 0 !important;
}

.book-desc {
  font-size: 0.95rem;
  line-height: 1.6;
  color: var(--text-color, #495057);
  margin-bottom: 1rem;
}

.book-meta {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.25rem;
}

.badge {
  padding: 0.25rem 0.6rem;
  border-radius: 4px;
  font-size: 0.8rem;
  font-weight: 500;
}

.badge-status {
  background-color: rgba(37, 99, 235, 0.1);
  color: #2563eb;
}

.badge-lang {
  background-color: rgba(4, 120, 87, 0.1);
  color: #047857;
}

.badge-waiting {
  background-color: rgba(108, 117, 125, 0.15);
  color: #6c757d;
}

/* 书籍链接与按钮 */
.book-links {
  display: flex;
  gap: 0.75rem;
}

.btn {
  padding: 0.45rem 1.2rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 500;
  text-decoration: none !important;
  transition: background-color 0.15s;
}

.btn-primary-book {
  background-color: #2563eb;
  color: #ffffff !important;
}

.btn-primary-book:hover {
  background-color: #1d4ed8;
}

.btn-secondary-book {
  border: 1px solid #ced4da;
  color: var(--text-color, #495057) !important;
}

.btn-secondary-book:hover {
  background-color: var(--card-bg, #f8f9fa);
  border-color: #b1b5b9;
}

/* 占位书卡片变灰 */
.book-card-placeholder {
  opacity: 0.6;
  filter: grayscale(1);
}

.book-card-placeholder .book-card-cover {
  background: linear-gradient(135deg, #4b5563 0%, #1f2937 100%);
}

/* 封面点击放大 */
.book-card-cover .popup {
  display: block;
  width: 100%;
  height: 100%;
  margin: 0 !important;
}

.book-cover-img {
  cursor: zoom-in;
}

@media (max-width: 576px) {
  .book-card {
    flex-direction: column;
  }
  .book-card-cover {
    width: 100%;
    min-height: 140px;
    padding: 1.5rem;
  }
}
</style>
