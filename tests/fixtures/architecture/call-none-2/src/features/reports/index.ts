import { formatPrice } from '../../lib/money';

export type MonthlyReport = { month: string; totalCents: number };

export async function listReports(): Promise<MonthlyReport[]> {
  const data: unknown = await (await fetch('/api/reports')).json();
  if (!Array.isArray(data) || !data.every(isMonthlyReport)) throw new Error('Unexpected /reports response');
  return data;
}

export function reportsScreen(reports: MonthlyReport[]): string {
  if (reports.length === 0) return 'No reports yet.';
  return reports.map((r) => `${r.month}: ${formatPrice(r.totalCents)}`).join('\n');
}

function isMonthlyReport(value: unknown): value is MonthlyReport {
  if (typeof value !== 'object' || value === null) return false;
  const { month, totalCents } = value as Record<string, unknown>;
  return typeof month === 'string' && Number.isInteger(totalCents);
}
