package main

import "core:log"

Turn_State :: enum {
    Input,
    Processing,
    Next,
    Death
}

Turn_Context :: struct {
    state : Turn_State,
    current_turn : int,
    entity_context : Entity_Context
}

turn_state_handler :: proc(turn_context: ^Turn_Context, entities: ^Entity_List, level: Level) {
    #partial switch turn_context.state {
        case .Input:
            // log.info("Input")
            log.info(turn_context.entity_context)
            input_processing(&turn_context.entity_context, entities^, level)
            if turn_context.entity_context.state == .Idle {
                // log.info("Input Input")
                turn_context.state = .Input
            } else {
                log.info("Input Processing")
                turn_context.state = .Processing
            }
        case .Processing:
            // log.info("Turn Processing")
            entity_state_handler(turn_context, entities, level)
        case .Next:
            log.info("Turn Next")
            turn_state_next(turn_context, entities^)
    }
}

turn_state_next :: proc(turn_context: ^Turn_Context, entities: Entity_List) {
    turn_context.state = .Input
    if turn_context.current_turn < len(entities.arr)-1 {
        turn_context.current_turn += 1
    } else {
        turn_context.current_turn = 0
    }
    reset_entity_context(turn_context.current_turn, &turn_context.entity_context, entities)
    log.info("Current Turn:", turn_context.current_turn)
}

input_processing :: proc(entity_context: ^Entity_Context, entities: Entity_List, level: Level) {
    e := entities.arr[entity_context.entity_i]
    player := entities.arr[entities.player_i]
    input := entity_input(entity_context^, entities, level)
    entity_context.input = input
    determine_entity_state(input, entity_context)
}

