export const MAX_TITLE_LENGTH = 60;

/**
 * タスクのタイトルを検証する。
 * 前後の空白は許容し、トリムした結果で判定する。
 */
export function validateTitle(title) {
  if (typeof title !== 'string') {
    return { ok: false, error: 'title must be a string' };
  }

  const trimmed = title.trim();

  if (trimmed.length === 0) {
    return { ok: false, error: 'title must not be empty' };
  }

  if (trimmed.length >= MAX_TITLE_LENGTH) {
    return {
      ok: false,
      error: `title must be ${MAX_TITLE_LENGTH} characters or less`,
    };
  }

  return { ok: true, value: trimmed };
}
