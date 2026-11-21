// Match the raw URL: normalizing first could hide credentials or dot segments.
const officialPage =
  /^https:\/\/(?:www\.)?neo-stream\.eu((?:\/[a-z0-9][a-z0-9_-]{0,47})+(?:\.[a-z]{1,8})?\/?)$/i;
const sensitivePath =
  /(?:^|[/_.-])(?:tokens?|jwt|bearer|credentials?|secrets?)(?=$|[/_.-])/i;
const uuidPath = /\/[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}(?=$|[/.])/i;

export function validateLegalUrl(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 160) return null;
  const match = officialPage.exec(value);
  if (
    !match ||
    match[0] !== value ||
    sensitivePath.test(match[1]) ||
    uuidPath.test(match[1])
  ) {
    return null;
  }
  return value;
}
