import { DECLINE_MESSAGES } from './constants';

export function declineMessage(code: string): string {
  if (!Object.prototype.hasOwnProperty.call(DECLINE_MESSAGES, code)) {
    return FALLBACK_DECLINE_MESSAGE;
  }

  return DECLINE_MESSAGES[code];
}

const FALLBACK_DECLINE_MESSAGE = 'The payment failed. Try another card.';
