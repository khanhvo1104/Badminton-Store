type StatusBadgeProps = {
  children: string;
  tone?: "success" | "neutral" | "danger";
};

const TONE_CLASS: Record<NonNullable<StatusBadgeProps["tone"]>, string> = {
  success: "border-emerald-300/30 bg-emerald-300/10 text-emerald-200",
  neutral: "border-white/15 bg-white/5 text-slate-200",
  danger: "border-rose-300/30 bg-rose-300/10 text-rose-200",
};

export function StatusBadge({ children, tone = "success" }: StatusBadgeProps) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-3 py-1 text-sm font-medium ${TONE_CLASS[tone]}`}
    >
      {children}
    </span>
  );
}
