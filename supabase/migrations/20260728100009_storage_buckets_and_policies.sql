-- Storage buckets and object policies.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'product-images',
    'product-images',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  ),
  (
    'brand-assets',
    'brand-assets',
    true,
    2097152,
    array['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
  ),
  (
    'category-assets',
    'category-assets',
    true,
    2097152,
    array['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
  ),
  (
    'user-avatars',
    'user-avatars',
    false,
    2097152,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public read for catalog buckets
create policy storage_product_images_public_read
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'product-images');

create policy storage_brand_assets_public_read
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'brand-assets');

create policy storage_category_assets_public_read
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'category-assets');

-- Staff write catalog media
create policy storage_product_images_staff_write
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'product-images' and public.is_staff_or_admin());

create policy storage_product_images_staff_update
  on storage.objects for update
  to authenticated
  using (bucket_id = 'product-images' and public.is_staff_or_admin())
  with check (bucket_id = 'product-images' and public.is_staff_or_admin());

create policy storage_product_images_staff_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'product-images' and public.is_staff_or_admin());

create policy storage_brand_assets_staff_write
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'brand-assets' and public.is_staff_or_admin());

create policy storage_brand_assets_staff_update
  on storage.objects for update
  to authenticated
  using (bucket_id = 'brand-assets' and public.is_staff_or_admin())
  with check (bucket_id = 'brand-assets' and public.is_staff_or_admin());

create policy storage_brand_assets_staff_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'brand-assets' and public.is_staff_or_admin());

create policy storage_category_assets_staff_write
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'category-assets' and public.is_staff_or_admin());

create policy storage_category_assets_staff_update
  on storage.objects for update
  to authenticated
  using (bucket_id = 'category-assets' and public.is_staff_or_admin())
  with check (bucket_id = 'category-assets' and public.is_staff_or_admin());

create policy storage_category_assets_staff_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'category-assets' and public.is_staff_or_admin());

-- Avatars: authenticated read; own-folder write
create policy storage_user_avatars_authenticated_read
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );

create policy storage_user_avatars_own_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'user-avatars'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );

create policy storage_user_avatars_own_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  )
  with check (
    bucket_id = 'user-avatars'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );

create policy storage_user_avatars_own_delete
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );
