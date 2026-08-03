# Storage schema

| Bucket | Public read | Write |
|--------|-------------|-------|
| product-images | yes | staff/admin |
| brand-assets | yes | staff/admin |
| category-assets | yes | staff/admin |
| user-avatars | authenticated (own folder or staff) | own folder `{user_id}/...` |

## Path conventions

```
product-images/{product_id}/{file_name}
brand-assets/{brand_id}/{file_name}
category-assets/{category_id_or_slug}/{file_name}
user-avatars/{user_id}/{file_name}
```

Database columns store **paths** (`storage_path`, `image_path`, `logo_path`, `avatar_path`), never signed URLs.

Flutter builds public URLs via `Supabase.instance.client.storage.from(bucket).getPublicUrl(path)` when needed.
