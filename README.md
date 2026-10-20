# Figma UI Gates

当前发布版本：`v1.0.3`。版本以 Git tag 为权威。

## 为什么需要这套门禁

AI 实现 UI 时，如果一次拉取所有节点再实现，节点越多，上下文就越长，遗漏的实现细节也越多，过程会逐渐失去控制。整页一起做时，一个子节点的尺寸、层级、内边距或运行时位置即使出错，也容易被整页结果掩盖。

这套 skill 采用开发写代码时常用的办法：**化整为零，先固定页面元素树的顺序，再一个节点一个节点实现**。具体只有三个动作：

1. **先定树的顺序**：明确谁在谁里面、谁盖在谁上面，以及从上到下、同一行从左到右的顺序。
2. **再逐节点实现**：每个实现任务只携带一个节点的信息，使用设计稿原始 `x/y/w/h`，不凭观感调整。
3. **做完一个验一个**：当前节点通过实现与运行时验收后，才继续下一个兄弟节点；失败或 blocked 立即停止。

规则、工件和门禁的全部设计都围绕同一个目标：让每个实现任务的上下文只包含一个节点，使细节有明确落点，也使错误能在局部被发现。

下一步：先理解下面两个组成部分，再按文末顺序执行门禁；完整约束以 [`SKILL.md`](./SKILL.md) 为准。

## 组成部分一：最小实现单元

最小实现单元是**直接对应代码实现的节点**。从产品元素看，目前包含三类：**按钮、文字、图片**。

判定原则是：**一个组别内部包含两种及以上最小实现单元，就必须继续拆分**。此外：

- 含可本地化文字或交互的复合节点必须继续拆分；可本地化文字不能做成图片。
- 按钮按内容细分为纯文字、纯图、文字+图标；文字+图标永不折叠成一张导出图。
- 纯静态、非交互的图形组合可以整体作为一个图片单元。
- 技术记录中的真实 `unit_kind` 为 `text`、`button-text`、`button-image`、`button-text-icon`、`image`、`shared-component`；其中 `shared-component` 用于共享 chrome 或跨页面组件实例，不是新增的产品元素类别。

必须继续拆，是因为每次只处理一个直接实现节点，才能控制上下文；同时，字体、颜色、圆角、资产、锚点和交互等容易遗漏的细节都有自己的记录与验收位置，不会消失在“整页一起做”里。

下一步：拆分时为每个节点写明 `unit_kind`；遇到可本地化文字、交互复合节点或文字+图标按钮时继续拆，不要自行折叠。

## 组成部分二：节点文档落地

每个节点都要落一份文档，同时承担两件事：

1. **实现时的知识库**：记录 Figma 原始值、父容器、布局锚点、尺寸、圆角、颜色、字体、资产来源和运行时锚点。
2. **验收时的校对标准**：实现后仍拿同一份文档，逐条比对运行时结果。

文档不是事后补的总结，而是在拆分阶段就产生、随实现推进逐步填满的工件。实现与校对共用同一把尺子，设计依据、代码落点和运行时证据才能保持连续。

实际工件如下：

| 工件 | 作用 |
|---|---|
| `frame_struct.md` / `frame_struct_index.json` | 固定页面元素树、父子关系、视觉顺序、原始坐标和来源绑定 |
| `gates/G2-detail.json` | 承载逐单元 detail 记录，包括父节点、原始 frame、布局锚点、`unit_kind`、运行时 ID、拆分与实现状态 |
| `rules_used.json` | 记录本页实际使用的最小单元规则集合，后续只加载对应规则 |
| `gates/G6-assets.json` | 记录资产拆分或合并决策、原因、本地资产和导出尺寸/倍率证据 |
| `runtime/*.json` | 保存逐节点运行时查询结果，作为几何和语义验收证据 |
| `reviews/*.json` | 保存各审查门禁的 reviewer、verdict、findings、父节点汇总和证据路径 |

下一步：从 G1 建树时就创建结构工件；G2 拆分每个节点时填写 detail，不要等页面实现完成后再倒补。

## 实践依据

最近一次页面还原包含 95 个节点。逐节点验收抓到 5 处结构性错误，包括整簇控件离屏一个屏宽、第四个 tab 完全不可见、图标右侧内边距丢失等。这类问题在“整页一起做”时不会暴露。

下一步：不要用整页观感代替节点验收；每完成一个最小单元，就保存运行时证据并按节点文档校对。

## 适用范围与分工

