return {
    serverName = 'Server',
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    notifyPosition = 'top-right', -- 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left'
    ---@type { name: string, amount: integer, metadata: fun(source: number): table }[]
    -- Empty: vl_identity issues the starter kit itself, after the character
    -- exists and its mugshot can be taken. See _framework_patches/README.md.
    starterItems = {}
}
