# Figma UI Gates

独立 skill 仓库：负责 **新 Figma UI** 的 G0–G12 门禁合同（`dev-flow feature` 的条件子路由）。

- 仓库：https://github.com/Immmmmmortal1/figma-ui-gates
- 入口文档：[`SKILL.md`](./SKILL.md)
- 编排入口在 [`devflow`](https://github.com/Immmmmmortal1/devflow)；**已有页面 parity** 由 `ui-review` 承担，不归本仓。

## 何时使用

- `feature` 含新 Figma 界面 / 按设计还原实现
- 需要按 G0→G12 顺序产出可机械校验的 gate 证据

不要用于：

- 已有屏与 Figma 的校对修复（用 `ui-review`）
- 与 Figma 无关的纯逻辑 feature / bug

## 门禁顺序

```text
preflight
→ G0 scope
→ G1 root tree + structure review
→ G2 current group detail + detail review
→ G3 REST design evidence
→ G4 classification/container
→ G5 ordered group sweep
→ G6 asset boundary
→ G6 binding validation (mechanical)
→ G7 native implementation
→ G7A leaf runtime review / G7B parent rollup review
→ G8 build
→ G9 runtime semantics
→ G10 screenshot/design review
→ G11 independent orchestrator review
→ G12 final verifier
```

失败或 blocked 必须停；禁止手写 summary 冒充 pass。

## 产物工作区

在**目标工程**内按 canonical Figma URL 建工作区（目标仓应 ignore）：

```text
.dev-flow/ui/by-url/<sanitized-canonical-figma-url>/
├── manifest.json
├── preflight.json
├── gates/          # G0–G12 记录，含 G6-assets.json
├── figma/
├── reviews/
├── runtime/
└── …
```

## 与 devflow 的关系

| 仓库 | 职责 |
|---|---|
| `devflow` | 路由、会话、环境门禁、`ui-review`、通用脚本 |
| `figma-ui-gates`（本仓） | 新 UI 的 G0–G12 skill 合同 |

本机建议与 `devflow` 并列放置：

```text
devskills/
├── devflow/
└── figma-ui-gates/   # 本仓
```

安装到 Codex / Cursor skills 时，将本仓 `SKILL.md` 链到：

```text
~/.codex/skills/figma-ui-gates/SKILL.md
# 或
~/.cursor/skills/figma-ui-gates/SKILL.md
```

若使用 `devflow` 的 `scripts/link-*-skills.sh`，需保证它解析到**本仓**的 `SKILL.md`，而不是把副本嵌进 `devflow` 仓库。

## G6 机械绑定校验

G6 要求 collapsed 非交互视觉单元使用导出资产。机械校验脚本目前由 `devflow` 提供：

```bash
bash ../devflow/scripts/validate-g6-asset-binding.sh \
  --workspace <artifact-workspace> \
  --source-root <target-project-root> \
  [--report <path>]
```

详细资产规则、Review MCP 证据要求与各 gate 停点见 [`SKILL.md`](./SKILL.md)。

## 依赖能力

- `figma-rest-api`：只读 Figma REST / 导出图
- `orchestrator_mcp`（Review Hub）：structure / detail / runtime / rollup / final review
- DebugBridge：真机或模拟器运行时检查（按目标工程约定）
- XcodeBuildMCP：构建安装启动
- 目标工程的 artifact initializer / final UI verifier
