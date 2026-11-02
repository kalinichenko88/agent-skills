// Each brand row shows its logo through /logo, one request a row and a view.
const res = await fetch('/brands');
for (const b of await res.json()) {
  const li = document.createElement('li');
  li.innerHTML = `<img src="/logo?domain=${encodeURIComponent(b.domain)}" width="32" height="32"> ${b.domain}`;
  document.getElementById('brands').append(li);
}
