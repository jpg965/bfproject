# Express 后端开发规则

> **适用场景**: 开发或修改 `packages/backend` 中的 Express 服务代码时加载此规则。

---

## 核心原则

- Express 4.x + TypeScript + tsx 热重载
- 所有路由以 `/api/v1` 开头，使用 `shared` 包中的 `API_PREFIX`
- 统一 `ApiResponse<T>` 响应格式
- 路由按领域拆分模块，禁止单文件堆砌

---

## 模块模板

```typescript
// src/routes/users.routes.ts
import { Router, Request, Response } from 'express';
import { ApiResponse, User, PaginatedData, API_PREFIX } from 'shared';

const router = Router();

// GET /api/v1/users
router.get(`${API_PREFIX}/users`, (req: Request, res: Response) => {
  const response: ApiResponse<PaginatedData<User>> = {
    code: 0,
    message: 'ok',
    data: { list: [], total: 0, page: 1, pageSize: 10 },
  };
  res.json(response);
});

// GET /api/v1/users/:id
router.get(`${API_PREFIX}/users/:id`, (req: Request, res: Response) => {
  const id = Number(req.params.id);
  // ...
  const user: User | undefined = undefined;
  if (!user) {
    res.status(404).json({ code: 404, message: 'User not found', data: null } as ApiResponse);
    return;
  }
  res.json({ code: 0, message: 'ok', data: user } as ApiResponse<User>);
});

// POST /api/v1/users
router.post(`${API_PREFIX}/users`, (req: Request, res: Response) => {
  const body = req.body;
  // 验证...
  res.status(201).json({ code: 0, message: 'created', data: null } as ApiResponse);
});

export default router;
```

---

## 响应格式规范

| 场景 | HTTP 状态码 | code | message |
|------|-----------|------|---------|
| 查询成功 | 200 | 0 | "ok" |
| 创建成功 | 201 | 0 | "created" |
| 参数错误 | 400 | 400 | 具体错误描述 |
| 未找到 | 404 | 404 | "xxx not found" |
| 服务器错误 | 500 | 500 | "Internal error" |

```typescript
// ✅ 正确：使用 ApiResponse 泛型
res.json({ code: 0, message: 'ok', data: user } as ApiResponse<User>);

// ✅ 正确：分页响应
res.json({ code: 0, message: 'ok', data: { list, total, page, pageSize } } as ApiResponse<PaginatedData<User>>);

// ❌ 错误：自定义响应格式
res.json({ success: true, result: user });
```

---

## 路由 RESTful 约定

| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/api/v1/users` | 查询列表（支持 ?page=&pageSize=） |
| GET | `/api/v1/users/:id` | 查询单条 |
| POST | `/api/v1/users` | 创建 |
| PUT | `/api/v1/users/:id` | 更新 |
| DELETE | `/api/v1/users/:id` | 删除 |

---

## 中间件配置

```typescript
// src/index.ts
import cors from 'cors';
import express from 'express';

const app = express();
app.use(cors({ origin: 'http://localhost:5173' }));
app.use(express.json());
```

- CORS 只允许前端开发地址
- 生产环境应通过环境变量配置

---

## 文件组织

```
packages/backend/src/
├── index.ts              # 入口：Express 实例 + 中间件 + 启动
├── routes/               # 路由模块（按领域拆分）
│   ├── users.routes.ts
│   ├── health.routes.ts
│   └── index.ts          # 统一导出
├── services/             # 业务逻辑层
│   └── users.service.ts
├── middleware/            # 自定义中间件
│   └── error-handler.ts
└── utils/                # 工具函数
    └── response.ts
```

---

## 开发命令

```bash
pnpm --filter backend dev     # 启动热重载开发服务器
pnpm --filter backend build   # 编译 TypeScript
pnpm --filter backend start   # 运行编译产物
```

---

## 禁止事项

- 禁止在路由中直接写业务逻辑（应提取到 services）
- 禁止使用 `any` 类型
- 禁止响应格式不一致（必须用 `ApiResponse`）
- 禁止硬编码 API 前缀（必须用 `shared` 包的 `API_PREFIX`）