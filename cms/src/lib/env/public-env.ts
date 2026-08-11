import {
  PublicEnvironmentError,
  type PublicEnvironmentErrorCode,
} from "@/lib/errors/public-environment-error";

export type PublicEnvironment = {
  supabaseUrl: string;
  supabasePublishableKey: string;
};

type RawPublicEnvironment = {
  supabaseUrl: string | undefined;
  supabasePublishableKey: string | undefined;
};

export function parsePublicEnvironment(
  rawEnvironment: RawPublicEnvironment,
): PublicEnvironment {
  const supabaseUrl = rawEnvironment.supabaseUrl?.trim();
  const supabasePublishableKey = rawEnvironment.supabasePublishableKey?.trim();

  if (!supabaseUrl) {
    throw createPublicEnvironmentError("missing-url");
  }

  let parsedUrl: URL;

  try {
    parsedUrl = new URL(supabaseUrl);
  } catch {
    throw createPublicEnvironmentError("invalid-url");
  }

  if (!["http:", "https:"].includes(parsedUrl.protocol)) {
    throw createPublicEnvironmentError("invalid-url");
  }

  if (!supabasePublishableKey) {
    throw createPublicEnvironmentError("missing-publishable-key");
  }

  return {
    supabaseUrl: parsedUrl.toString(),
    supabasePublishableKey,
  };
}

export function getPublicEnvironment(): PublicEnvironment {
  return parsePublicEnvironment({
    supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
    supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
}

function createPublicEnvironmentError(code: PublicEnvironmentErrorCode) {
  return new PublicEnvironmentError(code);
}
