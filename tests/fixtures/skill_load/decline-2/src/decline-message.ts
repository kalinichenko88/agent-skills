import { declineMessages } from './constants';

export function declineMessage(code: string): string {
  if (!Object.prototype.hasOwnProperty.call(declineMessages, code)) {
    return unknownDeclineMessage;
  }

  return declineMessages[code];
}

const unknownDeclineMessage = 'The payment failed. Try another card.';
