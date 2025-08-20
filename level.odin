package main

import "core:log"
import "gui"
import rl "vendor:raylib"

Level :: struct {
    using rec : rl.Rectangle,
    num_columns, num_rows, num_tiles : int,
    player_start_i : int,
    cell_width, cell_height : f32,
    tiles : [dynamic]Tile,
    enemy_starting_tiles : [dynamic]int
}

Direction :: enum {
    North, East, South, West
}
Direction_Set :: bit_set[Direction]
Direction_Vectors :: [Direction][2]f32 {
    .North = {0,-1},
    .East = {1, 0},
    .South = {0, 1},
    .West = {-1, 0},
}

Tile :: struct {
    render : gui.Renderable,
    valid_directions : Direction_Set
}

Wall :: struct {
    render : gui.Renderable,
    padding : f32
}

find_v2_from_tile_index :: proc(tile_i, column_size: int) -> ([2]int) {
    row := int(tile_i / column_size)
    column := tile_i - (row * column_size)
    return {column, row}
}

draw_walls_from_inverse :: proc(tile: Tile, h_wall, v_wall: Wall, inverse_set: Direction_Set) {
    wall_pos : gui.Position
    wall : Wall
    for i in inverse_set {
        switch i {
            case .North:
                wall_pos = find_wall_position(h_wall, tile, {.North})
                wall = h_wall
                wall.render.x -= (wall.padding/2)
                wall.render.width += wall.padding
            case .East:
                wall_pos = find_wall_position(v_wall, tile, {.East})
                wall = v_wall
                wall.render.y -= (wall.padding/2)
                wall.render.height += wall.padding
            case .South:
                wall_pos = find_wall_position(h_wall, tile, {.South})
                wall = h_wall
                wall.render.x -= (wall.padding/2)
                wall.render.width += wall.padding
            case .West:
                wall_pos = find_wall_position(v_wall, tile, {.West})
                wall = v_wall
                wall.render.y -= (wall.padding/2)
                wall.render.height += wall.padding
        }
        wall.render.x += wall_pos.x
        wall.render.y += wall_pos.y
        gui.draw_rec_render(wall.render)
    }
}

find_wall_position :: proc(wall: Wall, tile: Tile, wall_direction: Direction_Set) -> (gui.Position) {
    wall_pos : gui.Position
    switch wall_direction {
        case {.North}:
            wall_pos.x = tile.render.x
            wall_pos.y = tile.render.y - (wall.render.height/2)
        case {.East}:
            wall_pos.x = tile.render.x + tile.render.width - (wall.render.width/2)
            wall_pos.y = tile.render.y
        case {.South}:
            wall_pos.x = tile.render.x
            wall_pos.y = tile.render.y + tile.render.height - (wall.render.height/2)
        case {.West}:
            wall_pos.x = tile.render.x - (wall.render.width/2)
            wall_pos.y = tile.render.y
    }
    return wall_pos
}

inverse_directions :: proc(directions: Direction_Set) -> (Direction_Set) {
    all_set := Direction_Set{.North, .East, .South, .West}
    return all_set - directions
}

find_next_tile :: proc(level: Level, direction: Direction_Set, tile_i: int) -> (int) {
    next_tile_i : int

    if (direction & {.North}) == {.North} {
        next_tile_i = tile_i - level.num_columns
    }
    else if (direction & {.East}) == {.East} {
        next_tile_i = tile_i + 1
    }
    else if (direction & {.South}) == {.South} {
        next_tile_i = tile_i + level.num_columns
    }
    else if (direction & {.West}) == {.West} {
        next_tile_i = tile_i - 1
    } else {
        next_tile_i = tile_i
    }
    return next_tile_i
}

move_to_tile :: proc(e: ^Entity, tile: Tile) {
    center_position := gui.find_center_position(tile.render.rec)
    offset_position := gui.find_center_offset(e.render.rec, center_position)
    update_position(offset_position, &e.render)
    e.movement.directions = tile.valid_directions
}

update_position_pos :: proc(position: gui.Position, render: ^gui.Renderable) {
    render.x = position.x
    render.y = position.y
}

update_position_rec :: proc(rec: rl.Rectangle, render: ^gui.Renderable) {
    position := gui.Position{rec.x, rec.y}
    update_position_pos(position, render)
}

update_position :: proc{update_position_pos, update_position_rec}

create_level :: proc(x, y, width, height: f32, num_columns, num_rows, player_start_i: int, cell_width, cell_height: f32) -> (Level) {
    level := Level{
        x = x,
        y = y,
        width = width,
        height = height,
        num_columns = num_columns,
        num_rows = num_rows,
        num_tiles = num_columns * num_rows,
        player_start_i = player_start_i,
        cell_width = cell_width,
        cell_height = cell_height,
    }

    row_counter := 0
    tile_counter : int
    level_y: f32 = y
    for r := 0; r < num_rows; r += 1 {
        level_x : f32 = x
        for c := 0; c < num_columns; c += 1 {
            tile : Tile
            color : rl.Color
            if tile_counter % 2 == 0 {
                color = TILE_DARK_COLOR
            } else {
                color = TILE_LIGHT_COLOR
            }
            tile = create_tile(level_x, level_y, cell_width, cell_height, color)
            append(&level.tiles, tile)
            tile_counter += 1
            level_x += cell_width
        }
        level_y += cell_height
        row_counter += 1
        tile_counter = row_counter
    }
    return level
}

create_tile_raw :: proc(x, y, width, height: f32, color: rl.Color) -> (Tile) {
    return Tile{
        render = gui.Renderable{
            color = color,
            rec = rl.Rectangle{x, y, width, height}
        },
        valid_directions = {}
    }
}

create_tile_struct :: proc(render: gui.Renderable) -> (Tile) {
    return Tile{render, {}}
}

create_tile :: proc{create_tile_raw, create_tile_struct}