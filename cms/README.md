# Badminton Store CMS

Production-oriented Next.js App Router scaffold for the Badminton Store
administration product.

## Setup

1. Install dependencies with `npm ci`.
2. Copy `.env.example` to a local `.env` file.
3. Set safe public placeholders or real local values for:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

## Commands

```bash
npm run dev
npm run format
npm run format:check
npm run lint
npm run typecheck
npm test -- --run
npm run build
```

This scaffold validates the public Supabase environment at startup, but it does
not create a Supabase client, perform authentication, or make live network
requests.
