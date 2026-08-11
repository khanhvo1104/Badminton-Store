import { describe, expect, it } from "vitest";

import {
  getPublicEnvironment,
  parsePublicEnvironment,
} from "@/lib/env/public-env";
import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

describe("parsePublicEnvironment", () => {
  it("accepts non-empty valid public Supabase configuration", () => {
    expect(
      parsePublicEnvironment({
        supabaseUrl: " https://demo-project.supabase.co ",
        supabasePublishableKey: " public-demo-key ",
      }),
    ).toEqual({
      supabaseUrl: "https://demo-project.supabase.co/",
      supabasePublishableKey: "public-demo-key",
    });
  });

  it.each([
    {
      name: "missing Supabase URL",
      input: {
        supabaseUrl: undefined,
        supabasePublishableKey: "public-demo-key",
      },
      expectedCode: "missing-url",
    },
    {
      name: "blank Supabase URL",
      input: {
        supabaseUrl: "   ",
        supabasePublishableKey: "public-demo-key",
      },
      expectedCode: "missing-url",
    },
    {
      name: "non-http Supabase URL",
      input: {
        supabaseUrl: "ftp://demo-project.supabase.co",
        supabasePublishableKey: "public-demo-key",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "malformed Supabase URL",
      input: {
        supabaseUrl: "not-a-url",
        supabasePublishableKey: "public-demo-key",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "missing publishable key",
      input: {
        supabaseUrl: "https://demo-project.supabase.co",
        supabasePublishableKey: undefined,
      },
      expectedCode: "missing-publishable-key",
    },
    {
      name: "blank publishable key",
      input: {
        supabaseUrl: "https://demo-project.supabase.co",
        supabasePublishableKey: "   ",
      },
      expectedCode: "missing-publishable-key",
    },
  ])("rejects $name", ({ input, expectedCode }) => {
    try {
      parsePublicEnvironment(input);
      throw new Error("Expected public environment parsing to fail.");
    } catch (error) {
      expect(error).toBeInstanceOf(PublicEnvironmentError);
      expect(error).toMatchObject({
        code: expectedCode,
        message: "Invalid public environment configuration.",
      });
    }
  });

  it("reads validated public configuration from process.env", () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "publishable-key";

    expect(getPublicEnvironment()).toEqual({
      supabaseUrl: "https://example.supabase.co/",
      supabasePublishableKey: "publishable-key",
    });
  });
});
