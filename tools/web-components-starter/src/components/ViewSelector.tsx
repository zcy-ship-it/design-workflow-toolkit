import type { ViewId } from "../core/contracts";
export interface ViewSelectorProps {
  value: ViewId;
  onChange: (view: ViewId) => void;
  disabled?: boolean;
  label?: string;
}
const items: ReadonlyArray<{ id: ViewId; label: string }> = [
  { id: "front", label: "正面" },
  { id: "rear", label: "背面" },
  { id: "left", label: "左侧" },
  { id: "right", label: "右侧" },
  { id: "top", label: "顶面" },
  { id: "bottom", label: "底面" },
];
/** Controlled UI only: no camera, model, or conversion dependency. */
export function ViewSelector({
  value,
  onChange,
  disabled = false,
  label = "模型视角",
}: ViewSelectorProps) {
  return (
    <fieldset disabled={disabled} className="view-selector">
      <legend>{label}</legend>
      <div className="view-selector__buttons">
        {items.map((item) => (
          <button
            type="button"
            key={item.id}
            aria-pressed={value === item.id}
            onClick={() => onChange(item.id)}
          >
            {item.label}
          </button>
        ))}
      </div>
    </fieldset>
  );
}
