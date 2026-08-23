import type { DashboardRangeDays } from "@/features/operational-dashboard/types";

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export function getExpectedDailySeriesLength(
  rangeDays: DashboardRangeDays,
): number {
  return rangeDays + 1;
}

export function getUtcDateFromIsoDateTime(isoDateTime: string): string | null {
  const parsed = new Date(isoDateTime);
  if (!Number.isFinite(parsed.getTime())) {
    return null;
  }
  return formatUtcDate(parsed);
}

export function buildUtcDateSeries(
  startDate: string,
  length: number,
): string[] {
  if (!ISO_DATE_PATTERN.test(startDate) || length < 1) {
    return [];
  }

  const dates: string[] = [];
  const current = new Date(`${startDate}T00:00:00.000Z`);
  if (!Number.isFinite(current.getTime())) {
    return [];
  }

  for (let index = 0; index < length; index += 1) {
    dates.push(formatUtcDate(current));
    current.setUTCDate(current.getUTCDate() + 1);
  }

  return dates;
}

export function resolveUtcWindowBounds(
  rangeDays: DashboardRangeDays,
  windowStart: string,
  windowEnd: string,
): {
  startDate: string;
  endDate: string;
  expectedSeriesLength: number;
} | null {
  const startDate = getUtcDateFromIsoDateTime(windowStart);
  const endDate = getUtcDateFromIsoDateTime(windowEnd);
  if (startDate === null || endDate === null) {
    return null;
  }

  const expectedSeriesLength = getExpectedDailySeriesLength(rangeDays);
  const series = buildUtcDateSeries(startDate, expectedSeriesLength);
  if (
    series.length !== expectedSeriesLength ||
    series[series.length - 1] !== endDate
  ) {
    return null;
  }

  return { startDate, endDate, expectedSeriesLength };
}

function formatUtcDate(date: Date): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
