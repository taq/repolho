# Repolho

![Logo](logo.png)

Report generator for Ruby and Rails.

Given a `.rep.erb` template and a data source (ActiveRecord `exec_query`,
Relation, array of models, or array of hashes), Repolho produces HTML with:

- Nested groupings (`<report-group>`)
- Page breaks (`<report-page rows="N">`)
- Headers and footers at every level
- Per-container statistics (`sum`, `avg`, `min`, `max`, `count`)
- Optional group-header reprint on page break

## Installation

```ruby
# Gemfile
gem "repolho"
```

```bash
bundle install
```

## Usage

Plain Ruby:

```ruby
require "repolho"

rows = Order.connection.exec_query(sql)
# or
# rows = Order.joins(...).select(...).order(...)

report = Repolho::Main.new("app/views/reports/sales.rep.erb", rows, { company: "Acme" })
report.run

html = report.content.join
```

Or with Rails:

```ruby
render html: html.html_safe
# or File.write("report.html", html)
```

## Template (`.rep.erb`)

Repolho uses a few custom elements inside a normal HTML document. Everything
outside `<report>…</report>` is copied as-is (the `previous` and `after`
sections). Everything inside the custom elements is processed as ERB.

### Custom elements

| Element | Purpose | Attributes |
|---------|---------|------------|
| `<report>` | Root container of the report | `pagination` (optional, `"true"`): enables client-side page navigation. Also accepts `pagination-first`, `pagination-prev`, `pagination-next`, `pagination-last` for custom labels. |
| `<report-page>` | Defines a page (required, only one) | `rows` (required): max data rows per page |
| `<report-group>` | Nested grouping | `id` (required), `attr` (required), `reprint-header-on-page-break` (optional, `"true"`) |
| `<report-header>` | Header of the current container | — |
| `<report-footer>` | Footer of the current container | — |
| `<report-row>` | Template for each data row (inside the innermost group) | — |

### Allowed HTML inside page content

Each page is emitted as a `<tbody class="repolho-page" data-page="N">`.
Because of HTML table rules, **only `<tr>` elements** may appear as direct
children of that `<tbody>`.

| Allowed | Not allowed | Why |
|---------|-------------|-----|
| `<tr>` (with `<td>` / `<th>`) | `<thead>` | `<thead>` cannot be a child of `<tbody>`. The browser moves it out and empties the page container. |
| | `<tfoot>` | Same reason. |
| | `<div>`, `<p>`, `<section>`, etc. | Invalid inside a table. |

Use `<tr>` for headers and footers of pages and groups. Reserve `<thead>` /
`<tfoot>` only for content that lives **outside** the page bodies (for example
a report-level header that should appear before any page, if you place it
before the first `<report-page>`).

### Page wrapper

Repolho automatically wraps each page like this:

```html
<tbody class="repolho-page" data-page="1" style="break-after: page; page-break-after: always;">
  <!-- only <tr> elements here -->
</tbody>
```

The `data-page` attribute and the `break-after` style are injected for you.
You do not need to write the `<tbody>` yourself.

### Client-side pagination

If you set `pagination="true"` on the root `<report>` element, Repolho
appends a navigation bar just before the `after` section (still inside
the table) and a small pure-ES6 script at the end of the document
(inserted before `</body>` when present, otherwise appended). The bar
is omitted when the report has only one page.

Optional attributes let you customize the labels:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `pagination-first` | `First` | First page link text |
| `pagination-prev` | `<` | Previous page link text |
| `pagination-next` | `>` | Next page link text |
| `pagination-last` | `Last` | Last page link text |

```html
<report pagination="true"
        pagination-first="Primeira"
        pagination-prev="«"
        pagination-next="»"
        pagination-last="Última">
  ...
</report>
```

The generated controls look like:

```html
<tbody id="report-pagination" data-max="N">
  <tr>
    <td colspan="200" id="report-pagination-links">
      <a href="#" id="report-first-page">First</a>
      <a href="#" id="report-prev-page"><</a>
      <input type="number" id="report-current-page" min="1" max="N" value="1"/>
      <a href="#" id="report-next-page">></a>
      <a href="#" id="report-last-page">Last</a>
    </td>
  </tr>
</tbody>
```

You can restyle the links and the input with normal CSS. The script is
wrapped in try/catch so a failure does not break the rest of the page.

