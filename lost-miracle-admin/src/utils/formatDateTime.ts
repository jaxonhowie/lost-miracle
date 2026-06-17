export function formatDateTime(value: string | number | null | undefined): string {
  if (value === null || value === undefined || value === '') {
    return '-';
  }

  if (typeof value === 'string') {
    const isoLocal = value.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})/);
    if (isoLocal) {
      return `${isoLocal[1]} ${isoLocal[2]}`;
    }
  }

  const date =
    typeof value === 'number'
      ? new Date(value > 1e12 ? value : value * 1000)
      : new Date(value);

  if (Number.isNaN(date.getTime())) {
    return String(value);
  }

  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}
