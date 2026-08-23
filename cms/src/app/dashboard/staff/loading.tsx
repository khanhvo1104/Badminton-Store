export default function StaffLoading() {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="space-y-3">
        <div className="h-4 w-24 animate-pulse rounded bg-white/10" />
        <div className="h-10 w-72 animate-pulse rounded bg-white/10" />
        <div className="h-20 w-full max-w-3xl animate-pulse rounded bg-white/10" />
      </div>
      <div className="h-64 animate-pulse rounded-3xl bg-white/5" />
      <div className="h-40 animate-pulse rounded-3xl bg-white/5" />
    </div>
  );
}
