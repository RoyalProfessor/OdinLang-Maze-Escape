package main

// Imports
import rl "vendor:raylib"
import "core:fmt"
import "core:mem"
import "core:log"
import "core:math"
import "gui"

// Aliases

// Constants
WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 1000
WINDOW_TITLE :: "Maze Escape"
ZOOM_MULTIPLIER :: WINDOW_WIDTH / (CELL_WIDTH * NUM_COLUMNS)

NUM_ROWS :: 6
NUM_COLUMNS :: 6
CELL_WIDTH :: f32(64)
CELL_HEIGHT :: f32(64)
LEVEL_POSITION :: gui.Position{0,0}

BACKGROUND_COLOR :: rl.PURPLE
TILE_DARK_COLOR :: rl.DARKBROWN
TILE_LIGHT_COLOR :: rl.BROWN
WALL_COLOR :: rl.BLACK

// Empty Tiles
TOP_LEFT_CORNER :: Direction_Set{.East, .South}
TOP_RIGHT_CORNER :: Direction_Set{.South, .West}
TOP_TILE :: Direction_Set{.East, .South, .West}
BOTTOM_LEFT_CORNER :: Direction_Set{.North, .East}
BOTTOM_RIGHT_CORNER :: Direction_Set{.North, .West}
BOTTOM_TILE :: Direction_Set{.North, .East, .West}
LEFT_TILE :: Direction_Set{.North, .East, .South}
RIGHT_TILE :: Direction_Set{.North, .South, .West}
MIDDLE_TILE :: Direction_Set{.North, .East, .South, .West}

// Walls
WALL_PADDING :: f32(7)
HORIZONTAL_WALL :: Wall{
    render = {
        color = WALL_COLOR,
        x = 0,
        y = 0,
        width = CELL_WIDTH,
        height = WALL_PADDING
    },
    padding = WALL_PADDING
}
VERTICAL_WALL :: Wall{
    render = {
        color = WALL_COLOR,
        x = 0,
        y = 0,
        width = WALL_PADDING,
        height = CELL_HEIGHT
    },
    padding = WALL_PADDING
}

// Player Constants
PLAYER_RENDER :: gui.Renderable{rl.RED,{0, 0, 40, 40}}
PLAYER_SPEED :: f32(600)
PLAYER_MOVES :: 1
PLAYER_ATTACK :: 0

// White Mummy Constants
WHITE_MUMMY_RENDER :: gui.Renderable{rl.WHITE,{0, 0, 40, 40}}
WHITE_MUMMY_SPEED :: f32(400)
WHITE_MUMMY_MOVES :: 2
WHITE_MUMMY_ATTACK :: 2

