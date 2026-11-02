import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';

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
    res.writeHead(302, { location: serviceUrl(url.searchParams.get('domain')) });
    return res.end();
  }
  res.writeHead(404);
  res.end();
}).listen(3000);
