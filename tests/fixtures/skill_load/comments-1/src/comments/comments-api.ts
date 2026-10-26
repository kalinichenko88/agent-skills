import type { PostComment } from './models/post-comment';

export async function fetchComments(postId: string, signal: AbortSignal): Promise<PostComment[]> {
  const response = await fetch(commentsUrl(postId), { signal });

  if (!response.ok) {
    throw new Error(`Could not load the comments (HTTP ${response.status})`);
  }

  const data: unknown = await response.json();

  if (!Array.isArray(data) || !data.every(isPostComment)) {
    throw new Error('The comments response has an unexpected shape');
  }

  return data;
}

export async function sendComment(postId: string, text: string): Promise<PostComment> {
  const response = await fetch(commentsUrl(postId), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });

  if (!response.ok) {
    throw new Error(`Could not send the comment (HTTP ${response.status})`);
  }

  const data: unknown = await response.json();

  if (!isPostComment(data)) {
    throw new Error('The new comment has an unexpected shape');
  }

  return data;
}

function commentsUrl(postId: string): string {
  return `/api/posts/${encodeURIComponent(postId)}/comments`;
}

function isPostComment(value: unknown): value is PostComment {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    typeof value.id === 'string' &&
    'author' in value &&
    typeof value.author === 'string' &&
    'text' in value &&
    typeof value.text === 'string'
  );
}
