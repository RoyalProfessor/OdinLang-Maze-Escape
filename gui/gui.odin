package gui

// Import
import rl "vendor:raylib"

// Constants


// Globals


// Structs

Position :: struct {
    x, y : f32
}

Renderable :: struct {
    color: rl.Color,
    using rec : rl.Rectangle
}

TextureRenderable :: struct {
    texture : rl.Texture2D,
    using position : Position
}


// Procs

button_click_render :: proc(render: Renderable, zoom: f32, line_thick: f32 = 0, mouse_click: rl.MouseButton = rl.MouseButton.LEFT) -> (bool) {
    mouse_pos := rl.GetMousePosition()
    mouse_x := mouse_pos[0]
    mouse_y := mouse_pos[1]
    lower_x := (render.x + line_thick) * zoom
    upper_x := (render.x * zoom) + ((render.width - line_thick) * zoom)
    lower_y := (render.y + line_thick) * zoom
    upper_y := (render.y * zoom) + ((render.height - line_thick) * zoom)
    return mouse_x >= lower_x && mouse_x <= upper_x && mouse_y >= lower_y && mouse_y <= upper_y && rl.IsMouseButtonPressed(mouse_click) == true
}
