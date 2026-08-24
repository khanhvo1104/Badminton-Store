import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  E2E_ACCOUNTS,
  E2E_CATEGORY,
  E2E_ORDER,
  E2E_PASSWORD,
} from "./accounts.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../../..");
const DB_CONTAINER =
  process.env.CMS_E2E_DB_CONTAINER ?? "supabase_db_Badminton-Store";

function parseEnvOutput(raw) {
  const env = {};
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq);
    let value = trimmed.slice(eq + 1);
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function loadSupabaseStatusEnv() {
  const raw = execFileSync("supabase", ["status", "-o", "env"], {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  return parseEnvOutput(raw);
}

async function upsertAuthUser(params) {
  const listResponse = await fetch(
    `${params.apiUrl}/auth/v1/admin/users?page=1&per_page=200`,
    {
      headers: {
        apikey: params.serviceRoleKey,
        Authorization: `Bearer ${params.serviceRoleKey}`,
      },
    },
  );

  if (!listResponse.ok) {
    throw new Error(`Auth admin list failed with HTTP ${listResponse.status}`);
  }

  const listed = await listResponse.json();
  const existing = (listed.users ?? []).find(
    (user) => user.email?.toLowerCase() === params.email.toLowerCase(),
  );

  if (existing) {
    const deleteResponse = await fetch(
      `${params.apiUrl}/auth/v1/admin/users/${existing.id}`,
      {
        method: "DELETE",
        headers: {
          apikey: params.serviceRoleKey,
          Authorization: `Bearer ${params.serviceRoleKey}`,
        },
      },
    );
    if (!deleteResponse.ok && deleteResponse.status !== 404) {
      throw new Error(
        `Auth admin delete failed with HTTP ${deleteResponse.status}`,
      );
    }
  }

  const createResponse = await fetch(`${params.apiUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: params.serviceRoleKey,
      Authorization: `Bearer ${params.serviceRoleKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      id: params.id,
      email: params.email,
      password: params.password,
      email_confirm: true,
      user_metadata: { full_name: "CMS E2E" },
    }),
  });

  if (!createResponse.ok) {
    throw new Error(
      `Auth admin create failed with HTTP ${createResponse.status}`,
    );
  }
}

function runSql(sql) {
  execFileSync(
    "docker",
    [
      "exec",
      "-i",
      DB_CONTAINER,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
    ],
    {
      input: sql,
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
    },
  );
}

function promoteProfilesAndSeedOrder() {
  const admin = E2E_ACCOUNTS.admin;
  const staff = E2E_ACCOUNTS.staff;
  const customer = E2E_ACCOUNTS.customer;
  const order = E2E_ORDER;

  runSql(`
begin;

delete from public.order_items where order_id = '${order.id}';
delete from public.orders where id = '${order.id}';
delete from public.categories
where slug like 'cms-e2e-%';

update public.profiles
set
  full_name = '${admin.fullName}',
  role = 'admin',
  is_active = true
where id = '${admin.id}';

update public.profiles
set
  full_name = '${staff.fullName}',
  role = 'staff',
  is_active = true
where id = '${staff.id}';

update public.profiles
set
  full_name = '${customer.fullName}',
  role = 'customer',
  is_active = true
where id = '${customer.id}';

insert into public.categories (
  id, parent_id, name, slug, description, image_path, sort_order, is_active
) values (
  '${E2E_CATEGORY.id}',
  null,
  '${E2E_CATEGORY.name}',
  '${E2E_CATEGORY.slug}',
  'Disposable CMS E2E category fixture',
  null,
  999,
  true
);

insert into public.orders (
  id, order_number, user_id, status,
  subtotal, discount_total, shipping_fee, grand_total,
  recipient_name, recipient_phone, shipping_address
) values (
  '${order.id}',
  '${order.orderNumber}',
  '${customer.id}',
  'pending',
  100000, 0, 0, 100000,
  '${order.recipientName}',
  '${order.recipientPhone}',
  '{"recipient_name":"E2E Recipient","phone_number":"0901000001","province_name":"HN","district_name":"Dong Da","ward_name":"Cat Linh","street_address":"1 E2E"}'::jsonb
);

insert into public.order_items (
  order_id, product_id, variant_id, product_name, variant_name, sku,
  unit_price, quantity, line_total
) values (
  '${order.id}',
  '30000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  'E2E Product',
  'Default',
  'E2E-SKU-1',
  100000,
  1,
  100000
);

commit;
`);
}

function cleanupSql() {
  const ids = Object.values(E2E_ACCOUNTS)
    .map((account) => `'${account.id}'`)
    .join(", ");
  runSql(`
begin;
select set_config('app.cms_audit_test_cleanup', '1', true);
delete from public.order_items where order_id = '${E2E_ORDER.id}';
delete from public.orders where id = '${E2E_ORDER.id}';
delete from public.categories
where slug like 'cms-e2e-%';
delete from public.cms_privileged_audit_events
where actor_id in (${ids});
delete from public.profiles where id in (${ids});
delete from auth.users where id in (${ids});
select set_config('app.cms_audit_test_cleanup', '', true);
commit;
`);
}

export async function prepareE2EFixtures() {
  const status = loadSupabaseStatusEnv();
  const apiUrl = status.API_URL;
  const serviceRoleKey = status.SERVICE_ROLE_KEY || status.SECRET_KEY;

  if (!apiUrl || !serviceRoleKey) {
    throw new Error("Missing local Supabase API_URL or service role key.");
  }

  cleanupSql();

  for (const account of Object.values(E2E_ACCOUNTS)) {
    await upsertAuthUser({
      apiUrl,
      serviceRoleKey,
      id: account.id,
      email: account.email,
      password: E2E_PASSWORD,
    });
  }

  promoteProfilesAndSeedOrder();
}

export async function cleanupE2EFixtures() {
  try {
    cleanupSql();
  } catch {
    // Local stack may already be stopped during teardown.
  }
}
