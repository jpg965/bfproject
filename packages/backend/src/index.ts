import express from 'express';
import cors from 'cors';
import { ApiResponse, User, API_PREFIX, PAGINATION } from 'shared';

const app = express();
const PORT = process.env.PORT || 3001;

// ---- Middleware ----
app.use(cors({ origin: 'http://localhost:5173' }));
app.use(express.json());

// ---- Mock data ----
const users: User[] = [
  { id: 1, name: 'Alice', email: 'alice@example.com', role: 'admin', createdAt: '2024-01-15' },
  { id: 2, name: 'Bob', email: 'bob@example.com', role: 'editor', createdAt: '2024-03-20' },
  { id: 3, name: 'Charlie', email: 'charlie@example.com', role: 'viewer', createdAt: '2024-06-10' },
];

// ---- Routes ----
app.get(`${API_PREFIX}/health`, (_req, res) => {
  const response: ApiResponse = { code: 0, message: 'ok', data: null };
  res.json(response);
});

app.get(`${API_PREFIX}/users`, (req, res) => {
  const page = Math.max(Number(req.query.page) || PAGINATION.DEFAULT_PAGE, 1);
  const pageSize = Math.min(
    Number(req.query.pageSize) || PAGINATION.DEFAULT_PAGE_SIZE,
    PAGINATION.MAX_PAGE_SIZE,
  );

  const response: ApiResponse = {
    code: 0,
    message: 'ok',
    data: {
      list: users,
      total: users.length,
      page,
      pageSize,
    },
  };
  res.json(response);
});

app.get(`${API_PREFIX}/users/:id`, (req, res) => {
  const user = users.find((u) => u.id === Number(req.params.id));
  if (!user) {
    res.status(404).json({ code: 404, message: 'User not found', data: null } as ApiResponse);
    return;
  }
  res.json({ code: 0, message: 'ok', data: user } as ApiResponse);
});

// ---- Start ----
app.listen(PORT, () => {
  console.log(`Backend running at http://localhost:${PORT}`);
  console.log(`API base: http://localhost:${PORT}${API_PREFIX}`);
});