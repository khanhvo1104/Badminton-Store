import { describe, expect, it } from "vitest";

import { GOTRUE_RECOVERY_AMR_METHODS } from "@/lib/auth/authorization";
import {
  getLoginRedirectPath,
  getPasswordRecoveryRedirectTo,
  isPkceAuthCode,
  isSyntacticallyValidEmail,
  isVerifiedRecoverySession,
  LOGIN_STATUS_PASSWORD_UPDATED,
  LOGIN_STATUS_RECOVERY_FAILED,
  readLoginStatus,
  resolveSafePostAuthPath,
  validateNewPassword,
} from "@/lib/auth/password-recovery";

describe("isSyntacticallyValidEmail", () => {
  it("accepts a trimmed mailbox address", () => {
    expect(isSyntacticallyValidEmail("staff@example.com")).toBe(true);
  });

  it("rejects empty or malformed values", () => {
    expect(isSyntacticallyValidEmail("")).toBe(false);
    expect(isSyntacticallyValidEmail("staff")).toBe(false);
    expect(isSyntacticallyValidEmail("staff@example")).toBe(false);
  });
});

describe("isPkceAuthCode", () => {
  it("accepts a URL-safe PKCE code", () => {
    expect(isPkceAuthCode("34e770dd-9ff9-416c-87fa-43b31d7ef225")).toBe(true);
  });

  it("rejects missing, short, or unsafe values", () => {
    expect(isPkceAuthCode(null)).toBe(false);
    expect(isPkceAuthCode("short")).toBe(false);
    expect(isPkceAuthCode("has space in codevalue12")).toBe(false);
    expect(isPkceAuthCode("https://evil.example.com")).toBe(false);
  });
});

describe("resolveSafePostAuthPath", () => {
  it("allows only the internal update-password path", () => {
    expect(resolveSafePostAuthPath("/update-password")).toBe(
      "/update-password",
    );
  });

  it("never reflects an external or unknown destination", () => {
    expect(resolveSafePostAuthPath("https://evil.example.com")).toBe(
      "/update-password",
    );
    expect(resolveSafePostAuthPath("//evil.example.com")).toBe(
      "/update-password",
    );
    expect(resolveSafePostAuthPath("/dashboard")).toBe("/update-password");
    expect(
      resolveSafePostAuthPath("/login?next=https://evil.example.com"),
    ).toBe("/update-password");
    expect(resolveSafePostAuthPath(null)).toBe("/update-password");
  });
});

describe("getPasswordRecoveryRedirectTo", () => {
  it("builds an HTTPS production callback under the configured origin", () => {
    const redirectTo = getPasswordRecoveryRedirectTo(
      new URL("https://cms.example.com"),
    );
    const parsed = new URL(redirectTo);

    expect(parsed.protocol).toBe("https:");
    expect(parsed.origin).toBe("https://cms.example.com");
    expect(parsed.pathname).toBe("/auth/callback");
    expect(parsed.searchParams.get("next")).toBe("/update-password");
    expect(redirectTo).not.toContain("localhost");
  });

  it("builds a localhost callback only from a localhost origin", () => {
    const redirectTo = getPasswordRecoveryRedirectTo(
      new URL("http://localhost:3000"),
    );
    const parsed = new URL(redirectTo);

    expect(parsed.protocol).toBe("http:");
    expect(parsed.hostname).toBe("localhost");
    expect(parsed.pathname).toBe("/auth/callback");
  });
});

describe("login status helpers", () => {
  it("keeps login redirects on an internal allow-list", () => {
    expect(getLoginRedirectPath()).toBe("/login");
    expect(getLoginRedirectPath(LOGIN_STATUS_PASSWORD_UPDATED)).toBe(
      "/login?status=password-updated",
    );
    expect(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED)).toBe(
      "/login?status=recovery-failed",
    );
    expect(getLoginRedirectPath("https://evil.example.com")).toBe("/login");
    expect(getLoginRedirectPath("User not found")).toBe("/login");
  });

  it("ignores unknown login status query values", () => {
    expect(readLoginStatus("password-updated")).toBe("password-updated");
    expect(readLoginStatus("recovery-failed")).toBe("recovery-failed");
    expect(readLoginStatus("token=abc")).toBeNull();
    expect(readLoginStatus(["password-updated"])).toBeNull();
  });
});

describe("validateNewPassword", () => {
  it("requires a sufficiently strong password and matching confirmation", () => {
    expect(validateNewPassword("short", "short")).toBe(
      "Choose a password with at least 12 characters.",
    );
    expect(
      validateNewPassword("long-enough-password", "different-password"),
    ).toBe("Password and confirmation must match.");
    expect(
      validateNewPassword("long-enough-password", "long-enough-password"),
    ).toBeNull();
  });
});

describe("isVerifiedRecoverySession", () => {
  it("accepts GoTrue recovery AMR object and RFC-8176 string claims", () => {
    expect(GOTRUE_RECOVERY_AMR_METHODS).toEqual([
      "recovery",
      "otp",
      "magiclink",
    ]);
    expect(
      isVerifiedRecoverySession({
        sub: "user-1",
        amr: [{ method: "recovery", timestamp: 1715766000 }],
      }),
    ).toBe(true);
    expect(
      isVerifiedRecoverySession({
        sub: "user-1",
        amr: ["recovery"],
      }),
    ).toBe(true);
    expect(
      isVerifiedRecoverySession({
        sub: "user-1",
        amr: [{ method: "otp", timestamp: 1715766000 }],
      }),
    ).toBe(true);
    expect(
      isVerifiedRecoverySession({
        sub: "user-1",
        amr: [{ method: "magiclink", timestamp: 1715766000 }],
      }),
    ).toBe(true);
  });

  it("does not treat a password session as recovery", () => {
    expect(
      isVerifiedRecoverySession({
        sub: "user-1",
        amr: [{ method: "password", timestamp: 1715766000 }],
      }),
    ).toBe(false);
    expect(isVerifiedRecoverySession({ sub: "user-1" })).toBe(false);
    expect(
      isVerifiedRecoverySession({
        amr: [{ method: "recovery", timestamp: 1715766000 }],
      }),
    ).toBe(false);
  });
});
