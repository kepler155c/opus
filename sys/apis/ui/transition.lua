local Tween  = require('ui.tween')

local Transition = { }

function Transition.slideLeft(args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or 'outQuint'
	local pos        = { x = args.ex }
	local tween      = Tween.new(ticks, pos, { x = args.x }, easing)
	local lastScreen = args.canvas:copy()

	return function(device)
		local finished = tween:update(1)
		local x = math.floor(pos.x)
		lastScreen:dirty()
		lastScreen:blit(device, {
			x = args.ex - x + args.x,
			y = args.y,
			ex = args.ex,
			ey = args.ey },
			{ x = args.x, y = args.y })
		args.canvas:blit(device, {
			x = args.x,
			y = args.y,
			ex = args.ex - x + args.x,
			ey = args.ey },
			{ x = x, y = args.y })
		return not finished
	end
end

function Transition.slideRight(args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or'outQuint'
	local pos        = { x = args.x }
	local tween      = Tween.new(ticks, pos, { x = args.ex }, easing)
	local lastScreen = args.canvas:copy()

	return function(device)
		local finished = tween:update(1)
		local x = math.floor(pos.x)
		lastScreen:dirty()
		lastScreen:blit(device, {
			x = args.x,
			y = args.y,
			ex = args.ex - x + args.x,
			ey = args.ey },
			{ x = x, y = args.y })
		args.canvas:blit(device, {
			x = args.ex - x + args.x,
			y = args.y,
			ex = args.ex,
			ey = args.ey },
			{ x = args.x, y = args.y })
		return not finished
	end
end

function Transition.expandUp(args)
	local ticks  = args.ticks or 3
	local easing = args.easing or 'linear'
	local pos    = { y = args.ey + 1 }
	local tween  = Tween.new(ticks, pos, { y = args.y }, easing)

	return function(device)
		local finished = tween:update(1)
		args.canvas:blit(device, nil, { x = args.x, y = math.floor(pos.y) })
		return not finished
	end
end

function Transition.grow(args)
	local ticks  = args.ticks or 3
	local easing = args.easing or 'linear'
	local tween  = Tween.new(ticks,
		{ x = args.width / 2 - 1, y = args.height / 2 - 1, w = 1, h = 1 },
		{ x = 1, y = 1, w = args.width, h = args.height }, easing)

	return function(device)
		local finished = tween:update(1)
		local subj = tween.subject
		local rect = { x = math.floor(subj.x), y = math.floor(subj.y) }
		rect.ex = math.floor(rect.x + subj.w - 1)
		rect.ey = math.floor(rect.y + subj.h - 1)
		args.canvas:blit(device, rect, { x = args.x + rect.x - 1, y = args.y + rect.y - 1})
		return not finished
	end
end

return Transition
