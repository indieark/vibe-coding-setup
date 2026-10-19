import { Check } from "lucide-react";

export function Toggle({
  checked,
  onChange,
  disabled = false,
  label,
}: {
  checked: boolean;
  onChange: () => void;
  disabled?: boolean;
  label: string;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      className={"checkbox " + (checked ? "selected" : "")}
      onClick={onChange}
    >
      {checked && <Check size={13} strokeWidth={3} />}
    </button>
  );
}
