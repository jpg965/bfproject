# Shared 共享类型规则

> **适用场景**: 开发或修改 `packages/shared` 中的共享类型与常量时加载此规则。

---

## 核心原则

- **只放类型和常量**，禁止引入运行时代码或第三方依赖
- 前后端通过 `import { ... } from 'shared'` 引用
- 按领域分块组织，使用注释分隔

---

## 文件结构模板

```typescript
// packages/shared/src/index.ts

// ============ API 通用类型 ============

export interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T;
}

export interface PaginatedData<T> {
  list: T[];
  total: number;
  page: number;
  pageSize: number;
}

// ============ 用户相关类型 ============

export interface User {
  id: number;
  name: string;
  email: string;
  role: UserRole;
  createdAt: string;
}

export type UserRole = 'admin' | 'editor' | 'viewer';

export interface CreateUserRequest {
  name: string;
  email: string;
  role: UserRole;
}

export interface UpdateUserRequest {
  name?: string;
  email?: string;
  role?: UserRole;
}

// ============ 通用常量 ============

export const API_PREFIX = '/api/v1';

export const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_SIZE: 10,
  MAX_PAGE_SIZE: 100,
} as const;
```

---

## 类型定义规范

```typescript
// ✅ 正确：interface 定义对象类型
export interface User { id: number; name: string; }

// ✅ 正确：type 定义联合类型
export type UserRole = 'admin' | 'editor' | 'viewer';

// ✅ 正确：as const 定义只读常量
export const PAGINATION = { DEFAULT_PAGE: 1 } as const;

// ❌ 错误：引入运行时依赖
import axios from 'axios'; // 禁止

// ❌ 错误：定义函数/类
export function formatUser(user: User) { ... } // 禁止

// ❌ 错误：default export
export default interface User { ... } // 禁止，必须用 named export
```

---

## 添加新领域的步骤

1. 在 `shared/src/index.ts` 末尾添加分块注释
2. 定义该领域的数据类型（`interface`）
3. 定义请求体类型（`CreateXxxRequest` / `UpdateXxxRequest`）
4. 定义相关常量
5. 运行 `pnpm --filter shared build` 编译
6. 前后端通过 `import { ... } from 'shared'` 引用

---

## 引用方式

```typescript
// 前端 (packages/frontend/package.json)
"dependencies": { "shared": "workspace:*" }

// 后端 (packages/backend/package.json)
"dependencies": { "shared": "workspace:*" }

// 使用
import { User, ApiResponse, API_PREFIX } from 'shared';
```

---

## 编译配置

```json
// packages/shared/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}
```

```json
// packages/shared/package.json
{
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "require": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  }
}
```

---

## 禁止事项

- 禁止在 shared 包中引入运行时依赖（如 axios, lodash）
- 禁止在 shared 包中定义函数、类或可执行代码
- 禁止使用 `default export`
- 禁止在 shared 包中引用前端或后端包