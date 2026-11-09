-- Single source of truth for Arteria's native, image-free interface.
return {
    color = {
        ink = Color3.fromRGB(8, 8, 8), rail = Color3.fromRGB(16, 16, 16),
        surface = Color3.fromRGB(25, 25, 25), line = Color3.fromRGB(49, 49, 49),
        text = Color3.fromRGB(232, 230, 227), muted = Color3.fromRGB(166, 166, 166),
        neon = Color3.fromRGB(250, 248, 242),
    },
    font = { heading = Enum.Font.Oswald, body = Enum.Font.Gotham, mono = Enum.Font.Code },
    motion = { hover = 0.14, page = 0.24, window = 0.24, expand = 0.2, press = 0.08 },
    width = 840, height = 610, sidebar = 190, compact_sidebar = 60,
}
