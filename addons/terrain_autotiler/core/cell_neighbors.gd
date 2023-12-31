@tool
extends Object

const DEFAULT_OFFSET_AXIS := TileSet.TILE_OFFSET_AXIS_HORIZONTAL



const CellNeighbors := {
	TileSet.TILE_SHAPE_SQUARE : {
		DEFAULT_OFFSET_AXIS: [
			TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_TOP_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		],
	},
	TileSet.TILE_SHAPE_ISOMETRIC : {
		DEFAULT_OFFSET_AXIS: [
			TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_CORNER,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
		],
	},
	TileSet.TILE_SHAPE_HEXAGON : {
		TileSet.TILE_OFFSET_AXIS_HORIZONTAL : [
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
		],
		TileSet.TILE_OFFSET_AXIS_VERTICAL : [
			TileSet.CELL_NEIGHBOR_TOP_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
		],
	},
}

# TODO: figure out minimum counts for hex tiles
# these are one less than the common number due to the way they are
# calculated in TerrainsData
const FullSetPatternCounts := {
	TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
		Autotiler.MatchMode.MINIMAL: 46,
		Autotiler.MatchMode.FULL: 255,
	},
	TileSet.TERRAIN_MODE_MATCH_CORNERS: {
		Autotiler._DEFAULT_MATCH_MODE: 15,
	},
	TileSet.TERRAIN_MODE_MATCH_SIDES: {
		Autotiler._DEFAULT_MATCH_MODE: 15,
	},
}


const PeeringBitCellNeighbors := {
	TileSet.TILE_SHAPE_SQUARE : {
		DEFAULT_OFFSET_AXIS: {
			TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
				Autotiler.MatchMode.MINIMAL: {
					# Peering bit
					TileSet.CELL_NEIGHBOR_RIGHT_SIDE: {
						# Neighbor cell : Neighbor peering bit
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE : TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER : TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_SIDE : TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
				},
				Autotiler.MatchMode.FULL: {
					TileSet.CELL_NEIGHBOR_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER : TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_CORNERS: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE : TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER : TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_SIDE : TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_SIDE,
					},
					TileSet.CELL_NEIGHBOR_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
					},
				},
			},
		},
	},
	TileSet.TILE_SHAPE_ISOMETRIC: {
		DEFAULT_OFFSET_AXIS: {
			TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
				Autotiler.MatchMode.MINIMAL: {
					TileSet.CELL_NEIGHBOR_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_LEFT_CORNER: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
				Autotiler.MatchMode.FULL: {
					TileSet.CELL_NEIGHBOR_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: TileSet.CELL_NEIGHBOR_TOP_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_CORNER: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_CORNERS: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_CORNER: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_LEFT_CORNER: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_CORNER: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
			},
		},
	},
	TileSet.TILE_SHAPE_HEXAGON: {
		TileSet.TILE_OFFSET_AXIS_HORIZONTAL: {
			TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_CORNERS: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_CORNER,
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
			},
		},
		TileSet.TILE_OFFSET_AXIS_VERTICAL: {
			TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_CORNERS: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_LEFT_CORNER,
					},
				},
			},
			TileSet.TERRAIN_MODE_MATCH_SIDES: {
				Autotiler._DEFAULT_MATCH_MODE: {
					TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileSet.CELL_NEIGHBOR_TOP_SIDE,
					},
					TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
					},
					TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: {
						TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
					},
				},
			},
		},
	},
}


const CellNeighborsTexts := {
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE: "RIGHT_SIDE",
	TileSet.CELL_NEIGHBOR_RIGHT_CORNER: "RIGHT_CORNER",
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: "BOTTOM_RIGHT_SIDE",
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: "BOTTOM_RIGHT_CORNER",
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: "BOTTOM_SIDE",
	TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: "BOTTOM_CORNER",
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: "BOTTOM_LEFT_SIDE",
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: "BOTTOM_LEFT_CORNER",
	TileSet.CELL_NEIGHBOR_LEFT_SIDE: "LEFT_SIDE",
	TileSet.CELL_NEIGHBOR_LEFT_CORNER: "LEFT_CORNER",
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: "TOP_LEFT_SIDE",
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: "TOP_LEFT_CORNER",
	TileSet.CELL_NEIGHBOR_TOP_SIDE: "TOP_SIDE",
	TileSet.CELL_NEIGHBOR_TOP_CORNER: "TOP_CORNER",
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: "TOP_RIGHT_SIDE",
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: "TOP_RIGHT_CORNER",
}



