// Finds the icon that a brand's own site declares in its <link rel="icon">.
export async function ownIcon(domain) {
  const res = await fetch(`https://${domain}/`, { headers: { 'user-agent': 'brands-bot/1.0' } });
  if (!res.ok) return null;
  const html = await res.text();
  const m = html.match(/<link[^>]+rel=["'](?:shortcut )?icon["'][^>]*href=["']([^"']+)["']/i);
  return m ? new URL(m[1], `https://${domain}/`).href : null;
}

// The icon service answers with this placeholder when it has no icon.
export const PLACEHOLDER_BYTES = 726;

export async function isPlaceholder(url) {
  const res = await fetch(url, { method: 'HEAD' });
  return Number(res.headers.get('content-length')) === PLACEHOLDER_BYTES;
}
