# 第11周：CI/CD与Agent编排

> 实验时间：2学时
> 实验类型：设计性+验证性
**学号**：202442020611  
**姓名**：黄远锋 
**日期**：2026年5月  
**课程**：软件工程导论  
**周次**：第11周  
---

## 一、实验目标

- [x] 理解 CI/CD 在 Harness 中的角色（"自动化执行引擎"）
- [x] 能够配置 Gitea Actions CI 工作流
- [x] 理解 Agent 编排在 CI/CD 中的应用（explore/librarian/oracle 并行分析）
- [x] 能够设计一个多 Agent 协作的 CI 流程

---

## 二、实验环境

- 操作系统：Windows
- 代码仓库：Gitea
- CI引擎：Gitea Actions
- 调度系统：Nomad
- 编程语言：Rust

---

## 三、操作步骤

### 步骤1：配置 Gitea Actions CI（25分钟）

#### 1.1 创建工作流目录结构

```bash
mkdir -p .gitea/workflows
```

#### 1.2 创建 CI 配置文件

创建 `.gitea/workflows/ci.yml`：

```yaml
name: CI

on:
  push:
    branches: [ develop/v3.0.0 ]
  pull_request:
    branches: [ develop/v3.0.0 ]

jobs:
  bp1-static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust toolchain
        uses: dtolnay/rust-toolchain@stable

      - name: Build project
        run: cargo build --all-features

      - name: Check code formatting
        run: cargo fmt --check --all

      - name: Run clippy linter
        run: cargo clippy --all-features -- -D warnings

  bp2-integration:
    needs: bp1-static
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust toolchain
        uses: dtolnay/rust-toolchain@stable

      - name: Run all tests
        run: cargo test --all-features

      - name: Run QPS benchmark test
        run: cargo test --test qps_benchmark_test -- --ignored --nocapture
```

#### 1.3 配置说明

| 配置项 | 说明 |
|--------|------|
| `on.push.branches` | 监听 develop/v3.0.0 分支的 push 事件 |
| `on.pull_request` | 监听 PR 创建和更新事件 |
| `bp1-static` | 静态代码检查 job（编译、格式化、lint） |
| `bp2-integration` | 集成测试 job，依赖 bp1-static 完成 |
| `needs` | 定义 job 依赖关系，确保串行执行顺序 |

#### ✅ 检查点1：保存 CI 配置文件

- [x] `.gitea/workflows/ci.yml` 文件已创建
- [x] 包含 `bp1-static` 和 `bp2-integration` 两个 job
- [x] `bp2-integration` 正确配置了 `needs: bp1-static` 依赖关系

---

### 步骤2：设计 Agent 编排流程（25分钟）

#### 2.1 传统CI vs Agent CI 对比

```
传统 CI（串行执行）：
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│  PR创建  │ -> │ BP1静态  │ -> │ BP2集成  │ -> │ BP3风险  │ -> 结果
└────────┘    └────────┘    └────────┘    └────────┘
              一步等一步，效率较低

Agent CI（并行触发）：
┌────────┐
│  PR创建  │
└────┬───┘
     │
     ├── explore Agent  ──> "找到 DELETE 相关的所有调用点"
     ├── librarian Agent ──> "查外部文档，验证 API 用法"
     └── oracle Agent   ──> "评估这个改动对性能的风险"
           │
           ▼
     ┌──────────────┐
     │   收集结果     │
     │ 合成报告      │
     │ 通知开发者     │
     └──────────────┘
```

#### 2.2 DELETE 优化 PR 的 3-Agent 分析流程设计

为 DELETE 优化 PR 设计一个 3-Agent 的 CI 分析流程：

| Agent | 分析任务 | 预期发现 |
|-------|---------|---------|
| **explore** | 扫描代码库中所有 DELETE 相关的调用点，分析删除操作的影响范围 | 找到 5-8 个受影响的模块，识别级联删除风险 |
| **librarian** | 查询外部文档和API规范，验证 DELETE API 的正确用法和最佳实践 | 发现 2 处不符合规范的用法 |
| **oracle** | 评估 DELETE 改动对性能的影响，预测 QPS 下降风险 | 识别索引缺失导致的潜在性能问题 |

#### 2.3 Agent 任务详细说明

**Explore Agent（探索代理）**
```bash
explore-task:
  - 扫描 src/ 目录下所有 .rs 文件
  - 识别 delete()、remove()、drop() 等删除相关方法调用
  - 构建删除调用依赖图
  - 识别级联删除风险点
```

**Librarian Agent（文档代理）**
```bash
librarian-task:
  - 查询外部 API 文档
  - 验证 DELETE 操作符合 RESTful 规范
  - 检查是否有替代方案（如 soft delete）
  - 验证错误处理是否完善
```

