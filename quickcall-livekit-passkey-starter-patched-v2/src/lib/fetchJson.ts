/**
 * Robust JSON fetch helper for client-side use.
 *
 * Why:
 * - `res.json()` throws when the body is empty.
 * - When an API route crashes, Next.js may return HTML or an empty body.
 */
export async function fetchJson<T>(input: RequestInfo | URL, init?: RequestInit): Promise<T> {
  const res = await fetch(input, init);

  const text = await res.text();

  if (!res.ok) {
    // Include a snippet of the body to make debugging easy.
    throw new Error(`HTTP ${res.status} ${res.statusText}: ${text.slice(0, 400)}`);
  }

  if (!text) {
    // Some endpoints may legitimately return empty bodies.
    return null as unknown as T;
  }

  try {
    return JSON.parse(text) as T;
  } catch {
    throw new Error(`Response is not valid JSON: ${text.slice(0, 400)}`);
  }
}
