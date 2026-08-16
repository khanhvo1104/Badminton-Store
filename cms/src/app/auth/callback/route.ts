import { NextResponse, type NextRequest } from "next/server";

import {
  getLoginRedirectPath,
  isPkceAuthCode,
  LOGIN_STATUS_RECOVERY_FAILED,
  resolveSafePostAuthPath,
} from "@/lib/auth/password-recovery";
import { getCmsSiteUrl } from "@/lib/env/cms-site-url";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  let siteUrl: URL;

  try {
    siteUrl = getCmsSiteUrl();
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return new NextResponse("Configuration unavailable", { status: 503 });
    }

    throw error;
  }

  const code = request.nextUrl.searchParams.get("code");
  const nextPath = resolveSafePostAuthPath(
    request.nextUrl.searchParams.get("next"),
  );

  if (!isPkceAuthCode(code)) {
    return NextResponse.redirect(
      new URL(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED), siteUrl),
    );
  }

  try {
    const supabase = await createSupabaseServerClient({ canSetCookies: true });
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      return NextResponse.redirect(
        new URL(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED), siteUrl),
      );
    }
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return new NextResponse("Configuration unavailable", { status: 503 });
    }

    return NextResponse.redirect(
      new URL(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED), siteUrl),
    );
  }

  return NextResponse.redirect(new URL(nextPath, siteUrl));
}