When pagination is enabled, `page_number` (available in ERB) holds the
total number of pages after the report has been fully generated.


### Template example

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Sales report</title>
  </head>
  <body>
    <table>
      <report>
        <report-header>
          <tr><th colspan="100"><%= @company %></th></tr>
          <tr><th colspan="100">Sales report</th></tr>
        </report-header>

        <report-page rows="40">
          <report-header>
            <tr>
              <td>Id</td>
              <td>Name</td>
              <td class="text-end">Value</td>
            </tr>
          </report-header>

          <report-footer>
            <tr>
              <td colspan="2">Page total</td>
              <td><%= format("%.2f", sum(:value)) %></td>
            </tr>
          </report-footer>

          <report-group id="state" attr="state" reprint-header-on-page-break="true">
            <report-header>
              <tr>
                <td>State:</td>
                <td colspan="100"><%= attr(:state) %></td>
              </tr>
            </report-header>
            <report-footer>
              <tr>
                <td colspan="2"><%= attr(:state) %> total</td>
                <td>
                  <%= format("%.2f", sum(:value)) %>
                  (max: <%= format("%.2f", max(:value)) %>)
                </td>
              </tr>
            </report-footer>

            <report-row>
              <tr>
                <td><%= attr(:id) %></td>
                <td><%= attr(:name) %></td>
                <td class="text-end"><%= format("%.2f", attr(:value)) %></td>
              </tr>
            </report-row>
          </report-group>
        </report-page>

        <report-footer>
          <tr>
            <td colspan="2">Grand total</td>
            <td><%= format("%.2f", sum(:value)) %></td>
          </tr>
        </report-footer>
      </report>
    </table>
  </body>
</html>
```

To preview the structure, rename the file to `.html` and open it in a browser
(the custom tags will be ignored).

## Methods available in ERB

| Method | Description |
|--------|-------------|
| `attr(:field)` | Value of the field on the current row |
| `sum(:field)` | Sum within the current container |
| `avg(:field)` | Average |
| `min(:field)` / `max(:field)` | Minimum / maximum |
| `count(:field)` | Number of values |
| `number` | Current page or group number |

## Rails helpers

You can make Rails view helpers available inside the ERB templates by calling
`Repolho.include_rails_helpers!`. By default it includes
`ActionView::Helpers::NumberHelper` (so you get `number_to_currency`,
`number_with_precision`, etc.).

### Inside a Rails application

```ruby
# config/initializers/repolho.rb
Repolho.include_rails_helpers!
```

After that you can use the helpers normally in any template:

```erb
<td class="text-end"><%= number_to_currency(attr(:value)) %></td>
<td><%= number_with_precision(sum(:value), precision: 2) %></td>
```

You can also pass extra modules:

```ruby
Repolho.include_rails_helpers!(
  ActionView::Helpers::NumberHelper,
  ActionView::Helpers::TextHelper
)
```

### Outside Rails

You need the corresponding gems. Directly requiring the individual helper file
triggers an autoload problem in recent Rails versions, so load the helpers
framework first:

```ruby
# Gemfile
gem "actionview"

require "action_view"
require "action_view/helpers"          # loads NumberHelper and the rest
Repolho.include_rails_helpers!
```

Alternatively (and often simpler), use `ActiveSupport::NumberHelper`, which is
designed to be used outside of a view context. The method names are almost the
same (`number_to_currency`, `number_to_rounded`, etc.):

```ruby
# Gemfile
gem "activesupport"

require "active_support/number_helper"
Repolho.include_rails_helpers!(ActiveSupport::NumberHelper)
```

Note: some method names differ slightly between the two modules
(`number_with_delimiter` vs `number_to_delimited`). Prefer the ActiveSupport
version when you are not inside Rails.

Instance variables from the Rails view (such as `@current_template`) are not
automatically copied. Pass them explicitly through the `locals` hash:

```ruby
Repolho::Main.new(path, data, current_template: @current_template, user: current_user)
```

They become `@current_template` and `@user` inside the templates.


## Signing


This gem is cryptographically signed. To verify the signature on install:

```bash
# Trust the public certificate (once)
gem cert --add <(curl -Ls https://raw.githubusercontent.com/taq/repolho/main/certs/taq.pem)

# Install with signature verification
gem install repolho -P HighSecurity
```

## License

MIT
