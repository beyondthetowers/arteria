-- Single source of truth for Arteria's native, image-free interface.
return {
    color = {
        ink = Color3.fromRGB(8, 8, 9),
        rail = Color3.fromRGB(13, 13, 14),
        surface = Color3.fromRGB(22, 22, 25),
        surface_hover = Color3.fromRGB(34, 34, 38),
        rail_active = Color3.fromRGB(26, 26, 30),
        line = Color3.fromRGB(40, 40, 45),
        line_neon = Color3.fromRGB(180, 185, 200),
        text = Color3.fromRGB(245, 243, 240),
        muted = Color3.fromRGB(168, 168, 175),
        dim = Color3.fromRGB(115, 115, 122),
        neon = Color3.fromRGB(255, 255, 255),
        neon_glow = Color3.fromRGB(235, 242, 255),
        alert = Color3.fromRGB(255, 75, 75),
        alert_glow = Color3.fromRGB(255, 130, 130),
    },
    font = { heading = Enum.Font.Oswald, body = Enum.Font.Gotham, mono = Enum.Font.Code },
    motion = { hover = 0.12, page = 0.22, window = 0.22, expand = 0.20, press = 0.08 },
    width = 880, height = 630, sidebar = 210, compact_sidebar = 64,
}
