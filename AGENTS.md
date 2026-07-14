# 博客系统 (Chirpy Jekyll Theme) 开发指南

这是一个基于 [Jekyll](https://jekyllrb.com/) 框架和 [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) 主题的个人博客系统。

## 🚀 快速开始

### 依赖环境
确保本地已安装以下工具：
- Ruby (建议版本 3.0+)
- Bundler (`gem install bundler`)
- RubyGems

### 安装依赖
在根目录下执行：
```bash
bundle install
```

### 本地运行
使用内置脚本启动预览服务器：
```bash
bash tools/run.sh
```
启动后访问：`http://127.0.0.1:4000`

### 生产环境构建并测试
```bash
bash tools/test.sh
```

---

## 📝 内容管理

### 文章 (Posts)
- **位置**: `_posts/` 目录。
- **命名规范**: `YYYY-MM-DD-title.md` (例如: `2026-06-02-hello-world.md`)。
- **Front Matter**: 每篇文章开头需要包含 YAML 配置，例如：
  ```yaml
  ---
  title: 文章标题
  date: 2026-06-02 12:00:00 +0800
  categories: [分类1, 分类2]
  tags: [标签1, 标签2]
  ---
  ```

### 草稿 (Drafts)
- **位置**: `_drafts/` 目录。
- **预览草稿**: 运行 `bundle exec jekyll serve --drafts`。

### 页面 (Tabs)
- 侧边栏的导航页（如“关于”、“分类”、“标签”）定义在 `_tabs/` 目录下。

---

## 🎨 内容模板 (Templates)

为了保持内容精简有效，项目目前仅保留 **Tech (技术)** 和 **Life (生活)** 两个核心方向：

1. **技术沉淀** (`_drafts/template-tech.md`):
   - 适用于 AI 学习、工作经验、技术方案等。

2. **生活记录** (`_drafts/template-life.md`):
   - 适用于日常随笔、生活管理、个人感悟等。

### 多分类处理：
如果一篇文章既属于 `Tech` 又属于 `Life`，可以在 Front Matter 中这样写：
```yaml
categories: [Tech, Life]
```

### 如何使用模板：
1. **AI 助手操作**: 告诉 AI “请基于 `_drafts/template-tech.md` 模板帮我写一篇关于 [主题] 的博客”。
2. **手动操作**:
   - 复制对应模板内容。
   - 在 `_posts/` 创建新文件 `YYYY-MM-DD-your-title.md`。
---

## 📁 目录结构说明

- `_config.yml`: 站点全局配置文件（网站名称、描述、社交链接等）。
- `_posts/`: 所有的博文源文件。
- `_tabs/`: 自定义页面（About, Archives, Categories, Tags）。
- `assets/`: 静态资源文件（图片、头像、库文件）。
- `tools/`: 辅助脚本（运行、构建测试）。
- `_data/`: 存储网站使用的结构化数据（联系方式、分享配置）。
- `_plugins/`: Jekyll 插件。
- `Gemfile`: 项目依赖定义的 Ruby 配置文件。

---

## ⚙️ 常用配置修改

大部分站点配置都在 `_config.yml` 中完成：
- **站点信息**: `title`, `tagline`, `description`
- **个人信息**: `social.name`, `social.email`, `github.username`
- **外观**: `theme_mode` (light/dark)
- **分析工具**: 支持 Google Analytics, Umami 等。

---

## 动态 SVG 架构图发布规范

生成包含动态箭头的 Draw.io 架构图时，优先发布 SVG，并将资源放在按日期划分的目录：

```text
assets/img/YYYY-MM-DD/<diagram>.drawio.svg
```

Chirpy 会将普通 Markdown 图片自动包装为带 `popup` 类的 GLightbox 链接。点击放大时，弹层会重新加载 SVG，并同时执行弹层缩放与 SVG 内部 CSS 动画，可能产生闪动。因此，动态 SVG 不使用裸图片语法：

```markdown
![架构图](/assets/img/YYYY-MM-DD/diagram.drawio.svg)
```

统一使用“图片链接到 SVG 原图”的写法，并在新标签页打开：

```markdown
[![架构图](/assets/img/YYYY-MM-DD/diagram.drawio.svg)](/assets/img/YYYY-MM-DD/diagram.drawio.svg){: target="_blank" rel="noopener" }

点击架构图可在新标签页打开 SVG 原图，并使用浏览器缩放查看。
```

该写法保留文章内的 SVG 动画，同时绕过 GLightbox。生成文章后执行以下检查：

1. 使用 `bash tools/run.sh -d` 启动包含草稿的本地预览。
2. 确认文章页面和 SVG 资源均返回 HTTP 200。
3. 确认 SVG 的响应类型为 `image/svg+xml`。
4. 确认生成的图片链接包含 `target="_blank"` 和 `rel="noopener"`。
5. 确认图片附近不包含 `class="popup"`。
6. 动态 SVG 应使用 CSS 动画，发布文件中避免包含不必要的 JavaScript。

如果 SVG 文件较大或文章首屏性能受影响，使用静态 PNG 作为文章内预览，并将 PNG 链接到动态 SVG 原图。只有需要文章内独立交互、平移或缩放时，才考虑使用 `<object>` 或 `<iframe>`。

## 🛠 开发技巧
- **搜索优化**: 每次推送到 GitHub 时，Actions 会自动构建并更新搜索索引。
- **图片处理**: 建议将文章图片放在 `assets/img/` 下，并在 Markdown 中引用。动态 SVG 遵循上面的专用发布规范。
- **PWA**: 该项目已启用 PWA，支持离线访问。
