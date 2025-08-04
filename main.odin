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

PLAYER_RENDER :: gui.Renderable{rl.RED,{0,0, 40, 40}}
PLAYER_SPEED :: f32(480)

// Globals
player_ptr : ^Entity
player_start_i : int = 30
delta_time : f32
turn_context : Turn_Context
entity_context : Entity_Context
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
            num_moves = 1,
            move_speed = PLAYER_SPEED,
            directions = level.tiles[level.player_start_i].valid_directions
        },
        index = 0
    }
    append(&entities.arr, player)
    player.index = len(entities.arr)-1
    player_ptr = &entities.arr[player.index]

    move_to_tile(&entities.arr[0], level.tiles[level.player_start_i])

    reset_entity_context(player.index, &entity_context, entities)

    for !rl.WindowShouldClose() {
        delta_time = rl.GetFrameTime()

        for i in 0..<len(level.tiles) {
            if gui.button_click_render(level.tiles[i].render, ZOOM_MULTIPLIER) {
                log.info(i, level.tiles[i])
            }
        }

        if gui.button_click_render(player_ptr.render, ZOOM_MULTIPLIER) {
            log.info(player_ptr)
        }

        entity_state_handler(&entity_context, entities, level)

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

        rl.DrawRectangleRec(entities.arr[0].render.rec, player.render.color)

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    when ODIN_DEBUG {
        delete(level.tiles)
        delete(directions)
        delete(entities.arr)
    }
}

// Structs
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

Entity :: struct {
    render : gui.Renderable,
    movement : Entity_Movement,
    index : int,
    actor_type : Actor_Type
}

Entity_Movement :: struct {
    tile_i : int,
    num_moves : int,
    move_speed : f32,
    directions : Direction_Set
}

Entity_List :: struct {
    arr : [dynamic]Entity
}

Entity_State :: enum {
    Idle,
    Move,
    Wait,
    End,
}

Input_Type :: enum {
    Wait,
    Move,
    Idle,
    Invalid
}

Actor_Type :: enum {
    Player,
    AI
}

Actor_Input :: struct {
    type : Actor_Type,
    input : Input_Type,
    key : rl.KeyboardKey
}

Input_List :: struct {
    arr : [dynamic]Actor_Input
}

Entity_Context :: struct {
    input: Actor_Input,
    state : Entity_State,
    entity_i: int,
    remaining_moves : int,
    destination_i : int,
    origin_i : int,
}

Turn_State :: enum {
    Waiting,
    Processing,
    Next
}

Turn_Context :: struct {
    state : Turn_State,
    current_turn : int,
    entity_context : Entity_Context
}

// Procs
entity_state_handler :: proc(entity_context: ^Entity_Context, entities: Entity_List, level: Level) {
    entity_context.origin_i = entities.arr[entity_context.entity_i].movement.tile_i
    // log.info(entity_context.state)
    #partial switch entity_context.state {
        case .Move:
            log.info("Move")
            entity_state_movement(&entities.arr[entity_context.entity_i], entity_context, level)
        case .Wait:

        case .End:

        case .Idle:
            input_processing(entity_context, entities)
    }
}

entity_state_movement :: proc(entity: ^Entity, entity_context: ^Entity_Context, level: Level) {
    key := entity_context.input.key
    
    #partial switch key {
        case .UP, .W:
            if (entity.movement.directions & {.North}) == {.North} {
                entity_context.destination_i = find_next_tile(level, {.North}, entity_context.origin_i)
                entity_move_delta(entity, {.North}, level)
            } else {
                entity_context.state = .Idle
            }
        case .DOWN, .S:
            if (entity.movement.directions & {.South}) == {.South} {
                entity_context.destination_i = find_next_tile(level, {.South}, entity_context.origin_i)
                entity_move_delta(entity, {.South}, level)
            } else {
                entity_context.state = .Idle
            }
        case .LEFT, .A:
            if (entity.movement.directions & {.West}) == {.West} {
                entity_context.destination_i = find_next_tile(level, {.West}, entity_context.origin_i)
                entity_move_delta(entity, {.West}, level)
            } else {
                entity_context.state = .Idle
            }
        case .RIGHT, .D:
            if (entity.movement.directions & {.East}) == {.East} {
                entity_context.destination_i = find_next_tile(level, {.East}, entity_context.origin_i)
                entity_move_delta(entity, {.East}, level)
            } else {
                entity_context.state = .Idle
            }
        case .KEY_NULL, .SPACE:
            entity_context.destination_i = entity_context.origin_i
            entity_context.state = .Idle
    }
}

