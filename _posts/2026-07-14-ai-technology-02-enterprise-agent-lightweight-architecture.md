---
title: "AI 技术沉淀 | 第2篇：企业级 Agent 轻量架构设计"
date: 2026-07-14 12:00:00 +0800
categories: [Tech, AI 技术沉淀]
tags: [AI, Agent, AgentScope, Redis, 架构设计]
toc: true
---

企业级 Agent 系统的核心问题不只是接入大模型，还需要建立可扩展的请求调度、会话隔离、状态管理、流式输出和可观测机制。应用入口可以是 Web 应用、IM 机器人、任务下发平台、内部 API 或自动化工作流。入口形态不同，但进入 Agent 执行层后，应遵循统一的消息协议和运行模型。

本文基于当前项目实践，总结出一套轻量架构：应用接入层负责协议适配，Redis Mailbox 负责会话调度，AgentScope Java 2.0 Worker 负责推理与工具执行，状态和工作区存储在共享基础设施中，可观测体系纵向覆盖整条调用链。

[![企业级 Agent 轻量架构](/assets/img/2026-07-14/agent机器人架构.drawio.svg)](/assets/img/2026-07-14/agent机器人架构.drawio.svg){: target="_blank" rel="noopener" }

点击架构图可在新标签页打开 SVG 原图，并使用浏览器缩放查看。

## 名词解释

本文对核心术语作如下约定。代码字段和 Redis Key 保留原始命名，正文统一使用表中的中文或英文名称。

| 名词 | 解释 |
|---|---|
| Agent | 由大模型、提示词、记忆、规划、Skill 和工具调用组成的执行单元。 |
| Worker | 承载 Agent Runtime 的计算节点，负责消费任务、恢复状态并执行 Agent。 |
| 会话（Session） | 一组需要共享上下文并按顺序处理的请求，是调度与状态隔离的基本边界。 |
| Mailbox | 以会话为单位组织消息的调度模式，由 Inbox、Wakeup 和会话锁共同实现。 |
| Inbox | 每个会话独立的 FIFO 消息队列，保存完整入站消息，是待处理消息的事实来源。 |
| Wakeup | 不携带消息正文的轻量唤醒事件，用于通知 Worker 检查指定 Inbox。 |
| Agent Runtime | 根据 Agent 配置构建的运行时实例，封装模型、Skill、工具和状态存储。 |
| AgentStateStore | AgentScope 提供的状态存储抽象，用于外置会话状态。 |
| Outbound Stream | Worker 向网关发布文本增量片段和状态事件的出站消息流。 |
| 链路追踪（Trace） | 关联一次请求在网关、Worker、模型和工具之间执行过程的观测数据。 |
| PEL | Redis Stream 的 Pending Entries List，记录已投递但尚未确认的消息。 |
| DLQ | Dead Letter Queue，中文为死信队列，用于隔离持续处理失败的消息。 |

## 1. 架构目标

这套架构围绕以下目标设计：

1. **应用入口泛化**：Web、IM、API 和任务平台使用统一的入站与出站协议。
2. **会话严格隔离**：同一会话内消息串行执行，不同会话并行执行。
3. **Worker 无状态化**：任意 Worker 都可以处理任意会话，请求不绑定固定实例。
4. **流式链路解耦**：Agent 输出事件与客户端展示协议分离。
5. **状态外置**：会话状态、Agent 配置、Skill 和工作区文件不依赖单机进程。
6. **观测统一**：请求、模型、工具、队列和成本数据使用同一链路追踪上下文关联。

系统按职责划分为应用层、网关层、Redis 层、Worker 层和可观测体系。各层通过稳定协议连接，避免业务逻辑与客户端 SDK、消息中间件或模型供应商耦合。

## 2. 应用层：从单一入口扩展为统一客户端概念

应用层不限定为某一种 IM 平台，可以包括：

- Web 对话应用；
- IM 单聊、群聊和频道机器人；
- 工单、告警和研发协作平台；
- 定时任务和批处理任务；
- 内部 API、OpenAPI 或事件驱动客户端；
- 需要 Agent 能力的业务系统。

不同客户端的认证方式、消息结构和流式能力存在差异。网关需要将这些差异收敛为统一的 `InboundMessage`，至少包含：

```json
{
  "req_id": "request-uuid",
  "msg_id": "message-uuid",
  "agent_id": "default-agent",
  "session_id": "app:tenant:user-or-conversation",
  "user_id": "user-id",
  "content": "用户输入",
  "attachments": [],
  "timestamp": 1700000000
}
```

其中，`session_id` 是调度和状态隔离的核心字段。它不应直接等同于用户 ID，而应根据业务上下文设计。例如：

