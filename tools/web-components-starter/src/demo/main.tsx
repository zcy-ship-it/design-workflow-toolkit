import { useState } from "react";
import { createRoot } from "react-dom/client";
import { ViewSelector } from "../components/ViewSelector";
import type { ViewId } from "../core/contracts";
import "../styles/tokens.css";
function Demo() {
  const [view, setView] = useState<ViewId>("front");
  const [busy, setBusy] = useState(false);
  return (
    <main>
      <h1>组件演示</h1>
      <p>这是可复用起步工程。六视角控件独立于模型转换器，可以放进不同页面。</p>
      <section>
        <h2>六视角选择器</h2>
        <ViewSelector value={view} onChange={setView} disabled={busy} />
        <p role="status">当前视角：{view}</p>
        <label>
          <input
            type="checkbox"
            checked={busy}
            onChange={(e) => setBusy(e.target.checked)}
          />
          模拟处理中，禁用视角选择
        </label>
      </section>
      <aside>
        模型转换、六面渲染和 SVG
        引擎将在后续迁移时接入。当前页面只演示组件与工程流程。
      </aside>
    </main>
  );
}
createRoot(document.getElementById("root")!).render(<Demo />);
