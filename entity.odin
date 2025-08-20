package main

import "core:log"
import "gui"
import "core:math"
import rl "vendor:raylib"

Id :: struct {
    value : int
}

Entity :: struct {
    render : gui.Renderable,
    movement : Entity_Movement,
    actor_type : Actor_Type,
    entity_type : Entity_Type,
    move_pref : Move_Pref,
    id : Id,
    attack : int,
    index : int,
}

Entity_Movement :: struct {
    tile_i : int,
    num_moves : int,
    move_speed : f32,
    directions : Direction_Set
}

Entity_List :: struct {
    player_i : int,
    generation : int,
    arr : [dynamic]Entity
}

Entity_Type :: enum {
    Explorer,
    White_Mummy,
    Red_Mummy,
    Scorpion
}

Move_Pref :: enum {
    None,
    Horizontal,
    Vertical
}

find_entity_same_tile :: proc(entity: Entity, entities: Entity_List) -> (defender_i: int) {
    tile_i := entity.movement.tile_i
    for i in 0..<len(entities.arr) {
        if entities.arr[i].movement.tile_i == tile_i && i != entity.index{
            return i
        }
    }
    return -1
}

entity_combat :: proc(attacker_i, defender_i : int, entities : Entity_List) -> (winner: bool) {
    attacker := entities.arr[attacker_i]
    defender := entities.arr[defender_i]
    if attacker.attack >= defender.attack {
        return true
    }
    return false
}

insert_entity_into_list :: proc(entity: Entity, entities: ^Entity_List) {
    entities.generation += 1
    append(&entities.arr, entity)
    index := len(entities.arr)-1
    entities.arr[index].index = index
    entities.arr[index].id.value = entities.generation
}

remove_entity_from_list :: proc(entity_i: int, entities: ^Entity_List) {
    ordered_remove(&entities.arr, entity_i)
    for i in 0..<len(entities.arr) {
        entities.arr[i].index = i
    }
}

entity_move_delta :: proc(entity: ^Entity, directions: Direction_Set, level: Level) -> (reached: bool) {
    center : gui.Position
    e_pos : gui.Position = {entity.render.x, entity.render.y}
    target_pos : gui.Position //Center offset
    move_speed := entity.movement.move_speed
    center = gui.find_center_position(level.tiles[turn_context.entity_context.destination_i].render.rec)
    target_pos = gui.find_center_offset(entity.render.rec, center)
    distance := target_pos - e_pos
    distance = {math.abs(distance.x), math.abs(distance.y)}
    vector_speed := gui.Position{move_speed, move_speed}
    delta_vector := rl.Vector2{delta_time, delta_time}
    
    switch directions {
        case {.North}:
            vector_speed = (vector_speed * Direction_Vectors[.North]) * delta_vector
        case {.East}:
            vector_speed = (vector_speed * Direction_Vectors[.East]) * delta_vector
        case {.South}:
            vector_speed = (vector_speed * Direction_Vectors[.South]) * delta_vector
        case {.West}:
            vector_speed = (vector_speed * Direction_Vectors[.West]) * delta_vector
    }

    e_pos += vector_speed
    entity.render.x, entity.render.y = e_pos.x, e_pos.y
    distance -= {math.abs(vector_speed.x), math.abs(vector_speed.y)}
    
    if distance.x <= 0 && distance.y <= 0 {
        entity.render.x, entity.render.y = target_pos.x, target_pos.y
         return true
    }
    return false
}

find_and_move :: proc(level: Level, e: ^Entity, direction: Direction_Set) {
    next_tile_i : int
    next_tile_i = find_next_tile(level, direction, e.movement.tile_i)
    next_tile := level.tiles[next_tile_i]
    move_to_tile(e, next_tile)
    e.movement.tile_i = next_tile_i
}