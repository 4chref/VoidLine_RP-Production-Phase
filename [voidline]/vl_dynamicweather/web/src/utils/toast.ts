// Basit toast pub/sub (bağımlılıksız). toast(msg) çağrılır; <Toast /> dinler.
type Listener = (msg: string, id: number) => void;

let listeners: Listener[] = [];
let seq = 0;

export function toast(msg: string): void {
    seq += 1;
    const id = seq;
    for (const l of listeners) l(msg, id);
}

export function subscribeToast(l: Listener): () => void {
    listeners.push(l);
    return () => {
        listeners = listeners.filter((x) => x !== l);
    };
}
