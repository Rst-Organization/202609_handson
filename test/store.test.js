import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { createStore } from '../src/store.js';

describe('store', () => {
  test('タスクを作成できる', () => {
    const store = createStore();
    const result = store.create('買い物に行く');

    assert.equal(result.ok, true);
    assert.equal(result.value.title, '買い物に行く');
    assert.equal(result.value.done, false);
    assert.equal(typeof result.value.id, 'number');
  });

  test('IDは連番で振られる', () => {
    const store = createStore();
    const first = store.create('one');
    const second = store.create('two');

    assert.equal(second.value.id, first.value.id + 1);
  });

  test('空タイトルは拒否される', () => {
    const store = createStore();
    const result = store.create('   ');

    assert.equal(result.ok, false);
    assert.equal(store.count(), 0);
  });

  test('タスクを完了にできる', () => {
    const store = createStore();
    const created = store.create('掃除する');
    const result = store.complete(created.value.id);

    assert.equal(result.ok, true);
    assert.equal(result.value.done, true);
  });

  test('存在しないタスクの完了は失敗する', () => {
    const store = createStore();
    const result = store.complete(999);

    assert.equal(result.ok, false);
    assert.match(result.error, /not found/);
  });

  test('タスクを削除できる', () => {
    const store = createStore();
    const created = store.create('削除される');

    assert.equal(store.count(), 1);
    assert.equal(store.remove(created.value.id).ok, true);
    assert.equal(store.count(), 0);
  });

  test('完了状態でフィルタできる', () => {
    const store = createStore();
    const a = store.create('done task');
    store.create('pending task');
    store.complete(a.value.id);

    assert.equal(store.list({ done: true }).length, 1);
    assert.equal(store.list({ done: false }).length, 1);
    assert.equal(store.list().length, 2);
  });
});
