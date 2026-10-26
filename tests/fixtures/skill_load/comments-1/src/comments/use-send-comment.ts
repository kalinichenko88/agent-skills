import { useState } from 'react';

import { sendComment } from './comments-api';
import type { PostComment } from './models/post-comment';

type SendState =
  | { status: 'idle' }
  | { status: 'sending' }
  | { status: 'failed'; error: Error };

export function useSendComment(postId: string, onSent: (comment: PostComment) => void) {
  const [sendState, setSendState] = useState<SendState>({ status: 'idle' });

  async function send(text: string) {
    setSendState({ status: 'sending' });

    try {
      const comment = await sendComment(postId, text);

      setSendState({ status: 'idle' });
      onSent(comment);
    } catch (error: unknown) {
      setSendState({
        status: 'failed',
        error: error instanceof Error ? error : new Error('The comment could not be sent'),
      });
    }
  }

  return { sendState, send };
}
