import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./index.css";
import { IS_BROWSER } from "./utils/nui";
import { setupMocks } from "./mocks";

if (import.meta.env.DEV && IS_BROWSER) {
    setupMocks();
}

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <App />
    </StrictMode>
);
