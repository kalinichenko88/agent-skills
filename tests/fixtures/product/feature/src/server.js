import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { ownIcon, isPlaceholder } from './own-icon.js';

const brands = readFileSync(new URL('../data/brands.csv', import.meta.url), 'utf8')
  .trim().split('\n').slice(1).map((line) => ({ domain: line.split(',')[0] }));

export function serviceUrl(domain) {
  return `https://icons.example.com/${encodeURIComponent(domain)}.png`;
}

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/brands') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(brands));
  }
  if (url.pathname === '/logo') {
    const domain = url.searchParams.get('domain');
    let location = serviceUrl(domain);
    // When the service has only its placeholder, use the brand's own icon.
    if (await isPlaceholder(location)) location = (await ownIcon(domain)) ?? location;
    res.writeHead(302, { location });
    return res.end();
  }
  res.writeHead(404);
  res.end();
}).listen(3000);
