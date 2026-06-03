# clay's blog

一个基于 [Jekyll](https://jekyllrb.com/) + [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) 的个人博客。

主要记录：

- Java 后端开发经验
- AI / LLM / Agent 学习理解
- 工程实践、踩坑记录
- 生活思考和个人复盘

站点地址：<https://arthaks.github.io>

## 本地运行

安装依赖：

```bash
bundle install
```

启动本地预览：

```bash
bash tools/run.sh
```

访问：

```text
http://127.0.0.1:4000
```

## 构建测试

```bash
bash tools/test.sh
```

## 内容管理

### 发布文章

正式文章放在 `_posts/` 目录，文件名格式：

```text
YYYY-MM-DD-title.md
```

### 草稿

草稿放在 `_drafts/` 目录。

预览草稿：

```bash
bundle exec jekyll serve --drafts
```

### 图片资源

文章图片建议放在：

```text
assets/img/YYYY-MM-DD/
```

然后在 Markdown 中引用：

```markdown
![图片说明](/assets/img/YYYY-MM-DD/image.png)
```

## 技术说明

当前博客支持：

- Markdown
- 代码高亮
- LaTeX 数学公式
- Mermaid 图表
- Chirpy 主题内置的分类、标签、归档、搜索、PWA 等能力

## License

博客内容除特别说明外归作者所有。

主题基于 [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy)，遵循其开源协议。
