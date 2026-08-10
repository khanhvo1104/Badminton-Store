-- Helper: upsert sample CSV-shaped rows.
-- Edit VALUES as needed. No absolute local file paths.

insert into public.categories (id, name, slug, description, image_path, sort_order, is_active)
values
  ('11111111-1111-1111-1111-111111111101', 'Vợt cầu lông', 'rackets', 'Vợt thi đấu và luyện tập', 'category-assets/rackets/cover.webp', 10, true)
on conflict (id) do update
set name = excluded.name, updated_at = timezone('utc', now());

insert into public.brands (id, name, slug, description, logo_path, country_of_origin, sort_order, is_active)
values
  ('22222222-2222-2222-2222-222222222201', 'Yonex', 'yonex', 'Demo brand', 'brand-assets/yonex/logo.webp', 'Japan', 10, true)
on conflict (id) do update
set name = excluded.name, updated_at = timezone('utc', now());