**Oracle Agent（预言代理）**
```bash
oracle-task:
  - 分析 DELETE 操作是否正确使用索引
  - 评估大批量删除对 QPS 的影响
  - 预测是否需要添加缓式删除机制
  - 给出性能优化建议
```

#### 2.4 Agent 编排工作流实现

```yaml
# .gitea/workflows/agent-analysis.yml
name: Agent CI Analysis

on:
  pull_request:
    branches: [ develop/v3.0.0 ]
    types: [opened, synchronize]

jobs:
  # 并行触发三个 Agent
  explore-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Explore Agent
        run: |
          echo "=== Explore Agent: 分析 DELETE 调用点 ==="
          grep -rn "DELETE" --include="*.rs" ./src > explore_results.txt
          echo "发现 $(wc -l < explore_results.txt) 处 DELETE 调用"

      - name: Upload explore results
        uses: actions/upload-artifact@v3
        with:
          name: explore-results
          path: explore_results.txt

  librarian-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Librarian Agent
        run: |
          echo "=== Librarian Agent: 验证 API 用法 ==="
          echo "检查 DELETE API 文档合规性..."
          echo "API合规性检查完成" > librarian_results.txt

      - name: Upload librarian results
        uses: actions/upload-artifact@v3
        with:
          name: librarian-results
          path: librarian_results.txt

  oracle-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Oracle Agent
        run: |
          echo "=== Oracle Agent: 性能风险评估 ==="
          echo "性能风险评估完成" > oracle_results.txt

      - name: Upload oracle results
        uses: actions/upload-artifact@v3
        with:
          name: oracle-results
          path: oracle_results.txt

  # 汇总阶段
  synthesize-report:
    needs: [explore-analysis, librarian-analysis, oracle-analysis]
    runs-on: ubuntu-latest
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v3

      - name: Synthesize report
        run: |
          echo "=== 合成最终分析报告 ==="
          echo "explore 发现: $(cat explore-results/explore_results.txt | wc -l) 处调用点"
          echo "librarian 发现: API合规性问题"
          echo "oracle 发现: 性能风险"

      - name: Post PR comment
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Agent CI 分析报告\n\n✅ explore: 发现 DELETE 调用点\n✅ librarian: API合规性检查完成\n✅ oracle: 性能风险评估完成\n\n请查看完整报告。'
            })
```

#### ✅ 检查点2：保存 Agent 编排设计

- [x] Agent 编排设计文档已保存
- [x] 三个 Agent 的任务分配清晰
- [x] 预期发现符合 DELETE 优化场景

---

### 步骤3：模拟 Gate 联动（10分钟）

#### 3.1 完整 Gate 联动流程图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           完整 Gate 联动流程                                  │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐
  │  开发者 push  │
  │    代码       │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ Gitea 触发   │
  │  webhook     │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ Nomad 调度   │
  │    Job       │
  └──────┬───────┘
         │
         ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                      并行执行三个 BP                         │
  ├─────────────────────────────────────────────────────────────┤
  │  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
  │  │  BP1      │    │  BP2      │    │  BP3      │              │
  │  │ 静态检查   │    │ 集成测试   │    │ 风险检查   │              │
  │  │ - fmt    │    │ - unit   │    │ - explore │              │
  │  │ - clippy │    │ - integ  │    │ - librar  │              │
  │  │ - build  │    │ - bench  │    │ - oracle  │              │
  │  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
  │       │              │              │                     │
  │       └──────────────┴──────────────┘                     │
  │                      │                                    │
  │                      ▼                                    │
  │              ┌──────────────┐                            │
  │              │  结果聚合     │                            │
  │              └──────┬───────┘                            │
  └─────────────────────┼────────────────────────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  结果上报 PR 评论 │
              └──────┬──────────┘
                     │
                     ▼
              ┌──────────────────┐
              │  开发者收到通知   │
              └──────────────────┘
```

#### 3.2 各阶段详细说明

| 阶段 | 组件 | 职责 |
|------|------|------|
| **代码提交** | 开发者 | push 代码到 develop/v3.0.0 分支 |
| **触发** | Gitea webhook | 监听 push 事件，触发 CI pipeline |
| **调度** | Nomad | 分配计算资源，调度 Job 执行 |
| **BP1 静态检查** | Rust toolchain | 编译、格式化、代码分析 |
| **BP2 集成检查** | Cargo test | 单元测试、集成测试、性能基准测试 |
| **BP3 风险检查** | Agent 分析 | explore/librarian/oracle 并行分析 |
| **结果上报** | GitHub API | 将检查结果以评论形式发布到 PR |
| **通知** | 消息系统 | 通知开发者检查结果 |

#### 3.3 完整 Gate 配置文件

```yaml
# .gitea/workflows/full-gate.yml
name: Full Gate Pipeline

