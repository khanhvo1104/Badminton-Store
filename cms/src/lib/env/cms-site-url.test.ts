import { afterEach, describe, expect, it } from "vitest";

import { getCmsSiteUrl, parseCmsSiteUrl } from "@/lib/env/cms-site-url";
import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

const ORIGINAL_CMS_SITE_URL = process.env.CMS_SITE_URL;

afterEach(() => {
  if (ORIGINAL_CMS_SITE_URL === undefined) {
    delete process.env.CMS_SITE_URL;
  } else {
    process.env.CMS_SITE_URL = ORIGINAL_CMS_SITE_URL;
  }
});

describe("parseCmsSiteUrl", () => {
  it("accepts an HTTPS production CMS origin", () => {
    expect(
      parseCmsSiteUrl({
        cmsSiteUrl: " https://cms.example.com/admin ",
        nodeEnv: "production",
      }).toString(),
    ).toBe("https://cms.example.com/");
  });

  it("accepts localhost only in development and test configuration", () => {
    expect(
      parseCmsSiteUrl({
        cmsSiteUrl: "http://localhost:3000",
        nodeEnv: "development",
      }).toString(),
    ).toBe("http://localhost:3000/");
    expect(
      parseCmsSiteUrl({
        cmsSiteUrl: "http://127.0.0.1:3000",
        nodeEnv: "test",
      }).toString(),
    ).toBe("http://127.0.0.1:3000/");
  });

  it.each([
    {
      name: "missing CMS site URL",
      input: {
        cmsSiteUrl: undefined,
        nodeEnv: "production",
      },
      expectedCode: "missing-url",
    },
    {
      name: "blank CMS site URL",
      input: {
        cmsSiteUrl: "   ",
        nodeEnv: "development",
      },
      expectedCode: "missing-url",
    },
    {
      name: "malformed CMS site URL",
      input: {
        cmsSiteUrl: "not-a-url",
        nodeEnv: "development",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "HTTP non-local production origin",
      input: {
        cmsSiteUrl: "http://cms.example.com",
        nodeEnv: "production",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "localhost in production",
      input: {
        cmsSiteUrl: "http://localhost:3000",
        nodeEnv: "production",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "HTTPS localhost in production",
      input: {
        cmsSiteUrl: "https://localhost",
        nodeEnv: "production",
      },
      expectedCode: "invalid-url",
    },
    {
      name: "credentials in the CMS site URL",
      input: {
        cmsSiteUrl: "https://user:pass@cms.example.com",
        nodeEnv: "production",
      },
      expectedCode: "invalid-url",
    },
  ])("rejects $name", ({ input, expectedCode }) => {
    try {
      parseCmsSiteUrl(input);
      throw new Error("Expected CMS site URL parsing to fail.");
    } catch (error) {
      expect(error).toBeInstanceOf(PublicEnvironmentError);
      expect(error).toMatchObject({
        code: expectedCode,
        message: "Invalid public environment configuration.",
      });
    }
  });

  it("never falls back to localhost when configuration is missing", () => {
    try {
      parseCmsSiteUrl({
        cmsSiteUrl: undefined,
        nodeEnv: "production",
      });
      throw new Error("Expected CMS site URL parsing to fail.");
    } catch (error) {
      expect(error).toBeInstanceOf(PublicEnvironmentError);
      expect(String(error)).not.toMatch(/localhost/i);
    }
  });
});

describe("getCmsSiteUrl", () => {
  it("reads the validated CMS origin from process.env", () => {
    process.env.CMS_SITE_URL = "https://cms.example.com";

    expect(getCmsSiteUrl().toString()).toBe("https://cms.example.com/");
  });
});
