# Decisions

**D1. The site lists every brand in `data/brands.csv`.** The list changes by
hand, a few times a year. No database. Revisit when the list passes 10,000
brands.

**D2. Icons come from the icon service, through `/logo`.** The page loads no
icon from a brand's own site, and the CSP in `public/index.html` allows only
the service. Rests on: the service has an icon for most brands (924 of 1000
in 2026-09).

**D3. No tracking of the visitors.** The site sets no cookie and sends no
data to a third party.