```text
Web 私有会话：web:{tenantId}:{userId}:{conversationId}
IM 单聊：     im:{tenantId}:{userId}
IM 群聊：     im:{tenantId}:{groupId}
任务执行：    task:{tenantId}:{taskId}
```

多 Agent 场景还应将 `agent_id` 纳入状态命名空间，避免不同 Agent 共享同一会话状态。

## 3. 网关层：协议适配而非 Agent 执行

网关负责客户端协议与内部消息协议之间的转换，主要职责包括：

- 连接管理、认证和客户端 SDK 适配；
- 用户、租户、会话和 Agent 路由；
- 消息格式归一化和附件处理；
- `msg_id` 幂等校验；
- 限流、请求大小控制和基础安全检查；
- 入站消息写入 Mailbox；
- 消费出站事件，并转换为 SSE、WebSocket、HTTP Chunk 或 IM 流式回复。

网关不执行模型推理，不保存 Agent 长期状态，也不承担复杂工具调用。这样可以独立扩展协议接入能力，并减少客户端连接生命周期对 Agent 执行资源的影响。

流式输出也应在网关完成协议适配。Worker 统一输出文本增量片段（Delta）、思考状态、工具开始、工具结束和错误事件。Web 客户端可以直接消费增量片段，部分 IM 客户端要求每次刷新发送当前完整内容。网关负责聚合和渲染，Agent Runtime 不感知客户端展示规则。

## 4. Mailbox：以会话为单位的调度模型

### 4.1 全局队列不能直接解决会话顺序

一种常见实现是将所有消息写入全局 Redis Stream，由多个 Worker 消费，再通过分布式 FairLock 控制同一会话的并发。这种方案不能严格保证业务消息顺序。

假设同一会话连续产生消息 `M1` 和 `M2`。两条消息被不同消费线程读取后，`M2` 所在线程可能先向 Redis 发起锁请求。FairLock 能保证锁请求到达 Redis 后的排队顺序，但不能恢复 `M1`、`M2` 的业务创建顺序。

顺序约束需要落在消息存储结构上，而不是依赖线程调度和锁竞争时序。

### 4.2 Inbox 与 Wakeup 分离

Mailbox 将“消息数据”和“调度信号”分开：

| 逻辑对象 | Redis 结构 | 作用 |
|---|---|---|
| `inbox:{sessionId}` | List | 保存完整消息，`RPUSH`、`LPOP` 保证会话内 FIFO |
| `wakeups` | Stream | 只携带会话元数据，通知 Worker 有消息需要处理 |
| `lock:session:{sessionId}` | String | 保证同一会话同时只有一个 Worker 排空 Inbox |
| `outbound` | Stream | 承载 Agent 文本增量片段和状态事件 |
| `dedup:{msgId}` | String | 入口消息幂等控制 |

网关的写入顺序为：

```text
1. SET NX EX dedup:{msgId}
2. RPUSH inbox:{sessionId} <InboundMessage JSON>
3. XADD wakeups * session_id <sessionId> agent_id <agentId>
```

Wakeup 不保存消息正文，也不是业务事实的唯一来源。它可以重复投递，也可以被合并，其作用只是促使某个 Worker 检查对应 Inbox。真正需要处理的数据始终保存在 Inbox 中。

### 4.3 Worker 消费流程

Worker 通过 Redis Stream 消费者组消费 Wakeup，处理过程如下：

```text
XREADGROUP wakeups
    -> tryLock(lock:session:{sessionId})
        -> 成功：LPOP inbox:{sessionId}，按 FIFO 连续处理
        -> 失败：延迟重新投递 Wakeup，不阻塞全局消费线程
    -> 达到 maxDrainPerWakeup 或 Inbox 为空
    -> Lua 校验锁令牌后释放会话锁
    -> XACK Wakeup
```

会话锁需要设置存活时间（TTL），并在 Agent 长任务执行期间续租。释放锁时必须校验锁令牌（Token），避免旧 Worker 在锁超时后误删其他 Worker 获取的新锁。

单次排空应设置上限。例如每次最多处理 20 条消息，处理完成后如果 Inbox 仍有数据，再投递新的 Wakeup。该机制可以避免活跃会话长时间占用 Worker，使多个会话之间保持调度公平。

### 4.4 Mailbox 的并发语义

Mailbox 形成两层并发控制：

- **会话内串行**：Redis List 的 FIFO 顺序与会话锁共同保证消息顺序和状态一致性；
- **会话间并行**：不同会话使用不同 Inbox 和会话锁，可以由不同 Worker 同时处理。

这符合 Agent 会话的并发模型。记忆（Memory）和规划（Plan）通常以会话为边界。同一会话并发修改状态容易产生覆盖，不同会话之间没有顺序依赖，可以并行调用模型和工具。

