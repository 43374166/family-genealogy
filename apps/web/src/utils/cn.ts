type ClassValue = string | false | null | undefined | Record<string, boolean>;

export function cn(...values: ClassValue[]): string {
  const result: string[] = [];
  for (const value of values) {
    if (!value) continue;
    if (typeof value === 'string') {
      result.push(value);
    } else {
      for (const [key, active] of Object.entries(value)) {
        if (active) result.push(key);
      }
    }
  }
  return result.join(' ');
}
