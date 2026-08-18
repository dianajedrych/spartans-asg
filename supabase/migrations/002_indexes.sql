-- =============================================================================
-- SPARTANS ASG — 002_indexes.sql
-- Indeksy pod realne wzorce zapytań sklepu i panelu admina.
-- =============================================================================

-- Przeglądanie/filtrowanie sklepu
create index idx_products_category on products (category_id) where is_active;
create index idx_products_brand on products (brand_id) where is_active;
create index idx_products_active_featured on products (is_active, is_featured);
create index idx_products_slug on products (slug);
create index idx_categories_parent on categories (parent_id);
create index idx_product_variants_product on product_variants (product_id);
create index idx_product_images_product on product_images (product_id, sort_order);
create index idx_product_specifications_product on product_specifications (product_id, sort_order);

-- Wyszukiwarka produktów (nazwa + opis, prosty full-text po polsku)
create index idx_products_search on products
  using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(short_description, '')));

-- Koszyk / ulubione / porównanie
create index idx_cart_items_cart on cart_items (cart_id);
create index idx_favorites_user on favorites (user_id);
create index idx_comparison_items_list on comparison_items (comparison_list_id);

-- Zamówienia — panel admina filtruje wg statusu i szuka po numerze/e-mailu
create index idx_orders_status on orders (status, created_at desc);
create index idx_orders_user on orders (user_id);
create index idx_orders_number on orders (order_number);
create index idx_order_items_order on order_items (order_id);
create index idx_order_status_history_order on order_status_history (order_id, created_at);

-- Opinie — strona produktu pokazuje tylko opublikowane, posortowane
create index idx_reviews_product_status on reviews (product_id, status, created_at desc);

-- Wydarzenia / galeria
create index idx_events_status_date on events (status, event_date);
create index idx_event_registrations_event on event_registrations (event_id);
create index idx_gallery_images_album on gallery_images (album_id, sort_order);

-- Role — sprawdzane w RLS przy każdym zapytaniu, musi być szybkie
create index idx_user_roles_user on user_roles (user_id);

-- Audyt admina — panel filtruje po encji i dacie
create index idx_admin_logs_entity on admin_logs (entity_type, entity_id, created_at desc);
