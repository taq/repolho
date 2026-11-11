# Repolho website

Static site ready for GitHub Pages.

## Contents

- `index.html` — landing page
- `style.css`
- `images/` — logo and sample report screenshots
- `sample.rep.erb` — example template that matches the screenshots
- `sample-data.md` — notes on the data used for the example

## Hosting

1. Copy the contents of this folder into the `docs/` directory of the [repolho](https://github.com/taq/repolho) repository (or into a dedicated `gh-pages` branch).
2. In the repository Settings → Pages, choose “Deploy from a branch” and select the `docs` folder (or the `gh-pages` branch).
3. The site will be available at `https://taq.github.io/repolho/`.

## Custom domain (optional)

Add a `CNAME` file if you want a custom domain.
