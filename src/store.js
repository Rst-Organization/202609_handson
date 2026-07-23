import { validateTitle } from './validate.js';

/**
 * タスクのインメモリ保管庫。
 * プロセスを再起動すると消える。セミナー用途では十分。
 */
export function createStore() {
  const tasks = new Map();
  let nextId = 1;

  return {
    create(title) {
      const result = validateTitle(title);
      if (!result.ok) {
        return result;
      }

      const task = {
        id: nextId++,
        title: result.value,
        done: false,
        createdAt: new Date().toISOString(),
      };
      tasks.set(task.id, task);

      return { ok: true, value: task };
    },

    list({ done } = {}) {
      const all = [...tasks.values()];
      if (done === undefined) {
        return all;
      }
      return all.filter((task) => task.done === done);
    },

    get(id) {
      const task = tasks.get(id);
      if (!task) {
        return { ok: false, error: `task ${id} not found` };
      }
      return { ok: true, value: task };
    },

    complete(id) {
      const task = tasks.get(id);
      if (!task) {
        return { ok: false, error: `task ${id} not found` };
      }
      task.done = true;
      return { ok: true, value: task };
    },

    remove(id) {
      if (!tasks.has(id)) {
        return { ok: false, error: `task ${id} not found` };
      }
      tasks.delete(id);
      return { ok: true, value: { id } };
    },

    count() {
      return tasks.size;
    },
  };
}