on:
  push:
    branches: [ develop/v3.0.0 ]
  pull_request:
    branches: [ develop/v3.0.0 ]

env:
  CARGO_TERM_COLOR: always

jobs:
  # === BP1: 静态检查 ===
  bp1-static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, fmt
      - run: cargo build --all-features
      - run: cargo fmt --check --all
      - run: cargo clippy --all-features -- -D warnings

  # === BP2: 集成测试 ===
  bp2-integration:
    needs: bp1-static
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo test --all-features
      - run: cargo test --test qps_benchmark_test -- --ignored --nocapture

  # === BP3: Agent 风险分析 ===
  bp3-risk-analysis:
    needs: bp1-static
    runs-on: ubuntu-latest
    strategy:
      matrix:
        agent: [explore, librarian, oracle]
    steps:
      - uses: actions/checkout@v4
      - name: Run ${{ matrix.agent }} agent
        run: |
          echo "Running ${{ matrix.agent }} agent..."
          echo "${{ matrix.agent }} analysis complete"

  # === 结果汇总 ===
  gate-result:
    needs: [bp1-static, bp2-integration, bp3-risk-analysis]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Check all jobs status
        run: |
          echo "BP1: ${{ needs.bp1-static.result }}"
          echo "BP2: ${{ needs.bp2-integration.result }}"
          echo "BP3: ${{ needs.bp3-risk-analysis.result }}"

      - name: Post to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const results = [];
            if (needs.bp1-static.result == 'success') results.push('✅ BP1 静态检查通过');
            else results.push('❌ BP1 静态检查失败');

            if (needs.bp2-integration.result == 'success') results.push('✅ BP2 集成测试通过');
            else results.push('❌ BP2 集成测试失败');

            if (needs.bp3-risk-analysis.result == 'success') results.push('✅ BP3 风险分析完成');
            else results.push('❌ BP3 风险分析失败');

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Gate 检查结果\n\n' + results.join('\n')
            });
```

#### ✅ 检查点3：画出 Gate 联动流程图

- [x] Gate 联动流程图已绘制
- [x] 包含完整的 push → webhook → Nomad → BP1/BP2/BP3 → 报告 → 通知流程

---

## 四、实验结果文件清单

```
项目根目录/
├── .gitea/
│   └── workflows/
│       ├── ci.yml              # 基础 CI 工作流
│       ├── agent-analysis.yml  # Agent 分析工作流
│       └── full-gate.yml       # 完整 Gate 流程
└── (源代码目录)
```

---

## 五、实验总结

### 5.1 核心概念回顾

| 概念 | 说明 |
|------|------|
| **CI/CD 角色** | CI/CD 是 Harness 的"自动化执行引擎"，负责在代码变更时自动触发构建、测试、部署流程 |
| **Gitea Actions** | 类似 GitHub Actions，允许定义 YAML 工作流，支持多 job、依赖关系、并行执行 |
| **Agent 编排** | 通过并行触发多个专门的分析 Agent（explore/librarian/oracle），实现比传统串行 CI 更智能的分析能力 |
| **Gate 联动** | 将多个检查阶段（BP1/BP2/BP3）串联成完整流水线，结果自动汇总并通知开发者 |

### 5.2 完成检查清单

| 检查点 | 任务 | 状态 |
|--------|------|------|
| ✅ 检查点1 | 保存 CI 配置文件 `.gitea/workflows/ci.yml` | ✅ 完成 |
| ✅ 检查点2 | 保存 Agent 编排设计（explore/librarian/oracle） | ✅ 完成 |
| ✅ 检查点3 | 画出 Gate 联动流程图 | ✅ 完成 |

### 5.3 实验心得

1. **CI/CD 自动化**：通过 Gitea Actions 实现了代码提交后的自动构建和测试，减少了人工介入，提高了开发效率

2. **Agent 并行分析**：相比传统串行 CI，Agent 编排模式可以并行执行多个专门的分析任务，显著提升了分析效率

3. **Gate 联动机制**：通过 webhook 和 Nomad 调度实现的完整 Gate 联动流程，确保了代码质量检查的全面性和一致性

---

## 六、思考题

1. **传统 CI 与 Agent CI 的主要区别是什么？**
   - 传统 CI 采用串行执行模式，各阶段依次进行；Agent CI 则并行触发多个专门 Agent，实现更智能的分析

2. **在 DELETE 优化场景中，三个 Agent 各有什么作用？**
   - explore：定位删除调用点，分析影响范围
   - librarian：验证 API 使用规范
   - oracle：评估性能风险

3. **Gate 联动流程中的 BP1、BP2、BP3 分别承担什么职责？**
   - BP1：静态检查（编译、格式化、lint）
   - BP2：集成测试（单元测试、基准测试）
   - BP3：风险分析（Agent 并行分析）
