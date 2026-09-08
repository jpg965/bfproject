# 工作流规则

> **适用场景**: 项目级别的通用操作，如依赖安装、构建、Git 提交、新增模块等。

---

## 项目启动

```bash
# 安装依赖（首次或 package.json 变更后）
pnpm install --no-frozen-lockfile

# 并行启动前后端
pnpm dev

# 分别启动
pnpm dev:frontend   # → http://localhost:5173
pnpm dev:backend    # → http://localhost:3001
```

---

## 构建流程

```bash
# 完整构建（按依赖顺序：shared → backend → frontend）
pnpm build

# 单独构建
pnpm build:shared
pnpm build:backend
pnpm build:frontend
```

⚠️ 修改 `shared` 包后必须重新构建，否则前后端无法获取最新类型。

---

## 添加新模块

### 新增共享类型

1. 编辑 `packages/shared/src/index.ts`
2. 添加新领域的分块注释和类型定义
3. 运行 `pnpm build:shared`
4. 前后端自动生效

### 新增后端 API 路由

1. 在 `shared` 中定义请求/响应类型
2. 创建 `packages/backend/src/routes/xxx.routes.ts`
3. 在 `packages/backend/src/index.ts` 中注册路由
4. 测试: `curl http://localhost:3001/api/v1/xxx`

### 新增前端页面

1. 创建 `packages/frontend/src/views/XxxView.vue`
2. 如需复用逻辑，创建 `packages/frontend/src/composables/useXxx.ts`
3. 使用 `shared` 包中的类型

---

## Git 提交规范

```bash
# 提交格式
<type>: <中文描述>

# type 类型
feat:     新功能
fix:      Bug 修复
refactor: 重构
style:    样式调整
docs:     文档更新
chore:    构建/工具变更
perf:     性能优化
test:     测试

# 示例
git commit -m "feat: 添加用户详情页"
git commit -m "fix: 修复暗色主题表格边框颜色"
git commit -m "refactor: 提取 users API 路由模块"
git commit -m "docs: 添加 AI 编码规范文件"
```

---

## 命名速查

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件/目录 | kebab-case | `user-service.ts`, `use-users.ts` |
| Vue 组件文件 | PascalCase | `UserList.vue`, `UserDetail.vue` |
| 类型/接口 | PascalCase | `User`, `CreateUserRequest` |
| 变量/函数 | camelCase | `fetchUsers`, `userList` |
| 常量 | UPPER_SNAKE_CASE | `API_PREFIX`, `MAX_PAGE_SIZE` |
| 组合式函数 | `use` 前缀 | `useUsers`, `useAuth` |

---

## 环境变量

```bash
# 后端端口（默认 3001）
PORT=3001

# 前端端口（默认 5173，在 vite.config.ts 中配置）
```

---

## 常用 pnpm 命令

```bash
# 在指定包中执行命令
pnpm --filter frontend dev
pnpm --filter backend add <package>
pnpm --filter shared build

# 并行执行
pnpm --parallel dev

# 清理所有构建产物
pnpm clean
```

---

## 禁止事项

- 禁止手动编辑 `pnpm-lock.yaml`
- 禁止提交 `.env` / `.env.local` 等敏感文件
- 禁止跳过 shared 构建直接修改前后端类型引用
- 禁止在单文件中堆积超过 300 行代码
- 禁止使用 `any` 类型（除非必要并注明原因）