### 4.5 数据与信号分离的收益

Inbox 与 Wakeup 分离后，系统具备以下特性：

1. 消息顺序由 Redis List 的物理顺序保证；
2. Wakeup 重复投递不会导致业务消息重复，只会重复检查 Inbox；
3. 锁竞争失败时可以重新唤醒，不需要阻塞 Redis Stream 消费线程；
4. 消息正文不在全局 Redis Stream 中重复流转，降低调度事件体积；
5. 同一会话的多次 Wakeup 可以由一个持锁 Worker 一次排空；
6. Worker 扩缩容不改变会话顺序语义。

### 4.6 生产化边界

Mailbox 不替代可靠消息治理。生产环境还需要补充：

- 使用 Lua 或 Redis 事务保证 `RPUSH` 与 `XADD` 的一致性；
- 定期扫描非空 Inbox，修复消息已入队但 Wakeup 丢失的情况；
- 通过 `XPENDING`、`XAUTOCLAIM` 恢复 Worker 异常退出后滞留在 PEL 中的消息；
- 设置 DLQ，隔离无法解析或持续处理失败的消息；
- 对 Wakeup Stream 和 Outbound Stream 配置保留与裁剪策略；
- 记录重试次数、最后错误和下一次执行时间；
- 对 Inbox 长度、Wakeup 积压延迟、锁等待时间和处理时长建立告警。

## 5. AgentScope Java 2.0 与无状态 Worker

AgentScope Java 2.0 的 API 设计天然适合构建无状态 Worker：`RuntimeContext` 显式传递请求边界，`AgentStateStore` 外置会话状态，事件流按调用返回，Agent Runtime 不需要绑定固定节点。

### 5.1 RuntimeContext 定义请求边界

每条消息进入 Agent 前构造独立的运行上下文：

```java
RuntimeContext context = RuntimeContext.builder()
    .userId(message.userId())
    .sessionId(message.sessionId())
    .put("req_id", message.reqId())
    .put("agent_id", message.agentId())
    .build();
```

`userId`、`sessionId` 和扩展元数据随调用传递，不依赖线程本地变量，也不要求请求回到创建会话的 Worker。任意 Worker 获取相同的会话标识后，都可以恢复对应的 Agent 上下文。

### 5.2 AgentStateStore 外置会话状态

AgentScope 通过 `AgentStateStore` 抽象注入状态存储。当前架构采用 Redis 与 MySQL 两层存储：

```text
读取：Redis 热缓存 -> 未命中读取 MySQL -> 回填 Redis
写入：MySQL 持久化 -> 更新 Redis 热缓存
```

MySQL 是持久化事实源，Redis 用于降低活跃会话的读取延迟。Worker 重启、发布或迁移后，可以从共享状态存储恢复会话，不需要粘滞会话（Sticky Session）。

状态 Key 应包含以下隔离维度：

```text
agent_id + tenant_id + user_id + session_id + state_slot
```

如果只使用 `user_id + session_id`，多 Agent 或多租户场景可能发生状态串用。

### 5.3 工作区外置

HarnessAgent 可能读取项目文件、生成中间产物或调用 Shell。纯本地工作区会使会话隐式绑定到某个 Worker。

当前架构通过 S3/MinIO 叠加文件系统（Overlay）处理工作区：本地目录用于执行和缓存，持久文件同步到共享对象存储。新的 Worker 可以从对象存储恢复工作区，避免节点切换导致文件不可见。

对于需要强一致性的写操作，应增加同步写入、版本号或 ETag 冲突检查。异步上传适合缓存和可重建产物，不适合作为关键事务数据的唯一提交方式。

### 5.4 Agent Runtime 缓存不参与正确性

Agent 实例、模型客户端和 Skill 仓库的构建存在成本，可以在 Worker 本地使用 Caffeine 缓存。缓存键由以下字段组成：

```text
agent_id + agent_type + config_version
```

数据库保存 Agent 配置事实，`config_version` 控制版本切换，Redis Pub/Sub 只用于加速本地旧 Agent Runtime 的失效。即使 Worker 未收到失效事件，新请求读取到新版本后仍会构建正确的 Agent Runtime。

Skill 可以按 `agent_id + config_version` 从数据库物化为本地只读目录，再交给 AgentScope 的 `FileSystemSkillRepository` 加载。本地缓存可以删除和重建，不构成分布式一致性的来源。

### 5.5 水平扩展模型

完成状态外置后，Worker 节点具备对称性：

