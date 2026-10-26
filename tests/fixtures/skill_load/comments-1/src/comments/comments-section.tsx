import { useState, type FormEvent } from 'react';

import { useComments } from './use-comments';
import { useSendComment } from './use-send-comment';

export type CommentsSectionProps = { postId: string };

export function CommentsSection({ postId }: CommentsSectionProps) {
  const { state, addComment } = useComments(postId);
  const [draft, setDraft] = useState('');
  const { sendState, send } = useSendComment(postId, (comment) => {
    addComment(comment);
    setDraft('');
  });

  const isLoading = state.status === 'loading';
  const isSending = sendState.status === 'sending';

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    send(draft);
  }

  return (
    <section>
      {isLoading && <p>Loading…</p>}

      {state.status === 'failed' && <p role="alert">{state.error.message}</p>}

      {state.status === 'done' && (
        <ul>
          {state.comments.map((comment) => {
            return (
              <li key={comment.id}>
                <strong>{comment.author}</strong>: {comment.text}
              </li>
            );
          })}
        </ul>
      )}

      <form onSubmit={handleSubmit}>
        <textarea
          value={draft}
          disabled={isSending}
          onChange={(event) => {
            setDraft(event.target.value);
          }}
        />
        <button type="submit" disabled={isSending}>
          Send
        </button>
        {sendState.status === 'failed' && <p role="alert">{sendState.error.message}</p>}
      </form>
    </section>
  );
}
