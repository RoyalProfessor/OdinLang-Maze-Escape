package main

import "core:log"

Entity_State :: enum {
    Idle,
    Move,
    Wait,
    End,
    Battle,
    Decrement_Move,
    Death,
}

Entity_Context :: struct {
    input: Actor_Input,
    state : Entity_State,
    entity_i: int,
    remaining_moves : int,
    destination_i : int,
    origin_i : int,
}

entity_state_handler :: proc(turn_context: ^Turn_Context, entities: ^Entity_List, level: Level) {
    #partial switch turn_context.entity_context.state {
        case .Move:
            // log.info("Entity Move")
            entity_state_movement(&entities.arr[turn_context.entity_context.entity_i], &turn_context.entity_context, level)
        case .Wait:
            log.info("Entity Wait")
            entity_state_wait(&turn_context.entity_context)
        case .End:
            log.info("Entity End")
            turn_context.state = .Next
        case .Idle:
            log.info("Entity Idle")
            turn_context.entity_context.input.input = .Idle
            turn_context.state = .Input
        case .Battle:
            log.info("Entity Battle")
            entity_state_battle(entities.arr[turn_context.current_turn], &turn_context.entity_context, entities)
        case .Decrement_Move:
            turn_context.entity_context.remaining_moves -= 1
            if turn_context.entity_context.remaining_moves == 0 {
                turn_context.entity_context.state = .End
            } else {
                turn_context.entity_context.state = .Idle
            }
        case .Death:
            entity_state_death(turn_context, entities)
            turn_context.state = .Next
    }
}

entity_state_movement :: proc(entity: ^Entity, entity_context: ^Entity_Context, level: Level) {
    key := entity_context.input.key
    reached : bool
    entity_context.state = .Move
    #partial switch key {
        case .UP, .W:
            log.info("Entity Move Up")
            if (entity.movement.directions & {.North}) == {.North} {
                entity_context.destination_i = find_next_tile(level, {.North}, entity_context.origin_i)
                reached = entity_move_delta(entity, {.North}, level)
            } else {
                entity_context.input.key = .KEY_NULL
                entity_context.state = .Idle
            }
        case .DOWN, .S:
            log.info("Entity Move Down")
            if (entity.movement.directions & {.South}) == {.South} {
                entity_context.destination_i = find_next_tile(level, {.South}, entity_context.origin_i)
                reached = entity_move_delta(entity, {.South}, level)
            } else {
                entity_context.state = .Idle
                entity_context.input.key = .KEY_NULL
            }
        case .LEFT, .A:
            log.info("Entity Move Left")
            if (entity.movement.directions & {.West}) == {.West} {
                entity_context.destination_i = find_next_tile(level, {.West}, entity_context.origin_i)
                reached = entity_move_delta(entity, {.West}, level)
            } else {
                entity_context.state = .Idle
                entity_context.input.key = .KEY_NULL
            }
        case .RIGHT, .D:
            log.info("Entity Move Right")
            if (entity.movement.directions & {.East}) == {.East} {
                entity_context.destination_i = find_next_tile(level, {.East}, entity_context.origin_i)
                reached = entity_move_delta(entity,{.East}, level)
            } else {
                entity_context.state = .Idle
                entity_context.input.key = .KEY_NULL
            }
    }
    if reached {
        entity.movement.directions = level.tiles[entity_context.destination_i].valid_directions
        entity.movement.tile_i = entity_context.destination_i
        entity_context.origin_i = entity_context.destination_i 
        if find_entity_same_tile(entity^, entities) != -1 {
            entity_context.state = .Battle
        } else {
            entity_context.state = .Decrement_Move
        }
    }
}

entity_state_battle :: proc(entity: Entity, entity_context: ^Entity_Context, entities: ^Entity_List) {
    found : bool
    defender_i := find_entity_same_tile(entity, entities^)
    log.info("Defender i:", defender_i)
    if entity_combat(entity.index, defender_i, entities^) {
        entity_context.state = .Decrement_Move
        log.info("Killed:", entities.arr[defender_i])
        remove_entity_from_list(defender_i, entities)
        for i in 0..<len(entities.arr) {
            if entities.arr[i].id.value == entity.id.value {
                entity_context.entity_i = i
            }
        }
    } else {
        entity_context.state = .Death
    }
}

entity_state_wait :: proc(entity_context: ^Entity_Context) {
    log.info("Entity Wait Idle")
    entity_context.destination_i = entity_context.origin_i
    entity_context.state = .End
}

entity_state_death :: proc(turn_context: ^Turn_Context, entities: ^Entity_List) {
    entity_context := &turn_context.entity_context
    remove_entity_from_list(turn_context.current_turn, entities)
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
    entity_context.entity_i = entity_i
    entity_context.remaining_moves = entity.movement.num_moves
    entity_context.destination_i = -1
    entity_context.origin_i = entity.movement.tile_i
}

