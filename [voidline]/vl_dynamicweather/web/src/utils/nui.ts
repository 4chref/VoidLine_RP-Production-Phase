const resourceName =
    (window as any).GetParentResourceName?.() ?? "codem-dynamicweather";

export const IS_BROWSER = !(window as any).GetParentResourceName;

export async function fetchNui<T = any>(
    event: string,
    data?: Record<string, unknown>
): Promise<T> {
    // Tarayıcıda (npm run dev) mock'lara düş
    if (import.meta.env.DEV && IS_BROWSER) {
        return mockNuiCallback<T>(event, data);
    }

    const resp = await fetch(`https://${resourceName}/${event}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify(data ?? {}),
    });

    const text = await resp.text();
    if (!text) return {} as T;

    try {
        return JSON.parse(text) as T;
    } catch {
        return {} as T;
    }
}

export function sendNui(event: string, data?: Record<string, unknown>): void {
    fetchNui(event, data);
}

// ── Dev modu mock sistemi ──────────────────────────────────────────

const mockCallbacks: Record<string, (data?: any) => any> = {};

export function registerMock(event: string, callback: (data?: any) => any) {
    mockCallbacks[event] = callback;
}

async function mockNuiCallback<T>(
    event: string,
    data?: Record<string, unknown>
): Promise<T> {
    const handler = mockCallbacks[event];
    if (handler) {
        return handler(data) as T;
    }
    console.log(`[NUI Mock] No mock registered for event: ${event}`);
    return {} as T;
}
