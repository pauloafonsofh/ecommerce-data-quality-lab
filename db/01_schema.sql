-- System under test: a small online store.
-- Money is numeric(12,2). Rules that fit in one row are constraints here;
-- rules that cross rows or tables are checked by the files in checks/.

CREATE TABLE customers (
  id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tax_id text NOT NULL UNIQUE,  -- fictional 11-digit document (never a real CPF)
  name   text NOT NULL,
  email  text NOT NULL
);

CREATE TABLE products (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sku        text NOT NULL UNIQUE,
  name       text NOT NULL,
  unit_price numeric(12,2) NOT NULL CHECK (unit_price > 0)
);

CREATE TABLE inventory (
  product_id   bigint PRIMARY KEY REFERENCES products (id),
  received_qty integer NOT NULL CHECK (received_qty >= 0),  -- total units ever received
  stock        integer NOT NULL CHECK (stock >= 0)          -- units available now
);

CREATE TABLE orders (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_ref    text NOT NULL UNIQUE,
  customer_id  bigint NOT NULL REFERENCES customers (id),
  created_at   timestamptz NOT NULL,
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid')),
  total_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

CREATE TABLE order_items (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id   bigint NOT NULL REFERENCES orders (id),
  product_id bigint NOT NULL REFERENCES products (id),
  qty        integer NOT NULL CHECK (qty > 0),
  unit_price numeric(12,2) NOT NULL CHECK (unit_price > 0)  -- price at the time of the sale
);

CREATE TABLE payments (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_ref text NOT NULL UNIQUE,
  order_id    bigint NOT NULL REFERENCES orders (id),
  amount      numeric(12,2) NOT NULL CHECK (amount > 0),
  status      text NOT NULL CHECK (status IN ('captured', 'failed')),
  paid_at     timestamptz NOT NULL
);

CREATE TABLE refunds (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  refund_ref  text NOT NULL UNIQUE,
  payment_id  bigint NOT NULL REFERENCES payments (id),
  amount      numeric(12,2) NOT NULL CHECK (amount > 0),
  refunded_at timestamptz NOT NULL
);
