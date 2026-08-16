import {
  PublicEnvironmentError,
  type PublicEnvironmentErrorCode,
} from "@/lib/errors/public-environment-error";

type CmsSiteUrlEnvironment = {
  cmsSiteUrl: string | undefined;
  nodeEnv: string | undefined;
};

export function parseCmsSiteUrl(rawEnvironment: CmsSiteUrlEnvironment): URL {
  const cmsSiteUrl = rawEnvironment.cmsSiteUrl?.trim();

  if (!cmsSiteUrl) {
    throw createPublicEnvironmentError("missing-url");
  }

  let parsedUrl: URL;

  try {
    parsedUrl = new URL(cmsSiteUrl);
  } catch {
    throw createPublicEnvironmentError("invalid-url");
  }

  if (parsedUrl.username || parsedUrl.password) {
    throw createPublicEnvironmentError("invalid-url");
  }

  const nodeEnv = rawEnvironment.nodeEnv?.trim() || "development";
  const allowsLocalhost = nodeEnv === "development" || nodeEnv === "test";
  const hostname = parsedUrl.hostname.toLowerCase();
  const isLocalhostHost =
    hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "::1" ||
    hostname === "[::1]";

  if (isLocalhostHost) {
    if (!allowsLocalhost) {
      throw createPublicEnvironmentError("invalid-url");
    }

    if (!["http:", "https:"].includes(parsedUrl.protocol)) {
      throw createPublicEnvironmentError("invalid-url");
    }

    return stripToOrigin(parsedUrl);
  }

  if (parsedUrl.protocol !== "https:") {
    throw createPublicEnvironmentError("invalid-url");
  }

  return stripToOrigin(parsedUrl);
}

export function getCmsSiteUrl(): URL {
  return parseCmsSiteUrl({
    cmsSiteUrl: process.env.CMS_SITE_URL,
    nodeEnv: process.env.NODE_ENV,
  });
}

function stripToOrigin(url: URL): URL {
  return new URL(url.origin);
}

function createPublicEnvironmentError(code: PublicEnvironmentErrorCode) {
  return new PublicEnvironmentError(code);
}
