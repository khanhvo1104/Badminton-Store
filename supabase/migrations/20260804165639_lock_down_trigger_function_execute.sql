-- Lock down direct EXECUTE on internal trigger helpers.
--
-- PostgreSQL grants EXECUTE to PUBLIC by default. These helpers are intended
-- only for trigger invocation (and trusted service_role operational access),
-- not as client-callable RPCs. Function bodies, triggers, RLS, and table
-- grants are intentionally unchanged.
--
-- Audit (migration history + call-site search):
--   Included:
--     - prevent_profile_privilege_escalation()  SECURITY DEFINER, trigger-only
--     - assign_order_number()                   SECURITY DEFINER, trigger-only
--     - record_order_status_change()            SECURITY DEFINER, trigger-only
--     - validate_product_image_variant()        SECURITY INVOKER, trigger-only
--       (only referenced by product_images_validate_variant; default PUBLIC
--       EXECUTE with no documented client API)
--   Excluded (already locked down or intentional client/RPC contract):
--     - set_updated_at()              explicit authenticated + service_role
--     - handle_new_user_profile()     already revoked from PUBLIC
--     - cart_items_enforce_active_cart()  already explicitly controlled
--     - generate_order_number()       history grants authenticated
--     - policy helpers / public RPCs  intentional Data API surface

revoke execute on function public.prevent_profile_privilege_escalation()
  from public;
revoke execute on function public.prevent_profile_privilege_escalation()
  from anon;
revoke execute on function public.prevent_profile_privilege_escalation()
  from authenticated;
grant execute on function public.prevent_profile_privilege_escalation()
  to service_role;

revoke execute on function public.assign_order_number()
  from public;
revoke execute on function public.assign_order_number()
  from anon;
revoke execute on function public.assign_order_number()
  from authenticated;
grant execute on function public.assign_order_number()
  to service_role;

revoke execute on function public.record_order_status_change()
  from public;
revoke execute on function public.record_order_status_change()
  from anon;
revoke execute on function public.record_order_status_change()
  from authenticated;
grant execute on function public.record_order_status_change()
  to service_role;

revoke execute on function public.validate_product_image_variant()
  from public;
revoke execute on function public.validate_product_image_variant()
  from anon;
revoke execute on function public.validate_product_image_variant()
  from authenticated;
grant execute on function public.validate_product_image_variant()
  to service_role;

comment on function public.prevent_profile_privilege_escalation() is
  'Locks role and is_active for non-staff self-updates. SECURITY DEFINER. '
  'EXECUTE revoked from PUBLIC/anon/authenticated; granted to service_role only. '
  'Invoked solely by profiles_prevent_privilege_escalation.';

comment on function public.assign_order_number() is
  'Assigns generate_order_number() when order_number is empty on insert. '
  'EXECUTE revoked from PUBLIC/anon/authenticated; granted to service_role only. '
  'Invoked solely by orders_assign_order_number.';

comment on function public.record_order_status_change() is
  'Writes order_status_history only when status changes. SECURITY DEFINER. '
  'EXECUTE revoked from PUBLIC/anon/authenticated; granted to service_role only. '
  'Invoked solely by orders_record_status_history.';

comment on function public.validate_product_image_variant() is
  'Ensures variant_id belongs to the same product as product_id. '
  'EXECUTE revoked from PUBLIC/anon/authenticated; granted to service_role only. '
  'Invoked solely by product_images_validate_variant.';
