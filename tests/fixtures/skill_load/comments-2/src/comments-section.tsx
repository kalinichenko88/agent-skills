import { useEffect, useState, type FormEvent, type ReactNode } from 'react';

type Comment = { id: string; author: string; text: string };

type LoadState =
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; comments: Comment[] };

type SendState =
  | { status: 'idle' }
  | { status: 'sending' }
  | { status: 'failed'; error: Error };

export function CommentsSection({ postId }: { postId: string }) {
  const [load, setLoad] = useState<LoadState>({ status: 'loading' });
  const [send, setSend] = useState<SendState>({ status: 'idle' });
  const [text, setText] = useState('');

  useEffect(() => {
    const controller = new AbortController();

    setLoad({ status: 'loading' });

    fetchComments(postId, controller.signal)
      .then((comments) => {
        setLoad({ status: 'done', comments });
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) {
          return;
        }

        setLoad({ status: 'failed', error: toError(error) });
      });

    return () => {
      controller.abort();
    };
  }, [postId]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSend({ status: 'sending' });

    try {
      const comment = await postComment(postId, text);

      setLoad((previous) => {
        if (previous.status !== 'done') {
          return previous;
        }

        return { status: 'done', comments: [...previous.comments, comment] };
      });
      setText('');
      setSend({ status: 'idle' });
    } catch (error: unknown) {
      setSend({ status: 'failed', error: toError(error) });
    }
  }

  const isLoading = load.status === 'loading';
  const isSending = send.status === 'sending';
  const canSend = text.trim() !== '' && !isLoading && !isSending;

  let list: ReactNode;

  if (load.status === 'loading') {
    list = <p>Loading…</p>;
  } else if (load.status === 'failed') {
    list = <p role="alert">{load.error.message}</p>;
  } else {
    list = (
      <ul>
        {load.comments.map((comment) => {
          return (
            <li key={comment.id}>
              <strong>{comment.author}</strong>: {comment.text}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <section>
      <h2>Comments</h2>
      {list}
      <form onSubmit={handleSubmit}>
        <textarea
          value={text}
          disabled={isLoading || isSending}
          onChange={(event) => {
            setText(event.target.value);
          }}
        />
        <button type="submit" disabled={!canSend}>
          Send
        </button>
        {send.status === 'failed' ? <p role="alert">{send.error.message}</p> : null}
      </form>
    </section>
  );
}

function commentsUrl(postId: string): string {
  return `/api/posts/${encodeURIComponent(postId)}/comments`;
}

async function fetchComments(postId: string, signal: AbortSignal): Promise<Comment[]> {
  const response = await fetch(commentsUrl(postId), { signal });

  if (!response.ok) {
    throw new Error(`Could not load comments (HTTP ${response.status})`);
  }

  const data: unknown = await response.json();

  if (!Array.isArray(data) || !data.every(isComment)) {
    throw new Error('The comments response has an unexpected shape');
  }

  return data;
}

async function postComment(postId: string, text: string): Promise<Comment> {
  const response = await fetch(commentsUrl(postId), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });

  if (!response.ok) {
    throw new Error(`Could not send comment (HTTP ${response.status})`);
  }

  const data: unknown = await response.json();

  if (!isComment(data)) {
    throw new Error('The comment response has an unexpected shape');
  }

  return data;
}

function isComment(value: unknown): value is Comment {
  if (typeof value !== 'object' || value === null) {
    return false;
  }

  return (
    'id' in value &&
    typeof value.id === 'string' &&
    'author' in value &&
    typeof value.author === 'string' &&
    'text' in value &&
    typeof value.text === 'string'
  );
}

function toError(error: unknown): Error {
  return error instanceof Error ? error : new Error(String(error));
}
