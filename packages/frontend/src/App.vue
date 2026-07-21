<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { User, ApiResponse, PaginatedData, API_PREFIX } from 'shared';
import { UserFilled } from '@element-plus/icons-vue';

const users = ref<User[]>([]);
const loading = ref(true);
const error = ref('');

const roleMap: Record<string, { label: string; type: '' | 'success' | 'warning' | 'info' }> = {
  admin: { label: '管理员', type: '' },
  editor: { label: '编辑者', type: 'success' },
  viewer: { label: '观察者', type: 'info' },
};

const fetchUsers = async () => {
  loading.value = true;
  error.value = '';
  try {
    const res = await fetch(`${API_PREFIX}/users`);
    const json: ApiResponse<PaginatedData<User>> = await res.json();
    if (json.code === 0) {
      users.value = json.data.list;
    } else {
      error.value = json.message;
    }
  } catch (err: any) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};

onMounted(fetchUsers);
</script>

<template>
  <el-container class="app-container">
    <el-header class="app-header">
      <div class="header-content">
        <h1>Monorepo 全栈应用</h1>
        <el-tag type="primary" effect="dark" round>Vue 3 + Element Plus</el-tag>
      </div>
    </el-header>

    <el-main class="app-main">
      <el-card shadow="hover">
        <template #header>
          <div class="card-header">
            <el-icon :size="20"><UserFilled /></el-icon>
            <span class="card-title">用户列表</span>
            <el-tag size="small" type="info">{{ API_PREFIX }}/users</el-tag>
          </div>
        </template>

        <el-alert
          v-if="error"
          :title="`请求失败: ${error}`"
          type="error"
          show-icon
          :closable="false"
          style="margin-bottom: 16px"
        />

        <el-skeleton v-if="loading" :rows="5" animated />

        <el-table
          v-else
          :data="users"
          stripe
          style="width: 100%"
          empty-text="暂无数据"
        >
          <el-table-column prop="id" label="ID" width="80" align="center" />
          <el-table-column prop="name" label="姓名" min-width="120" />
          <el-table-column prop="email" label="邮箱" min-width="200" />
          <el-table-column prop="role" label="角色" width="120" align="center">
            <template #default="{ row }">
              <el-tag
                :type="roleMap[row.role]?.type ?? 'info'"
                effect="plain"
                size="small"
              >
                {{ roleMap[row.role]?.label ?? row.role }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="createdAt" label="创建时间" width="140" align="center" />
        </el-table>
      </el-card>
    </el-main>
  </el-container>
</template>

<style scoped>
.app-container {
  min-height: 100vh;
  background: var(--el-bg-color-page);
}

.app-header {
  background: linear-gradient(135deg, #1a3a5c, #2a5298);
  display: flex;
  align-items: center;
  padding: 0 24px;
}

.header-content {
  display: flex;
  align-items: center;
  gap: 16px;
  width: 100%;
}

.header-content h1 {
  margin: 0;
  font-size: 1.25rem;
  color: #fff;
  font-weight: 600;
}

.app-main {
  max-width: 960px;
  margin: 24px auto;
  padding: 0 20px;
  width: 100%;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
}

.card-title {
  font-size: 1rem;
  font-weight: 600;
}
</style>