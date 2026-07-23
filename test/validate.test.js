import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { validateTitle, MAX_TITLE_LENGTH } from '../src/validate.js';

describe('validateTitle', () => {
  test('通常のタイトルを受け付ける', () => {
    const result = validateTitle('牛乳を買う');

    assert.equal(result.ok, true);
    assert.equal(result.value, '牛乳を買う');
  });

  test('前後の空白をトリムする', () => {
    const result = validateTitle('  余白あり  ');

    assert.equal(result.ok, true);
    assert.equal(result.value, '余白あり');
  });

  test('空文字を拒否する', () => {
    assert.equal(validateTitle('').ok, false);
  });

  test('空白のみを拒否する', () => {
    assert.equal(validateTitle('\t \n').ok, false);
  });

  test('文字列以外を拒否する', () => {
    assert.equal(validateTitle(null).ok, false);
    assert.equal(validateTitle(42).ok, false);
    assert.equal(validateTitle(undefined).ok, false);
  });

  // ---------------------------------------------------------------------
  // 演習3の教材：このテストは意図的に失敗します。
  // 仕様は「MAX_TITLE_LENGTH 文字以下は許可」です。
  // 実装がその仕様を満たしているか確認してください。
  // ---------------------------------------------------------------------
  test('上限ちょうどの長さを受け付ける', () => {
    const exactly = 'あ'.repeat(MAX_TITLE_LENGTH);
    const result = validateTitle(exactly);

    assert.equal(result.ok, true, `${MAX_TITLE_LENGTH}文字ちょうどは許可されるべき`);
  });

  test('上限を超える長さを拒否する', () => {
    const tooLong = 'あ'.repeat(MAX_TITLE_LENGTH + 1);

    assert.equal(validateTitle(tooLong).ok, false);
  });
});
