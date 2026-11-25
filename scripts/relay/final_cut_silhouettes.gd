extends RefCounted
## Twelve 1-bit cuts of the same figure, in assembly coordinates.
## Head (with the player's brim), chest, upper arms, forearms, hands, thighs, shins.
const CUTS := [
	[Vector2(81, 45), Vector2(82, 24), Vector2(94, 8), Vector2(111, 4), Vector2(131, 10), Vector2(142, 29), Vector2(143, 44), Vector2(166, 49), Vector2(163, 56), Vector2(140, 58), Vector2(135, 83), Vector2(124, 96), Vector2(101, 93), Vector2(88, 80), Vector2(86, 59), Vector2(57, 56), Vector2(55, 50)],
	[Vector2(94, 96), Vector2(126, 99), Vector2(151, 103), Vector2(156, 169), Vector2(145, 212), Vector2(149, 240), Vector2(113, 257), Vector2(71, 241), Vector2(72, 206), Vector2(64, 165), Vector2(69, 111)],
	[Vector2(65, 110), Vector2(47, 118), Vector2(32, 155), Vector2(24, 185), Vector2(51, 196), Vector2(67, 165)],
	[Vector2(155, 103), Vector2(176, 118), Vector2(191, 148), Vector2(197, 183), Vector2(170, 193), Vector2(160, 169)],
	[Vector2(23, 189), Vector2(49, 200), Vector2(37, 246), Vector2(15, 240), Vector2(14, 222)],
	[Vector2(171, 197), Vector2(198, 187), Vector2(205, 233), Vector2(188, 246), Vector2(177, 229)],
	[Vector2(14, 244), Vector2(36, 250), Vector2(31, 271), Vector2(23, 280), Vector2(10, 273), Vector2(7, 258)],
	[Vector2(189, 250), Vector2(205, 238), Vector2(215, 254), Vector2(216, 270), Vector2(204, 277), Vector2(194, 268)],
	[Vector2(70, 245), Vector2(109, 260), Vector2(104, 289), Vector2(94, 331), Vector2(62, 330), Vector2(61, 293)],
	[Vector2(115, 261), Vector2(149, 245), Vector2(157, 282), Vector2(161, 327), Vector2(129, 334), Vector2(116, 292)],
	[Vector2(62, 334), Vector2(93, 335), Vector2(88, 376), Vector2(80, 410), Vector2(49, 410), Vector2(45, 401), Vector2(56, 377)],
	[Vector2(130, 338), Vector2(162, 331), Vector2(169, 382), Vector2(181, 402), Vector2(176, 412), Vector2(143, 412), Vector2(133, 378)],
]


static func make() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for cut: Array in CUTS:
		var bounds := Rect2(cut[0], Vector2.ZERO)
		for point: Vector2 in cut:
			bounds = bounds.expand(point)
		var polygon := PackedVector2Array(cut)
		var image := Image.create(int(bounds.size.x) + 1, int(bounds.size.y) + 1, false, Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				if Geometry2D.is_point_in_polygon(bounds.position + Vector2(x + 0.5, y + 0.5), polygon):
					image.set_pixel(x, y, Color.WHITE)
		pieces.append({"offset": bounds.position, "texture": ImageTexture.create_from_image(image)})
	return pieces
