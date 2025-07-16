package main

// Imports
import rl "vendor:raylib"
import "core:fmt"
import "core:mem"
import "core:log"
import "gui"

// Aliases
Position :: rl.Vector2

// Constants
WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 1000
WINDOW_TITLE :: "Maze Escape"
ZOOM_MULTIPLIER :: WINDOW_WIDTH / (CELL_WIDTH * NUM_COLUMNS)

NUM_ROWS :: 6
NUM_COLUMNS :: 6
CELL_WIDTH :: f32(64)
CELL_HEIGHT :: f32(64)
LEVEL_POSITION :: Position{0,0}

BACKGROUND_COLOR :: rl.PURPLE
TILE_DARK_COLOR :: rl.DARKBROWN
TILE_LIGHT_COLOR :: rl.BROWN

TOP_LEFT_CORNER :: Direction_Set{.East, .South}
TOP_RIGHT_CORNER :: Direction_Set{.South, .West}
TOP_TILE :: Direction_Set{.East, .South, .West}
BOTTOM_LEFT_CORNER :: Direction_Set{.North, .East}
BOTTOM_RIGHT_CORNER :: Direction_Set{.North, .West}
BOTTOM_TILE :: Direction_Set{.North, .East, .West}
LEFT_TILE :: Direction_Set{.North, .East, .South}
RIGHT_TILE :: Direction_Set{.North, .South, .East}
MIDDLE_TILE :: Direction_Set{.North, .East, .South, .West}

// Globals


main :: proc() {

    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                for _, entry in track.allocation_map {
                    fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
                }
            }
            if len(track.bad_free_array) > 0 {
                for entry in track.bad_free_array {
                    fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    context.logger = log.create_console_logger()

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
    log.info("Program Start.")

    // Create level.
    level := create_level(LEVEL_POSITION.x, LEVEL_POSITION.y, CELL_WIDTH, CELL_HEIGHT, NUM_COLUMNS, NUM_ROWS, CELL_WIDTH, CELL_HEIGHT)

    // Create list of directions to assign to tiles.
    directions : [dynamic]Direction_Set
    append(&directions, TOP_LEFT_CORNER, TOP_TILE,TOP_TILE,TOP_TILE, TOP_TILE, TOP_RIGHT_CORNER,
      LEFT_TILE, MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,RIGHT_TILE,
      LEFT_TILE, MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,RIGHT_TILE,
      LEFT_TILE, MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,RIGHT_TILE,
      LEFT_TILE, MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,MIDDLE_TILE,RIGHT_TILE,
      BOTTOM_LEFT_CORNER, BOTTOM_TILE, BOTTOM_TILE, BOTTOM_TILE, BOTTOM_TILE, BOTTOM_RIGHT_CORNER
    )

    for i in 0..<len(level.tiles) {
        level.tiles[i].valid_directions = directions[i]
    }


    for !rl.WindowShouldClose() {

        for t in level.tiles {
            if gui.button_click_render(t.render, ZOOM_MULTIPLIER) {
                log.info(t)
            }
        }

        // Rendering Start
        rl.BeginDrawing()
        rl.ClearBackground(BACKGROUND_COLOR)

        camera := rl.Camera2D{
            zoom = ZOOM_MULTIPLIER
        }

        rl.BeginMode2D(camera)

        for i in 0..<len(level.tiles) {
            tile := level.tiles[i]
            rl.DrawRectangleRec(tile.render.rec, tile.render.color)
        }


        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    when ODIN_DEBUG {
        delete(level.tiles)
        delete(directions)
    }
}

// Structs
Level :: struct {
    using rec : rl.Rectangle,
    num_columns, num_rows, num_tiles : int,
    cell_width, cell_height : f32,
    tiles : [dynamic]Tile
}

Direction :: enum {
    North, East, South, West
}
Direction_Set :: bit_set[Direction]
Direction_Vectors :: [Direction][2]int {
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
}

Player :: struct {
    render : gui.Renderable,
    movement : Direction
}

Entity_Movement :: struct {
    num_moves : int
}

// Procs
create_level :: proc(x, y, width, height: f32, num_columns, num_rows: int, cell_width, cell_height: f32) -> (Level) {
    level := Level{
        x = x,
        y = y,
        width = width,
        height = height,
        num_columns = num_columns,
        num_rows = num_rows,
        num_tiles = num_columns * num_rows,
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