// Globals
player_ptr : ^Entity
player_start_i : int = 30
white_mummy_start_i : int = 8
delta_time : f32
turn_context : Turn_Context
entities : Entity_List

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

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
    context.logger = log.create_console_logger(); defer {log.destroy_console_logger(context.logger)}
    log.info("Program Start.")

    // Create level.
    level := create_level(LEVEL_POSITION.x, LEVEL_POSITION.y, CELL_WIDTH, CELL_HEIGHT, NUM_COLUMNS, NUM_ROWS, player_start_i, CELL_WIDTH, CELL_HEIGHT)
    append(&level.enemy_starting_tiles, white_mummy_start_i)

    // Create list of directions to assign to tiles.
    directions : [dynamic]Direction_Set
    append(&directions,
        Direction_Set{.East, .South}, Direction_Set{.East, .West}, Direction_Set{.East, .South, .West}, Direction_Set{.South, .West}, Direction_Set{.South}, Direction_Set{.South},
        Direction_Set{.North}, Direction_Set{.East, .South}, Direction_Set{.North, .East, .South, .West}, Direction_Set{.North, .East, .South, .West}, Direction_Set{.North, .East, .South, .West}, Direction_Set{.North, .South, .West},
        Direction_Set{.East, .South}, Direction_Set{.North, .South, .West}, Direction_Set{.North, .East, .South}, Direction_Set{.North, .East, .West}, Direction_Set{.North, .East, .South, .West}, Direction_Set{.North, .South, .West},
        Direction_Set{.North, .South}, Direction_Set{.North, .East, .South}, Direction_Set{.North, .South, .West}, Direction_Set{.South}, Direction_Set{.North, .East, .South}, Direction_Set{.North, .South, .West},
        Direction_Set{.North}, Direction_Set{.North, .South}, Direction_Set{.North, .East, .South}, Direction_Set{.North, .South, .West}, Direction_Set{.North, .East, .South}, Direction_Set{.North, .South, .West},
        Direction_Set{.East}, Direction_Set{.North, .East, .West}, Direction_Set{.North, .East, .West}, Direction_Set{.North, .West}, Direction_Set{.North, .East}, Direction_Set{.North, .West}
    )

    for i in 0..<len(level.tiles) {
        level.tiles[i].valid_directions = directions[i]
    }

    player := Entity{
        render = PLAYER_RENDER,
        movement = Entity_Movement{
            tile_i = level.player_start_i,
            num_moves = PLAYER_MOVES,
            move_speed = PLAYER_SPEED,
            directions = level.tiles[level.player_start_i].valid_directions
        },
        actor_type = .Player,
        entity_type = .Explorer,
        move_pref = .None,
        attack = PLAYER_ATTACK,
        index = 0
    }
    insert_entity_into_list(player, &entities)
    entities.player_i = player.index
    player_ptr = &entities.arr[player.index]

    log.info(level.enemy_starting_tiles)

    mummy := Entity{
        render = WHITE_MUMMY_RENDER,
        movement = Entity_Movement{
            tile_i = level.enemy_starting_tiles[0],
            num_moves = WHITE_MUMMY_MOVES,
            move_speed = WHITE_MUMMY_SPEED,
            directions = level.tiles[level.enemy_starting_tiles[0]].valid_directions
        },
        actor_type = .AI,
        entity_type = .White_Mummy,
        move_pref = .Horizontal,
        attack = WHITE_MUMMY_ATTACK,
        index = 1
    }
    insert_entity_into_list(mummy, &entities)

    move_to_tile(&entities.arr[0], level.tiles[level.player_start_i])
    move_to_tile(&entities.arr[1], level.tiles[white_mummy_start_i])

    mummy_ptr := &entities.arr[mummy.index]

    reset_entity_context(player.index, &turn_context.entity_context, entities)
    turn_context.state = .Input
    turn_context.current_turn = 0

    for !rl.WindowShouldClose() {
        delta_time = rl.GetFrameTime()

        for i in 0..<len(level.tiles) {
            if gui.button_click_render(level.tiles[i].render, ZOOM_MULTIPLIER) {
                log.info(i, level.tiles[i])
            }
        }

        if gui.button_click_render(player_ptr.render, ZOOM_MULTIPLIER) {
            // log.info("Player:", player_ptr)
            // log.info("Turn Context:", turn_context)
            log.info("Entities:", len(entities.arr))
        }
        if gui.button_click_render(mummy_ptr.render, ZOOM_MULTIPLIER) {
            log.info(mummy_ptr)
        }

        turn_state_handler(&turn_context, &entities, level)

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

        for i in 0..<len(level.tiles) {
            tile := level.tiles[i]
            inverse_set := inverse_directions(tile.valid_directions)
            draw_walls_from_inverse(tile, HORIZONTAL_WALL, VERTICAL_WALL, inverse_set)
        }

        for e in entities.arr {
            rl.DrawRectangleRec(e.render.rec, e.render.color)
        }

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    when ODIN_DEBUG {
        delete(level.tiles)
        delete(directions)
        delete(entities.arr)
        delete(level.enemy_starting_tiles)
    }
}