import { useEffect, useState } from "react";

// Tasarım 1920x1080 referansıyla çizildi; farklı çözünürlüklerde
// paneli orantılı ölçeklemek için min(genişlik, yükseklik) oranını kullanır.
export function useUiScale(designWidth = 1920, designHeight = 1080): number {
    const compute = () =>
        Math.min(
            window.innerWidth / designWidth,
            window.innerHeight / designHeight
        );

    const [scale, setScale] = useState(compute);

    useEffect(() => {
        const onResize = () => setScale(compute());
        window.addEventListener("resize", onResize);
        return () => window.removeEventListener("resize", onResize);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [designWidth, designHeight]);

    return scale;
}
