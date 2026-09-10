import { useEffect, useRef } from "react";

interface NuiMessage<T = unknown> {
    action: string;
    data: T;
}

// Lua'dan SendNUIMessage ile gelen mesajları dinler:
//   SendNUIMessage({ action = 'setVisible', data = true })
export function useNuiEvent<T = unknown>(
    action: string,
    handler: (data: T) => void
) {
    const savedHandler = useRef(handler);
    savedHandler.current = handler;

    useEffect(() => {
        const listener = (event: MessageEvent<NuiMessage<T>>) => {
            if (event.data?.action === action) {
                savedHandler.current(event.data.data);
            }
        };

        window.addEventListener("message", listener);
        return () => window.removeEventListener("message", listener);
    }, [action]);
}