本 skill 负责**新 UI 的一次性实现与几何还原**。已有页面校对由 `ui-review` 负责；加载、空态、错误、重试、离线、权限等业务状态由 `ui-review` 与目标项目已批准的需求负责，本 skill 不重复定义。

下一步：新 Figma 页面使用本 skill；已有页面的差异修复或业务状态检查转交 `ui-review` 和目标项目需求。

## 怎么跑

### 门禁顺序

必须按以下顺序执行，不得跳过或重排：

```text
preflight → G0 scope → G1 root tree* → G2 detail* → G3 REST evidence
→ G4 classification/container → G5 ordered sweep → G6 asset declaration*
→ G7 implementation → G8 build + launch → G6V asset binding validation
→ G7A unit runtime review* → G7B parent rollup review*
→ G9 runtime semantics → G10 geometry parity* → G11 final review* → G12 final verify
```

`*` = 需要 review 记录。

任一门禁失败或 blocked 必须停止；文字总结不能代替门禁记录。

### 哪些门禁需要 review

| gate | 审什么 | 默认执行者 | 没有配置 review role 时 |
|---|---|---|---|
| G1 | 根节点身份、直接子节点完整性、层级与视觉顺序、原始坐标、索引覆盖 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G2 | 父节点与来源绑定、字段完整性、锚点推导、最小单元判定、后序字段、frame-index 绑定；歧义必须停下确认 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G6 | 资产合并/拆分决策、原因、本地资产存在性、导出尺寸与 2x/3x 倍率，以及拆分项的原生映射 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G7A | 每个最小单元的运行时节点唯一性、frame/bounds、旋转、锚点、圆角、透明度、图片尺寸、字体及适用单元规则 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G7B | 非最小父节点的直接子节点覆盖与顺序、拆分/实现完成状态、计数器、完成类型、frame-index 绑定 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G10 | 几何容差、圆角与 capsule、z-order、字体，并覆盖原点/尺寸、旋转、锚点、透明度、图片尺寸、颜色和跨宽度锚点稳定性 | 当前 agent 自审（`nodeGate.mode = "self"`） | 改为当前 agent 自审即可，配置 `review.nodeGate.mode = "self"` |
| G11 | 变更文件、全部门禁状态、运行时结论、G6V 资产绑定结果、几何结果和已知风险 | 子 agent `ui-reviewer`（`finalGate.mode = "subagent"`） | 终审也可改为当前 agent 自审，配置 `review.finalGate.mode = "self"` |

执行者不同不会让门禁变成可选：以上每个 gate 的 `reviews/<gate>.json` 仍必须存在且 `verdict = "pass"`。这些记录会被 verifier 机械校验，包括文件、verdict、reviewer 身份、findings、evidence 和时间序，因此不能省略。

### review 的三种执行方式

- `self`（节点审查默认）：当前执行 agent 自己审，记录 `reviewer.kind = "self"`。
- `subagent`（终审默认）：由指定子 agent 审，例如默认的 `ui-reviewer`，记录 `reviewer.kind = "subagent"`。
- `custom`：执行自定义命令；只有对应 reviewer 的 `mode = "custom"` 时，其非空 `command` 才生效，记录 `reviewer.kind = "custom"`。

有完整 review role 的机器使用默认配置即可，不需要提供配置：

```json
{}
```

没有 review role 的机器可让节点审查和终审都由当前 agent 执行：

```json
{
  "review": {
    "nodeGate": { "mode": "self" },
    "finalGate": { "mode": "self" }
  }
}
```

门禁强度不变，变的只是谁来做这次审查。`review.requireIndependentNodeGate` 默认是 `false`；只有显式设为 `true`，才强制节点门禁使用独立 reviewer，此时 `nodeGate.mode` 不能是 `self`。

### 配置解析

配置是可选的部分 JSON。先合并默认值，再校验完整结果：

```bash
python3 scripts/resolve-config.py [path/to/config.json]
```

### 本地校验

```bash
bash tests/run-tests.sh
bash scripts/verify-gate-record.sh --workspace <artifact-workspace> --source-root <target-project-root>
```

产物工作区必须被目标仓库忽略；未被 Git ignore 时，preflight 为 blocked，不得提交产物。已知无法机械保证的边界见 [`LIMITATIONS.md`](./LIMITATIONS.md)，完整门禁、字段和验收合同见 [`SKILL.md`](./SKILL.md)。

下一步：先解析配置并通过 preflight，再从 G0 开始；不要在 G1-G6 通过前修改目标 UI 源码。
