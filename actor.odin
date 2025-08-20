package main

import rl "vendor:raylib"
import "core:log"

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

entity_input :: proc(entity_context: Entity_Context, entities: Entity_List, level: Level) -> (input: Actor_Input) {
    entity := entities.arr[entity_context.entity_i]
    player := entities.arr[entities.player_i]
    input.type = entity.actor_type
    if entity_context.state == .Idle {
        if input.type == .Player {
            input.key = rl.GetKeyPressed()
        }
        else if input.type == .AI {
            input.key = ai_decide_move(entity, player, level)
        }
        #partial switch input.key {
            case .UP, .DOWN, .LEFT, .RIGHT, .W, .A, .S, .D:
                input.input = .Move
                log.info("Key:", input.key, "State:", input.input)
            case .SPACE:
                input.input = .Wait
                log.info("Key:", input.key, "State:", input.input)
            case .KEY_NULL:
                input.input = .Idle
            case:
                input.input = .Idle
        }
    } else {
        input.input = .Idle
    }
    return input
}

ai_decide_move :: proc(entity, player: Entity, level: Level) -> (rl.KeyboardKey) {
    pref := entity.move_pref
    key : rl.KeyboardKey = .SPACE
    directions := entity.movement.directions
    num_column := level.num_columns
    player_tile_pos := find_v2_from_tile_index(player.movement.tile_i, num_column)
    entity_tile_pos := find_v2_from_tile_index(entity.movement.tile_i, num_column)
    distance := player_tile_pos - entity_tile_pos

    loop: for i := 0; i < entity.movement.num_moves; i += 1 {
        #partial switch pref {
        case .Horizontal:
            if distance.x < 0 && directions & {.West} == {.West} {
                key = .LEFT
                break loop
            }
            else if distance.x > 0 && directions & {.East} == {.East} {
                key = .RIGHT
                break loop
            } else {
                pref = .Vertical
            }
        case .Vertical:
            if distance.y < 0 && directions & {.North} == {.North} {
                key = .UP
                break loop
            }
            else if distance.y > 0 && directions & {.South} == {.South} {
                key = .DOWN
                break loop
            } else {
                pref = .Horizontal
            }
        }
    }
    return key
}