// Modal alan etiketi (Figma: opacity-30 SF Pro Semibold 16px).
export default function FieldLabel({ children }: { children: string }) {
    return (
        <p className="text-[16px] font-semibold tracking-[-0.64px] text-white opacity-30">
            {children}
        </p>
    );
}