- 每个 Worker 加入同一个 Wakeup 消费者组；
- 任意 Worker 都能消费任意会话的 Wakeup；
- 会话锁保证同一会话只有一个执行者；
- AgentStateStore 恢复会话状态；
- S3/MinIO 恢复共享工作区；
- Agent 配置和 Skill 通过数据库版本化加载；
- 输出统一写入 Outbound Stream。

因此，Worker 可以按 Wakeup 积压量、活跃会话数、Agent 执行延迟或 CPU 指标水平扩展。Java 21 虚拟线程适合承载模型请求、Redis、数据库和工具调用等 I/O 等待，但并发上限仍需受模型配额、数据库连接池、工具容量和成本预算约束。

这里的“无状态”是运行时语义上的无状态：进程内可以存在缓存和正在执行的流，但这些数据不作为跨请求正确性的唯一来源。节点退出后，后续请求可以由其他节点继续处理。

## 6. 出站事件与客户端渲染解耦

Agent 执行过程中会产生多类事件：

```text
text        模型正文增量片段
thinking    临时思考状态
tool_start  工具开始
tool_done   工具完成
notice      可保留的系统提示
error       用户可见错误
```

Worker 将事件写入 Outbound Stream，网关根据客户端能力进行转换：

- Web 应用可以通过 SSE 或 WebSocket 直接消费事件；
- 支持增量更新的客户端可以直接渲染文本增量片段；
- 要求完整内容快照的客户端由网关累积后发送；
- 不需要展示内部工具流水的客户端可以只保留最终正文；
- 任务型客户端可以将最终结果写入数据库、Webhook 或回调接口。

这种设计使 Agent Runtime 专注于推理与工具执行，客户端交互策略由网关负责。

## 7. 可观测体系纵向贯穿

一次 Agent 请求包含网关排队、会话调度、状态恢复、模型推理、工具调用和流式回传等阶段。只记录应用日志无法判断延迟和成本来自哪个环节。

系统使用 `req_id`、`session_id`、`user_id` 和 `agent_id` 贯穿消息协议与链路追踪：

```text
网关 / Worker / AgentScope
        -> OpenTelemetry Collector
            -> Langfuse：Prompt、Generation、Token、成本、工具 Observation
            -> Jaeger：跨组件链路追踪和耗时瀑布图
        -> Actuator / Prometheus：健康状态与运行指标
        -> Structured Logs：按 req_id 检索日志
```

建议重点采集以下指标：

- Inbox 长度、Wakeup 积压延迟、PEL 消息数和 DLQ 消息数；
- 会话锁获取失败率、续租失败率和持锁时间；
- 每次 Wakeup 的排空数量和会话等待时间；
- Agent 总耗时、首 Token 延迟和流式完成耗时；
- 模型请求次数、Token、成本、限流和错误率；
- 工具调用次数、耗时、失败率和超时率；
- Outbound Stream 积压延迟与客户端发送失败率；
- Worker 活跃任务数、虚拟线程数和连接池使用率。

## 8. 轻量架构的部署边界

这套架构不要求在初期引入完整的 Kubernetes 和独立消息平台。单套 Redis、MySQL、对象存储、多个 Worker 和一个或多个网关即可建立运行闭环。生产部署时，需要根据入口协议确定网关的扩展方式：

- HTTP、SSE 和普通 WebSocket 网关可以通过负载均衡水平扩展；
- 存在单连接约束的 IM 通道需要主节点选举（Leader Election）或主备切换；
- Worker 通过 Wakeup 消费者组水平扩展；
- Redis、MySQL 和对象存储负责共享状态，需要独立的高可用与备份策略。

上线前还需要完善以下控制面：

1. Redis PEL 恢复、重试和 DLQ；
2. Agent 总超时、模型超时和工具超时；
3. Shell 沙箱、命令白名单、RBAC 和审计日志；
4. Prompt 注入防护、敏感信息脱敏和密钥管理；
5. Token 预算、模型分级和租户限流；
6. Agent 配置变更审计和版本回滚；
7. 队列堆积、模型错误率和成本预算告警。

## 9. 总结

企业级 Agent 轻量架构可以归纳为五项原则：

1. 应用入口泛化，网关只负责协议适配；
2. 使用 Mailbox 保存会话内的业务顺序，Wakeup 只负责调度；
3. 同一会话串行，不同会话并行；
4. 利用 AgentScope Java 2.0 的 `RuntimeContext` 和 `AgentStateStore`，将 Worker 设计为可重建、可水平扩展的计算节点；
5. 将状态、工作区、配置和可观测数据放入共享基础设施。

Mailbox 解决消息顺序与调度问题，AgentScope 解决 Agent Runtime 与状态抽象问题。两者结合后，应用入口、Agent 执行和状态管理之间形成稳定边界，可以在不改变核心调度语义的前提下扩展客户端、Worker、模型、工具和 Agent 类型。
