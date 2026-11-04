export interface EdgePathInput {
  sourceX: number;
  sourceY: number;
  targetX: number;
  targetY: number;
  barOffset?: number;
  gender?: string;
}

/** Orthodox father/mother connector with one shared horizontal sibling bar. */
export function familyEdgePath(input: EdgePathInput): string {
  const { sourceX, sourceY, targetX, targetY, barOffset = 0, gender } = input;
  const distance = Math.max(1, targetY - sourceY);
  const genderNudge = gender === 'female' ? 2 : gender === 'male' ? -2 : 0;
  const barY = Math.max(
    sourceY + 24,
    Math.min(targetY - 20, sourceY + distance * 0.46 + barOffset + genderNudge),
  );
  const radius = Math.max(
    2,
    Math.min(
      8,
      Math.abs(targetX - sourceX) / 2,
      (barY - sourceY) / 2,
      (targetY - barY) / 2,
    ),
  );
  if (Math.abs(targetX - sourceX) < 1) {
    return `M ${sourceX} ${sourceY} L ${targetX} ${targetY}`;
  }
  if (targetX > sourceX) {
    return [
      `M ${sourceX} ${sourceY}`,
      `L ${sourceX} ${barY - radius}`,
      `Q ${sourceX} ${barY} ${sourceX + radius} ${barY}`,
      `L ${targetX - radius} ${barY}`,
      `Q ${targetX} ${barY} ${targetX} ${barY + radius}`,
      `L ${targetX} ${targetY}`,
    ].join(' ');
  }
  return [
    `M ${sourceX} ${sourceY}`,
    `L ${sourceX} ${barY - radius}`,
    `Q ${sourceX} ${barY} ${sourceX - radius} ${barY}`,
    `L ${targetX + radius} ${barY}`,
    `Q ${targetX} ${barY} ${targetX} ${barY + radius}`,
    `L ${targetX} ${targetY}`,
  ].join(' ');
}
