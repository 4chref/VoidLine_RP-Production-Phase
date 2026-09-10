import { MutableRefObject, useEffect, useRef } from "react";
import type { NuiHandlerSignature, NuiMessageData, Response } from "./types";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

// The original asset (npm package "p-clothing") hardcoded its own resource
// name here. It was renamed to vl_clothing_rad on install, so a fetch to
// https://p-clothing/... pointed at a resource that no longer exists -- every
// click silently failed with nothing to show for it. GetParentResourceName()
// resolves to whatever this resource is actually named, so it survives a
// rename.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const GetParentResourceName: (() => string) | undefined;

function resourceName(): string {
  return typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "vl_clothing_rad";
}

export async function action(name: string, data?: unknown): Promise<boolean> {
  if (isEnvBrowser()) return true;

  const response = await fetch(`https://${resourceName()}/action`, {
    body: JSON.stringify(data ? { ...data, name } : { name }),
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    method: "POST",
  });

  const dataJson: Response = await response.json();
  return dataJson?.state || false;
}

export const useNuiEvent = <T = unknown>(
  action: string,
  handler: (data: T) => void
) => {
  const savedHandler: MutableRefObject<NuiHandlerSignature<T>> = useRef(
    () => {}
  );

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: MessageEvent<NuiMessageData<T>>) => {
      const { action: eventAction, data } = event.data;

      if (savedHandler.current) {
        if (eventAction === action) {
          savedHandler.current(data);
        }
      }
    };

    window.addEventListener("message", eventListener);
    return () => window.removeEventListener("message", eventListener);
  }, [action]);
};
