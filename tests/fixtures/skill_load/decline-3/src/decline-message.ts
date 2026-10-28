import { DECLINE_MESSAGES, FALLBACK_DECLINE_MESSAGE } from './constants';

export function declineMessage(code: string): string {
  if (!Object.prototype.hasOwnProperty.call(DECLINE_MESSAGES, code)) {
    return FALLBACK_DECLINE_MESSAGE;
  }

  return DECLINE_MESSAGES[code];
}
