# Sample data for the sales report example

This is a small SQLite schema and seed that produces enough rows to show page breaks
when the template uses `rows="15"`.

```sql
CREATE TABLE sales (
  id INTEGER PRIMARY KEY,
  category TEXT,
  product TEXT,
  qty INTEGER,
  unit_price REAL,
  total REAL
);

-- Electronics (enough for ~1.5 pages)
INSERT INTO sales (category, product, qty, unit_price, total) VALUES
('Electronics', 'Wireless Headphones', 24, 79.99, 1919.76),
('Electronics', 'Smart Watch', 18, 199.99, 3599.82),
-- ... add ~40 more rows across 3 categories
;
```

In a real application you would normally pass an ActiveRecord relation or
`exec_query` result. The template only cares about the column names
(`category`, `product`, `qty`, `unit_price`, `total`).
