package gui

// Import
import rl "vendor:raylib"

// Constants

// Structs
Position :: rl.Vector2

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

find_center_position :: proc(rec: rl.Rectangle) -> (Position) {
    center_x := rec.x + (rec.width/2)
    center_y := rec.y + (rec.height/2)
    return Position{center_x, center_y}
}

find_center_offset :: proc(rec: rl.Rectangle, center: Position) -> (Position) {
    offset_x := center.x - (rec.width/2)
    offset_y := center.y - (rec.height/2)
    return Position{offset_x, offset_y}
}

draw_rec_render :: proc(render: Renderable) {
    rl.DrawRectangleRec(render.rec, render.color)
}
