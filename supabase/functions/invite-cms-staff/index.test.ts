import { assertEquals } from "jsr:@std/assert@1";

Deno.test("readEmail normalizes and validates addresses", () => {
  assertEquals(readEmail(" Staff@Example.COM "), "staff@example.com");
  assertEquals(readEmail("not-an-email"), null);
  assertEquals(readEmail(""), null);
});

Deno.test("readRole accepts staff and admin only", () => {
  assertEquals(readRole("staff"), "staff");
  assertEquals(readRole("admin"), "admin");
  assertEquals(readRole("customer"), null);
});

Deno.test("readFullName trims and bounds length", () => {
  assertEquals(readFullName("  Alex   Coach  "), "Alex Coach");
  assertEquals(readFullName("x".repeat(121)), null);
});

Deno.test("buildInviteRedirectTo uses CMS callback contract", () => {
  assertEquals(
    buildInviteRedirectTo("http://localhost:3000"),
    "http://localhost:3000/auth/callback?next=%2Fupdate-password",
  );
  assertEquals(buildInviteRedirectTo("not-a-url"), null);
});

Deno.test("mapInviteError sanitizes provider failures", () => {
  assertEquals(
    mapInviteError({ status: 429, message: "email rate limit exceeded" }),
    RATE_LIMIT_MESSAGE,
  );
  assertEquals(
    mapInviteError({ message: "User already registered" }),
    DUPLICATE_MESSAGE,
  );
  assertEquals(mapInviteError({ message: "unexpected" }), GENERIC_FAILURE_MESSAGE);
});

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const RATE_LIMIT_MESSAGE =
  "Email sending is temporarily limited. Wait a few minutes and try again, or ask your operator to review SMTP rate limits.";
const DUPLICATE_MESSAGE =
  "That email already belongs to an account. Update the existing staff member instead of sending a new invitation.";
const GENERIC_FAILURE_MESSAGE =
  "We couldn't send that invitation. Try again later.";

function readEmail(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (!normalized || normalized.length > 254 || !EMAIL_PATTERN.test(normalized)) {
    return null;
  }
  return normalized;
}

function readRole(value: unknown): "staff" | "admin" | null {
  if (value !== "staff" && value !== "admin") {
    return null;
  }
  return value;
}

function readFullName(value: unknown): string | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (!trimmed || trimmed.length > 120) {
    return null;
  }
  return trimmed;
}

function buildInviteRedirectTo(rawSiteUrl: string): string | null {
  try {
    const site = new URL(rawSiteUrl);
    if (!["http:", "https:"].includes(site.protocol)) {
      return null;
    }
    const callback = new URL("/auth/callback", site);
    callback.searchParams.set("next", "/update-password");
    return callback.toString();
  } catch {
    return null;
  }
}

function mapInviteError(error: { message?: string; status?: number }): string {
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  const status = typeof error.status === "number" ? error.status : 0;

  if (
    status === 429 ||
    message.includes("rate limit") ||
    message.includes("too many requests") ||
    message.includes("email rate limit")
  ) {
    return RATE_LIMIT_MESSAGE;
  }

  if (
    message.includes("already been registered") ||
    message.includes("already exists") ||
    message.includes("user already registered")
  ) {
    return DUPLICATE_MESSAGE;
  }

  return GENERIC_FAILURE_MESSAGE;
}
