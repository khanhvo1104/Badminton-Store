import { describe, expect, it, vi } from "vitest";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

describe("login action", () => {
  it("rejects empty trimmed credentials without calling Supabase", async () => {
    const { INITIAL_LOGIN_FORM_STATE, login } = await import(
      "@/features/auth/actions/login"
    );

    const formData = new FormData();
    formData.set("email", "   ");
    formData.set("password", "   ");

    await expect(login(INITIAL_LOGIN_FORM_STATE, formData)).resolves.toEqual({
      errorMessage: "We couldn't sign you in with those credentials.",
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });

  it("trims credentials and returns sanitized failures", async () => {
    const signInWithPassword = vi.fn().mockResolvedValue({
      data: { session: null, user: null },
      error: new Error("backend details should not leak"),
    });

    createSupabaseServerClient.mockResolvedValue({
      auth: {
        signInWithPassword,
      },
    });

    const { INITIAL_LOGIN_FORM_STATE, login } = await import(
      "@/features/auth/actions/login"
    );

    const formData = new FormData();
    formData.set("email", " staff@example.com ");
    formData.set("password", " secret-password ");

    await expect(login(INITIAL_LOGIN_FORM_STATE, formData)).resolves.toEqual({
      errorMessage: "We couldn't sign you in with those credentials.",
    });
    expect(signInWithPassword).toHaveBeenCalledWith({
      email: "staff@example.com",
      password: "secret-password",
    });
  });

  it("redirects only to the fixed dashboard route on success", async () => {
    const signInWithPassword = vi.fn().mockResolvedValue({
      data: { session: { access_token: "token" } },
      error: null,
    });

    createSupabaseServerClient.mockResolvedValue({
      auth: {
        signInWithPassword,
      },
    });

    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/dashboard");
    });

    const { INITIAL_LOGIN_FORM_STATE, login } = await import(
      "@/features/auth/actions/login"
    );

    const formData = new FormData();
    formData.set("email", "admin@example.com");
    formData.set("password", "password123");
    formData.set("next", "https://evil.example.com");

    await expect(login(INITIAL_LOGIN_FORM_STATE, formData)).rejects.toThrow(
      "NEXT_REDIRECT:/dashboard",
    );
    expect(redirect).toHaveBeenCalledWith("/dashboard");
  });
});
