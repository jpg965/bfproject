# Vue 3 前端开发规则

> **适用场景**: 开发或修改 `packages/frontend` 中的 Vue 3 代码时加载此规则。

---

## 核心原则

- 使用 Vue 3 Composition API + `<script setup lang="ts">`
- 所有 UI 组件优先使用 Element Plus
- 暗色主题通过 CSS 变量适配，禁止硬编码颜色
- 类型定义从 `shared` 包导入，禁止在组件内重复定义

---

## 组件模板

```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ApiResponse, User } from 'shared';
import { ElMessage } from 'element-plus';

// Props
const props = defineProps<{ userId: number }>();

// State
const loading = ref(false);
const data = ref<User | null>(null);

// Methods
const fetchData = async () => {
  loading.value = true;
  try {
    const res = await fetch(`/api/v1/users/${props.userId}`);
    const json: ApiResponse<User> = await res.json();
    if (json.code === 0) data.value = json.data;
  } catch (err) {
    ElMessage.error('请求失败');
  } finally {
    loading.value = false;
  }
};

onMounted(fetchData);
</script>

<template>
  <el-card shadow="hover">
    <el-skeleton v-if="loading" :rows="3" animated />
    <template v-else>
      <!-- 内容 -->
    </template>
  </el-card>
</template>

<style scoped>
/* 使用 Element Plus CSS 变量 */
.card {
  background: var(--el-bg-color);
  color: var(--el-text-color-primary);
}
</style>
```

---

## Element Plus 组件速查

| 场景 | 推荐组件 | 示例 |
|------|---------|------|
| 布局 | `el-container` / `el-header` / `el-main` | 页面整体布局 |
| 容器 | `el-card` | 卡片内容区 |
| 表格 | `el-table` + `el-table-column` | 数据列表 |
| 表单 | `el-form` + `el-form-item` + `el-input` | 增改表单 |
| 弹窗 | `el-dialog` | 确认框 / 详情 |
| 加载 | `el-skeleton` | 骨架屏 |
| 提示 | `el-message` / `el-alert` | 操作反馈 |
| 标签 | `el-tag` | 状态标签 |
| 按钮 | `el-button` | 操作按钮 |
| 图标 | `@element-plus/icons-vue` 按需导入 | 图标 |

---

## 样式规则

```css
/* ✅ 正确：使用 Element Plus CSS 变量 */
background: var(--el-bg-color-page);
color: var(--el-text-color-primary);
border: 1px solid var(--el-border-color);

/* ❌ 错误：硬编码颜色 */
background: #ffffff;
color: #333333;
```

- 必须使用 `scoped` 样式
- 文件级别全局样式放 `src/styles/` 目录
- 不使用内联 `style` 属性（动态值除外）

---

## API 调用模式

```typescript
// ✅ 正确：使用 shared 包的类型
import { ApiResponse, User, PaginatedData } from 'shared';

const res = await fetch('/api/v1/users');
const json: ApiResponse<PaginatedData<User>> = await res.json();

// ❌ 错误：自定义响应类型
const res = await fetch('/api/v1/users');
const json: any = await res.json(); // 禁止 any
```

- 所有 API 调用通过 Vite proxy 走 `/api/v1` 前缀
- 响应必须用 `ApiResponse<T>` 类型标注
- 必须有 `try/catch` 错误处理

---

## 文件组织

```
packages/frontend/src/
├── main.ts              # 入口：挂载 Vue + Element Plus
├── App.vue              # 根组件
├── components/          # 可复用组件
│   └── UserTable.vue
├── views/               # 页面级组件
│   ├── UserList.vue
│   └── UserDetail.vue
├── composables/         # 组合式函数
│   └── useUsers.ts
├── utils/               # 工具函数
│   └── request.ts
└── styles/              # 全局样式
    └── global.css
```

---

## 禁止事项

- 禁止使用 Options API
- 禁止使用 `any` 类型
- 禁止硬编码颜色值（用 CSS 变量）
- 禁止在模板中直接使用 `fetch`（应封装到 composable）
- 禁止在组件内定义共享类型（应放入 `shared` 包）