# LearningGraphics 项目规范

## 项目目的
用 AI 辅助学习 Ray Marching，并将过程整理为一场 15-20 分钟的学术演讲。

## 文件组织规则

### Q&A 记录
用户每次关于 demo 的提问，单独保存为一个文件：
- 目录：`qa/`
- 命名：`qa/NNN_简短描述.md`（NNN 为三位数递增编号，如 `001_xxx.md`）
- 格式：
  ```markdown
  # Q: 用户的原始问题

  ## A: 回答内容
  ```

### 其他文件
- `step*.glsl` — ShaderToy 可直接运行的 shader 代码，按学习步骤编号
- `LEARNING_JOURNAL.md` — 学习笔记，记录 top-down 学习路径
- `slides/` — 演讲相关素材（大纲、slides 脚本等）

## Git 规范
- 每个有意义的学习步骤都要单独 commit
- commit message 用中文，说明"做了什么"和"学到了什么"
