import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_FORGOT_PASSWORD_FORM_STATE } from "@/features/auth/forgot-password-form-state";
import { PASSWORD_RECOVERY_ACKNOWLEDGEMENT } from "@/lib/auth/password-recovery";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getCmsSiteUrl = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/env/cms-site-url", () => ({
  getCmsSiteUrl,
}));

describe("requestPasswordReset action", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getCmsSiteUrl.mockReset();
  });
  it("rejects invalid email without calling Supabase", async () => {
    const { requestPasswordReset } = await import(
      "@/features/auth/actions/request-password-reset"
    );

    const formData = new FormData();
    formData.set("email", "not-an-email");

    await expect(
      requestPasswordReset(INITIAL_FORGOT_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "Enter a valid email address.",
      acknowledgement: null,
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });

  it("returns the same acknowledgement when the account exists", async () => {
    const resetPasswordForEmail = vi.fn().mockResolvedValue({
      data: {},
      error: null,
    });
    getCmsSiteUrl.mockReturnValue(new URL("https://cms.example.com"));
    createSupabaseServerClient.mockResolvedValue({
      auth: { resetPasswordForEmail },
    });

    const { requestPasswordReset } = await import(
      "@/features/auth/actions/request-password-reset"
    );
    const formData = new FormData();
    formData.set("email", " staff@example.com ");

    await expect(
      requestPasswordReset(INITIAL_FORGOT_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: null,
      acknowledgement: PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
    });

    const redirectTo = resetPasswordForEmail.mock.calls[0]?.[1]?.redirectTo;
    const parsed = new URL(String(redirectTo));
    expect(resetPasswordForEmail).toHaveBeenCalledWith("staff@example.com", {
      redirectTo,
    });
    expect(parsed.protocol).toBe("https:");
    expect(parsed.origin).toBe("https://cms.example.com");
    expect(parsed.pathname).toBe("/auth/callback");
    expect(parsed.searchParams.get("next")).toBe("/update-password");
  });

  it("returns the same acknowledgement when the provider reports an unknown account", async () => {
    const resetPasswordForEmail = vi.fn().mockResolvedValue({
      data: {},
      error: new Error("User not found"),
    });
    getCmsSiteUrl.mockReturnValue(new URL("https://cms.example.com"));
    createSupabaseServerClient.mockResolvedValue({
      auth: { resetPasswordForEmail },
    });

    const { requestPasswordReset } = await import(
      "@/features/auth/actions/request-password-reset"
    );
    const formData = new FormData();
    formData.set("email", "missing@example.com");

    await expect(
      requestPasswordReset(INITIAL_FORGOT_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: null,
      acknowledgement: PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
    });
  });

  it("returns the same acknowledgement when the provider throws", async () => {
    const resetPasswordForEmail = vi
      .fn()
      .mockRejectedValue(new Error("rate limited for missing@example.com"));
    getCmsSiteUrl.mockReturnValue(new URL("https://cms.example.com"));
    createSupabaseServerClient.mockResolvedValue({
      auth: { resetPasswordForEmail },
    });

    const { requestPasswordReset } = await import(
      "@/features/auth/actions/request-password-reset"
    );
    const formData = new FormData();
    formData.set("email", "missing@example.com");

    await expect(
      requestPasswordReset(INITIAL_FORGOT_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: null,
      acknowledgement: PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
    });
  });

  it("uses a localhost callback only from development/test configuration", async () => {
    const resetPasswordForEmail = vi.fn().mockResolvedValue({
      data: {},
      error: null,
    });
    getCmsSiteUrl.mockReturnValue(new URL("http://localhost:3000"));
    createSupabaseServerClient.mockResolvedValue({
      auth: { resetPasswordForEmail },
    });

    const { requestPasswordReset } = await import(
      "@/features/auth/actions/request-password-reset"
    );
    const formData = new FormData();
    formData.set("email", "staff@example.com");

    await requestPasswordReset(INITIAL_FORGOT_PASSWORD_FORM_STATE, formData);

    const redirectTo = String(
      resetPasswordForEmail.mock.calls[0]?.[1]?.redirectTo,
    );
    const parsed = new URL(redirectTo);
    expect(parsed.protocol).toBe("http:");
    expect(parsed.hostname).toBe("localhost");
    expect(parsed.pathname).toBe("/auth/callback");
  });
});
