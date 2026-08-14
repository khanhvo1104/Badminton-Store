import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_UPDATE_PASSWORD_FORM_STATE } from "@/features/auth/update-password-form-state";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

describe("updatePassword action", () => {
  beforeEach(() => {
    redirect.mockReset();
    createSupabaseServerClient.mockReset();
  });
  it("rejects a weak password without calling Supabase", async () => {
    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "short");
    formData.set("confirmPassword", "short");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "Choose a password with at least 12 characters.",
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });

  it("rejects a confirmation mismatch without calling Supabase", async () => {
    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "different-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "Password and confirmation must match.",
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });

  it("redirects when a verified recovery session is missing", async () => {
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims: { sub: "user-1", amr: [{ method: "password" }] } },
          error: null,
        }),
        updateUser: vi.fn(),
        signOut: vi.fn(),
      },
    });
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });

    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "long-enough-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).rejects.toThrow("NEXT_REDIRECT:/login?status=recovery-failed");
  });

  it("returns a sanitized failure when the password update fails", async () => {
    const updateUser = vi.fn().mockResolvedValue({
      data: { user: null },
      error: new Error("Password reused: leak details"),
    });
    const signOut = vi.fn();
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: {
              sub: "user-1",
              amr: [{ method: "recovery", timestamp: 1 }],
            },
          },
          error: null,
        }),
        updateUser,
        signOut,
      },
    });

    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "long-enough-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "We couldn't update your password. Try again.",
    });
    expect(signOut).not.toHaveBeenCalled();
    expect(redirect).not.toHaveBeenCalled();
  });

  it("clears the recovery session and redirects to a generic login success", async () => {
    const updateUser = vi.fn().mockResolvedValue({
      data: { user: { id: "user-1" } },
      error: null,
    });
    const signOut = vi.fn().mockResolvedValue({ error: null });
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: {
              sub: "user-1",
              amr: [{ method: "recovery", timestamp: 1 }],
            },
          },
          error: null,
        }),
        updateUser,
        signOut,
      },
    });
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });

    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "long-enough-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).rejects.toThrow("NEXT_REDIRECT:/login?status=password-updated");
    expect(updateUser).toHaveBeenCalledWith({
      password: "long-enough-password",
    });
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(redirect).toHaveBeenCalledWith("/login?status=password-updated");
    expect(String(redirect.mock.calls[0]?.[0])).not.toMatch(
      /token|password=|leak|sql/i,
    );
  });

  it("does not report success when sign-out returns an error", async () => {
    const updateUser = vi.fn().mockResolvedValue({
      data: { user: { id: "user-1" } },
      error: null,
    });
    const signOut = vi.fn().mockResolvedValue({
      error: new Error("session revoke failed: internal host"),
    });
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: {
              sub: "user-1",
              amr: [{ method: "recovery", timestamp: 1 }],
            },
          },
          error: null,
        }),
        updateUser,
        signOut,
      },
    });

    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "long-enough-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "We couldn't update your password. Try again.",
    });
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(redirect).not.toHaveBeenCalled();
  });

  it("does not report success when sign-out throws", async () => {
    const updateUser = vi.fn().mockResolvedValue({
      data: { user: { id: "user-1" } },
      error: null,
    });
    const signOut = vi
      .fn()
      .mockRejectedValue(new Error("cookie store unavailable"));
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: {
              sub: "user-1",
              amr: [{ method: "recovery", timestamp: 1 }],
            },
          },
          error: null,
        }),
        updateUser,
        signOut,
      },
    });

    const { updatePassword } = await import(
      "@/features/auth/actions/update-password"
    );
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("confirmPassword", "long-enough-password");

    await expect(
      updatePassword(INITIAL_UPDATE_PASSWORD_FORM_STATE, formData),
    ).resolves.toEqual({
      errorMessage: "We couldn't update your password. Try again.",
    });
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(redirect).not.toHaveBeenCalled();
  });
});
