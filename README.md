# Figma UI Gates

当前发布版本：`v1.0.1`。版本以 Git tag 为权威。

独立 skill 仓库：负责新 Figma UI 的一次性实现与几何还原验收。完整契约见
[`SKILL.md`](./SKILL.md)。

## 门禁顺序

```text
preflight → G0 → G1 → G2 → G3 → G4 → G5 → G6 → G7 → G8
→ G6V → G7A → G7B → G9 → G10 → G11 → G12
```

失败或 blocked 必须停止。已有页面校对及业务状态覆盖由 `ui-review` 与目标项目需求负责。

## 配置解析

配置是可选的部分 JSON。先合并默认值，再校验完整结果：

```bash
python3 scripts/resolve-config.py [path/to/config.json]
```

## 本地校验

```bash
bash tests/run-tests.sh
bash scripts/verify-gate-record.sh --workspace <artifact-workspace> --source-root <target-project-root>
```

产物工作区必须由目标仓库忽略；未被 Git ignore 时 preflight blocked，不得提交。已知无法
机械保证的边界见 [`LIMITATIONS.md`](./LIMITATIONS.md)。
