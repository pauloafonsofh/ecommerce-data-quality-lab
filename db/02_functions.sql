-- System under test: store functions.
-- Business rejections come back as a status text (never as an exception),
-- so the same scenario can run before and after a fix.

-- Registers a customer. Returns 'OK' or 'ALREADY_EXISTS'.
CREATE FUNCTION register_customer(p_tax_id text, p_name text, p_email text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO customers (tax_id, name, email)
  VALUES (p_tax_id, p_name, p_email)
  ON CONFLICT (tax_id) DO NOTHING;

  IF FOUND THEN
    RETURN 'OK';
  END IF;
  RETURN 'ALREADY_EXISTS';
END;
$$;


-- Adds one item to an order, reserving stock.
-- Creates the order when p_order_ref is new.
-- Returns 'OK', 'UNKNOWN_CUSTOMER', 'UNKNOWN_PRODUCT', 'INVALID_QTY',
-- 'ORDER_NOT_YOURS', 'ORDER_CLOSED' or 'OUT_OF_STOCK'.
CREATE FUNCTION place_order(p_order_ref text, p_tax_id text, p_sku text,
                            p_qty integer, p_at timestamptz)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_customer_id  bigint;
  v_product_id   bigint;
  v_price        numeric(12,2);
  v_order_id       bigint;
  v_order_customer bigint;
  v_order_status   text;
  v_stock          integer;
BEGIN
  -- 1. Validate the input
  SELECT id INTO v_customer_id FROM customers WHERE tax_id = p_tax_id;
  IF v_customer_id IS NULL THEN
    RETURN 'UNKNOWN_CUSTOMER';
  END IF;

  SELECT id, unit_price INTO v_product_id, v_price FROM products WHERE sku = p_sku;
  IF v_product_id IS NULL THEN
    RETURN 'UNKNOWN_PRODUCT';
  END IF;

  IF p_qty IS NULL OR p_qty <= 0 THEN
    RETURN 'INVALID_QTY';
  END IF;

  SELECT id, customer_id, status INTO v_order_id, v_order_customer, v_order_status
  FROM orders
  WHERE order_ref = p_order_ref;
  IF v_order_id IS NOT NULL AND v_order_customer <> v_customer_id THEN
    RETURN 'ORDER_NOT_YOURS';
  END IF;
  IF v_order_status = 'paid' THEN
    RETURN 'ORDER_CLOSED';
  END IF;

  -- 2. Reserve the stock
  SELECT stock INTO v_stock FROM inventory WHERE product_id = v_product_id;
  IF v_stock < p_qty THEN
    RETURN 'OUT_OF_STOCK';
  END IF;
  UPDATE inventory SET stock = v_stock - p_qty WHERE product_id = v_product_id;

  -- 3. Create the order (if new), add the item and update the total
  IF v_order_id IS NULL THEN
    INSERT INTO orders (order_ref, customer_id, created_at)
    VALUES (p_order_ref, v_customer_id, p_at)
    RETURNING id INTO v_order_id;
  END IF;

  INSERT INTO order_items (order_id, product_id, qty, unit_price)
  VALUES (v_order_id, v_product_id, p_qty, v_price);

  UPDATE orders SET total_amount = total_amount + p_qty * v_price WHERE id = v_order_id;

  RETURN 'OK';
END;
$$;


-- Records a payment for an order ('captured' or 'failed').
-- The order becomes 'paid' when its captured payments reach the order total.
-- Returns 'OK', 'ORDER_NOT_FOUND' or 'AMOUNT_EXCEEDS_BALANCE'.
CREATE FUNCTION pay_order(p_payment_ref text, p_order_ref text, p_amount numeric,
                          p_status text, p_at timestamptz)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id bigint;
  v_total    numeric(12,2);
  v_captured numeric(12,2);
BEGIN
  -- Lock the order row: two payments at the same time cannot both pass the balance check.
  SELECT id, total_amount INTO v_order_id, v_total
  FROM orders
  WHERE order_ref = p_order_ref
  FOR UPDATE;
  IF v_order_id IS NULL THEN
    RETURN 'ORDER_NOT_FOUND';
  END IF;

  SELECT coalesce(sum(amount), 0) INTO v_captured
  FROM payments
  WHERE order_id = v_order_id AND status = 'captured';

  IF p_status = 'captured' AND v_captured + p_amount > v_total THEN
    RETURN 'AMOUNT_EXCEEDS_BALANCE';
  END IF;

  INSERT INTO payments (payment_ref, order_id, amount, status, paid_at)
  VALUES (p_payment_ref, v_order_id, p_amount, p_status, p_at);

  IF p_status = 'captured' AND v_captured + p_amount = v_total THEN
    UPDATE orders SET status = 'paid' WHERE id = v_order_id;
  END IF;

  RETURN 'OK';
END;
$$;


-- Refunds part or all of a captured payment.
-- Returns 'OK', 'PAYMENT_NOT_FOUND', 'PAYMENT_NOT_CAPTURED' or 'REFUND_EXCEEDS_PAID'.
CREATE FUNCTION refund_payment(p_refund_ref text, p_payment_ref text, p_amount numeric,
                               p_at timestamptz)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_payment_id bigint;
  v_paid       numeric(12,2);
  v_status     text;
  v_refunded   numeric(12,2);
BEGIN
  -- Lock the payment row: prevents two refunds at the same time (see BUG-001).
  SELECT id, amount, status INTO v_payment_id, v_paid, v_status
  FROM payments
  WHERE payment_ref = p_payment_ref
  FOR UPDATE;

  IF v_payment_id IS NULL THEN
    RETURN 'PAYMENT_NOT_FOUND';
  END IF;
  IF v_status <> 'captured' THEN
    RETURN 'PAYMENT_NOT_CAPTURED';
  END IF;

  -- The refunds already made plus this one can never be larger than the payment.
  SELECT coalesce(sum(amount), 0) INTO v_refunded
  FROM refunds
  WHERE payment_id = v_payment_id;

  IF v_refunded + p_amount > v_paid THEN
    RETURN 'REFUND_EXCEEDS_PAID';
  END IF;

  INSERT INTO refunds (refund_ref, payment_id, amount, refunded_at)
  VALUES (p_refund_ref, v_payment_id, p_amount, p_at);

  RETURN 'OK';
END;
$$;