var tile_shape : TileSet.TileShape
var tile_offset_axis : TileSet.TileOffsetAxis
var terrain_mode : TileSet.TerrainMode
var match_mode : Autotiler.MatchMode


# NEIGHBOR ITERATORS
# To iterate cell neighbors:
#for neighbor in cn.get_cell_neighbors():
#	var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)

# To iterate peering bit neighbors:
#for bit in cn.get_peering_bits():
#	for neighbor in cn.get_peering_bit_cell_neighbors(bit):
#		var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)
#		var neighbor_bit := cn.get_peering_bit_cell_neighbor_peering_bit(bit, neighbor)


func _init(p_tile_shape : TileSet.TileShape, p_terrain_mode : TileSet.TerrainMode, p_match_mode := Autotiler._DEFAULT_MATCH_MODE, p_tile_offset_axis := DEFAULT_OFFSET_AXIS) -> void:
	tile_shape = p_tile_shape
	terrain_mode = p_terrain_mode

	# TileSets may have irrelevant settings that are not consistent,
	# so populate with defaults when not relevant
	if p_terrain_mode == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
		match_mode = p_match_mode
	else:
		match_mode = Autotiler._DEFAULT_MATCH_MODE

	if p_tile_shape == TileSet.TILE_SHAPE_HEXAGON:
		tile_offset_axis = p_tile_offset_axis
	else:
		tile_offset_axis = DEFAULT_OFFSET_AXIS


func get_full_set_pattern_count() -> int:
	return FullSetPatternCounts[terrain_mode][match_mode]


func get_cell_neighbors() -> Array:
	return CellNeighbors[tile_shape][tile_offset_axis].duplicate()


func get_peering_bits() -> Array:
	return PeeringBitCellNeighbors[tile_shape][tile_offset_axis][terrain_mode][match_mode].keys()


func get_peering_bit_at_index(p_index : int) -> TileSet.CellNeighbor:
	return get_peering_bits()[p_index]


func get_all_peering_bit_cell_neighbors() -> Array:
	var neighbors := {} # dictionary used as set
	for bit in get_peering_bits():
		for neighbor in get_peering_bit_cell_neighbors(bit):
			neighbors[neighbor] = true
	return neighbors.keys()


func get_peering_bit_cell_neighbors(p_bit : TileSet.CellNeighbor) -> Array:
	return PeeringBitCellNeighbors[tile_shape][tile_offset_axis][terrain_mode][match_mode][p_bit].keys()


# this function name is insane, but for the sake of clarity/consistency
func get_peering_bit_cell_neighbor_peering_bit(p_bit : TileSet.CellNeighbor, p_neighbor : TileSet.CellNeighbor) -> TileSet.CellNeighbor:
	return PeeringBitCellNeighbors[tile_shape][tile_offset_axis][terrain_mode][match_mode][p_bit][p_neighbor]


func get_neighbor_overlapping_bits(p_neighbor : TileSet.CellNeighbor) -> Array:
	var neighbor_overlapping_bits := []
	for bit in get_peering_bits():
		for neighbor in get_peering_bit_cell_neighbors(bit):
			if neighbor != p_neighbor:
				continue
			neighbor_overlapping_bits.append(get_peering_bit_cell_neighbor_peering_bit(bit, neighbor))
	return neighbor_overlapping_bits



# -----------------------------
# 	STATIC FUNCTIONS
# -----------------------------

static func get_text(p_neighbor : TileSet.CellNeighbor) -> String:
	return CellNeighborsTexts[p_neighbor]


static func is_tile_shape_supported(p_tile_shape : TileSet.TileShape) -> bool:
	return CellNeighbors.has(p_tile_shape)
