import { declineMessages, fallbackMessage } from './constants';

export function declineMessage(code: string): string {
  if (!Object.prototype.hasOwnProperty.call(declineMessages, code)) {
    return fallbackMessage;
  }

  return declineMessages[code];
}
