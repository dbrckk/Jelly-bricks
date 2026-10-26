extends RefCounted
## Twenty deterministic 6x6 Jelly sculpture silhouettes.
## R=red B=blue G=green Y=yellow O=orange; dot=empty.
## The second layer adds 3D eyes, ears and relief for advanced challenges.
## Each solution uses existing 1/2/3-cell Studio pieces and the same support
## rules. Players match the COLORED VOXELS, never a prescribed brick order.
const GRID := 6
const COLOR_CODES := {"R": 0, "B": 1, "G": 2, "Y": 3, "O": 4}
const RAW := [
    ["Cœur",1,"forme",["..RR..", ".RRRR.", "RRRRRR", "RRRRRR", ".RRRR.", "..RR.."], []],
    ["Flèche",1,"forme",["..Y...", "...Y..", "YYYYYY", "...Y..", "..Y...", "......"], []],
    ["Fleur",1,"nature",["..OO..", ".OOOO.", "OORROO", ".ORRO.", "..GG..", "..GG.."], []],
    ["Étoile",2,"forme",["..Y...", "..YY..", "YYYYYY", ".YYYY.", "..YY..", ".Y..Y."], []],
    ["Poisson",2,"animal",[".B...B", "BB.BBB", "BBBBBO", "BBBBBB", ".BBBB.", "..B.B."], []],
    ["Papillon",2,"animal",["RR..BB", "RRR.BB", ".RRBB.", "..GG..", ".O..O.", "O....O"], []],
    ["Tortue",2,"animal",["..G...", "GGGGG.", "GGRGGG", "GGGGGG", ".GGGG.", "..G..."], []],
    ["Canard",2,"animal",[".YYYY.", "YYYYOO", "YYBYYY", "YYYYY.", ".YYY..", "..O..."], []],
    ["Lapin",3,"animal",[".R..R.", ".R..R.", ".OOOO.", "OYYYYO", "OYOYYO", ".OOOO."], ["......", "......", "..YY..", "......", "......", "......"]],
    ["Grenouille",3,"animal",["GG..GG", "GGGGGG", "GGYGYG", "GGGGGG", ".GGGG.", "G....G"], ["G....G", "......", "......", "......", "......", "......"]],
    ["Crabe",3,"animal",["RR..RR", "R.RR.R", ".RRRR.", "RRYYRR", ".RRRR.", "R....R"], ["......", "..RR..", "......", "......", "......", "......"]],
    ["Chat",3,"animal",["O....O", "OO..OO", "OOOOOO", "OYOOYO", "OOOROO", ".OOOO."], ["......", "......", "......", "......", "......", "..O..."]],
    ["Hibou",3,"animal",[".OO.O.", "OOOOOO", "OYOYOY", "OOOOOO", ".OOOO.", "..OO.."], ["......", "......", ".Y.Y..", "......", "......", "......"]],
    ["Pingouin",3,"animal",[".BBBB.", "BBBBBB", "BYBBYB", "BBYYBB", ".BBBB.", "..B.B."], ["......", "......", "......", "..YY..", "......", "......"]],
    ["Renard",4,"animal",["O....O", "OO..OO", "OOOOOO", "OYOOYO", ".OOOO.", "..RR.."], ["O....O", "......", "......", "......", "......", "......"]],
    ["Ours",4,"animal",["OO..OO", "OOOOOO", "OYOOYO", "OOOOOO", ".ORRO.", "..OO.."], ["......", "......", "......", "..RR..", "......", "......"]],
    ["Éléphant",4,"animal",["BB..BB", "BBBBBB", "BYBBYB", "BBBBBB", ".BBBB.", "..BB.."], ["......", "......", "......", "..BB..", "..BB..", "..B..."]],
    ["Fusée",4,"objet",["..R...", "..RR..", ".RYYR.", ".RYYR.", "OBYYBO", "O....O"], ["......", "..R...", "..YY..", "..YY..", "......", "......"]],
    ["Château",5,"objet",["R.R.R.", "RRRRR.", "RYYYYR", "RYYYYR", "RRBBRR", "RRBBRR"], ["R.R.R.", "......", "......", "......", "..BB..", "..BB.."]],
    ["Dragon",5,"animal",["G....G", "GG..GG", ".GGGG.", "GGYGGG", ".GGGG.", "G.G.G."], ["G....G", "......", "..Y...", "......", "..G...", "......"]]
]

static func key(row: int, col: int, layer: int) -> String:
    return "%d:%d:%d" % [row, col, layer]

static func catalog() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(RAW.size()):
        var spec: Array = RAW[i]
        var layers: Array = [spec[3]]
        if not spec[4].is_empty():
            layers.append(spec[4])
        var target: Dictionary = {}
        var bricks: Array[Dictionary] = []
        for height in range(layers.size()):
            var plane: Array = layers[height]
            if plane.size() != GRID:
                push_error("Invalid Jelly challenge grid height: %d" % i)
                return []
            for row in range(GRID):
                var line: String = plane[row]
                if line.length() != GRID:
                    push_error("Invalid Jelly challenge grid width: %d" % i)
                    return []
                var col := 0
                while col < GRID:
                    var symbol: String = line.substr(col, 1)
                    if symbol == ".":
                        col += 1
                        continue
                    if not COLOR_CODES.has(symbol):
                        push_error("Unknown challenge pigment: " + symbol)
                        return []
                    var start: int = col
                    while col < GRID and line.substr(col, 1) == symbol \
                            and col - start < 3:
                        var position_key: String = key(row, col, height)
                        if height > 0 and not target.has(
                                key(row, col, height - 1)):
                            push_error("Floating sculpture voxel in level %d" % (i + 1))
                            return []
                        target[position_key] = COLOR_CODES[symbol]
                        col += 1
                    bricks.append({
                        "row": row, "col": start, "length": col - start - 1,
                        "turns": 0, "color": COLOR_CODES[symbol], "layer": height
                    })
        if bricks.size() > 32 or bricks.is_empty():
            push_error("Invalid sculpture brick budget for level %d" % (i + 1))
            return []
        result.append({
            "id": i, "title": spec[0], "difficulty": spec[1],
            "category": spec[2], "layers": layers, "cells": target,
            "required": target.size(), "demo": bricks,
            "par_bricks": bricks.size(), "max_layer": layers.size() - 1
        })
    return result
