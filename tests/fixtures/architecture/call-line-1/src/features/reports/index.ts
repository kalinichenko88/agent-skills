import { request } from '../../api/client';
import { formatPrice } from '../../lib/money';

export type Report = { month: string; totalCents: number };

export function listReports(): Promise<Report[]> {
  return request<Report[]>('/reports');
}

export function reportLabel(report: Report): string {
  return `${report.month}: ${formatPrice(report.totalCents)}`;
}
