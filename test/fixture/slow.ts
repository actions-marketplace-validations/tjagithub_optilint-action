export function first(xs: number[]) {
  return xs.filter((x) => x > 1)[0];
}

export const stamp = () => new Date().getTime();
