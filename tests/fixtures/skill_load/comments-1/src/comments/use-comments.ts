import { useEffect, useState } from 'react';

import { fetchComments } from './comments-api';
import type { PostComment } from './models/post-comment';

type CommentsState =
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; comments: PostComment[] };

export function useComments(postId: string) {
  const [state, setState] = useState<CommentsState>({ status: 'loading' });

  useEffect(() => {
    const controller = new AbortController();

    setState({ status: 'loading' });

    fetchComments(postId, controller.signal).then(
      (comments) => {
        setState({ status: 'done', comments });
      },
      (error: unknown) => {
        if (controller.signal.aborted) {
          return;
        }

        setState({
          status: 'failed',
          error: error instanceof Error ? error : new Error('The comments could not be loaded'),
        });
      },
    );

    return () => {
      controller.abort();
    };
  }, [postId]);

  function addComment(comment: PostComment) {
    setState((previous) => {
      if (previous.status !== 'done') {
        return previous;
      }

      return { status: 'done', comments: [...previous.comments, comment] };
    });
  }

  return { state, addComment };
}