entity_move_delta :: proc(entity: ^Entity, directions: Direction_Set, level: Level) {
    center : gui.Position
    a : gui.Position = {entity.render.x, entity.render.y}
    b : gui.Position //Center offset
    move_speed := entity.movement.move_speed
    center = gui.find_center_position(level.tiles[entity_context.destination_i].render.rec)
    b = gui.find_center_offset(entity.render.rec, center)
    vector_speed := gui.Position{move_speed, move_speed}
    delta_vector := rl.Vector2{delta_time, delta_time}
    
    switch directions {
        case {.North}:
            vector_speed = (vector_speed * Direction_Vectors[.North]) * delta_vector
            if a.y > b.y {
                entity.render.y += vector_speed.y
                entity_context.state = .Move
            } else {
                entity.render.y = b.y
                entity_context.state = .Idle
                entity.movement.directions = level.tiles[entity_context.destination_i].valid_directions
                entity.movement.tile_i = entity_context.destination_i
                entity_context.origin_i = entity_context.destination_i
            }
        case {.East}:
            vector_speed = (vector_speed * Direction_Vectors[.East]) * delta_vector
            if a.x < b.x {
                entity.render.x += vector_speed.x
                entity_context.state = .Move
            } else {
                entity.render.x = b.x
                entity_context.state = .Idle
                entity.movement.directions = level.tiles[entity_context.destination_i].valid_directions
                entity.movement.tile_i = entity_context.destination_i
                entity_context.origin_i = entity_context.destination_i
            }
        case {.South}:
            vector_speed = (vector_speed * Direction_Vectors[.South]) * delta_vector
            if a.y < b.y {
                entity.render.y += vector_speed.y
                entity_context.state = .Move
            } else {
                entity.render.y = b.y
                entity_context.state = .Idle
                entity.movement.directions = level.tiles[entity_context.destination_i].valid_directions
                entity.movement.tile_i = entity_context.destination_i
                entity_context.origin_i = entity_context.destination_i
            }
        case {.West}:
            vector_speed = (vector_speed * Direction_Vectors[.West]) * delta_vector
            if a.x > b.x {
                entity.render.x += vector_speed.x
                entity_context.state = .Move
            } else {
                entity.render.y = b.y
                entity_context.state = .Idle
                entity.movement.directions = level.tiles[entity_context.destination_i].valid_directions
                entity.movement.tile_i = entity_context.destination_i
                entity_context.origin_i = entity_context.destination_i
            }
    }
}

input_processing :: proc(entity_context: ^Entity_Context, entities: Entity_List) {
    e := entities.arr[entity_context.entity_i]
    input : Actor_Input
    if e.actor_type == .Player {
        input = player_input(entity_context^, e)
        // log.info("Player Input")
    }
    entity_context.input = input
    determine_entity_state(input, entity_context)
}

player_input :: proc(entity_context: Entity_Context, e: Entity) -> (input: Actor_Input) {
    input.type = .Player
    if entity_context.state == .Idle {
        input.key = rl.GetKeyPressed()
        #partial switch input.key {
            case .UP, .DOWN, .LEFT, .RIGHT, .W, .A, .S, .D:
                input.input = .Move
                log.info("Move")
            case .SPACE:
                input.input = .Wait
            case .KEY_NULL:
                input.input = .Invalid
        }
    } else {
        input.input = .Invalid
    }
    return input
}

determine_entity_state :: proc(input: Actor_Input, entity_context: ^Entity_Context) {
    switch input.input {
        case .Wait:
            entity_context.state = .Wait
        case .Move:
            entity_context.state = .Move
        case .Idle, .Invalid:
            entity_context.state = .Idle
    }
}

reset_entity_context :: proc(entity_i: int, entity_context: ^Entity_Context, entities: Entity_List) {
    entity := entities.arr[entity_i]
    entity_context.input = Actor_Input{entity.actor_type, .Idle, .KEY_NULL}
    entity_context.state = .Idle
    entity_context.remaining_moves = entity.movement.num_moves
    entity_context.destination_i = -1
    entity_context.origin_i = entity.movement.tile_i
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

find_and_move :: proc(level: Level, e: ^Entity, direction: Direction_Set) {
    next_tile_i : int
    next_tile_i = find_next_tile(level, direction, e.movement.tile_i)
    next_tile := level.tiles[next_tile_i]
    move_to_tile(e, next_tile)
    e.movement.tile_i = next_tile_i
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