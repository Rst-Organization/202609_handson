import { createServer } from 'node:http';
import { createStore } from './store.js';

const PORT = process.env.PORT || 3000;
const store = createStore();

// 起動時のサンプルデータ（触ってすぐ動きが見えるように）
store.create('Codespaces で環境を立ち上げる');
store.create('Claude Code を起動する');
store.create('演習1に取り組む');

function send(res, status, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  if (chunks.length === 0) {
    return {};
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null;
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // GET /tasks
  if (req.method === 'GET' && path === '/tasks') {
    const doneParam = url.searchParams.get('done');
    const filter = doneParam === null ? {} : { done: doneParam === 'true' };
    return send(res, 200, { tasks: store.list(filter) });
  }

  // POST /tasks
  if (req.method === 'POST' && path === '/tasks') {
    const body = await readJson(req);
    if (body === null) {
      return send(res, 400, { error: 'invalid JSON body' });
    }
    const result = store.create(body.title);
    return result.ok
      ? send(res, 201, result.value)
      : send(res, 400, { error: result.error });
  }

  // POST /tasks/:id/complete
  const completeMatch = path.match(/^\/tasks\/(\d+)\/complete$/);
  if (req.method === 'POST' && completeMatch) {
    const result = store.complete(Number(completeMatch[1]));
    return result.ok
      ? send(res, 200, result.value)
      : send(res, 404, { error: result.error });
  }

  // DELETE /tasks/:id
  const deleteMatch = path.match(/^\/tasks\/(\d+)$/);
  if (req.method === 'DELETE' && deleteMatch) {
    const result = store.remove(Number(deleteMatch[1]));
    return result.ok
      ? send(res, 200, result.value)
      : send(res, 404, { error: result.error });
  }

  send(res, 404, { error: 'not found' });
});

server.listen(PORT, () => {
  console.log(`タスクAPI が起動しました: http://localhost:${PORT}/tasks`);
});
