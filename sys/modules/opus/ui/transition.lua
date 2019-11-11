local Tween  = require('opus.ui.tween')

local Transition = { }

function Transition.slideLeft(args)
	local ticks      = args.ticks or 10
	local easing     = args.easing or 'outQuint'
	local pos        = { x = args.ex }
	local tween      = Tween.new(ticks, pos, { x = args.x }, easing)

	args.canvas:move(pos.x, args.canvas.y)

	return function()
		local finished = tween:update(1)
		args.canvas:move(math.floor(pos.x), args.canvas.y)
		args.canvas:dirty()
		return not finished
	end
end

function Transition.slideRight(args)
	local ticks      = args.ticks or 10
	local easing     = args.easing or'outQuint'
	local pos        = { x = -args.canvas.width }
	local tween      = Tween.new(ticks, pos, { x = 1 }, easing)

	args.canvas:move(pos.x, args.canvas.y)

	return function()
		local finished = tween:update(1)
		args.canvas:move(math.floor(pos.x), args.canvas.y)
		args.canvas:dirty()
		return not finished
	end
end

function Transition.expandUp(args)
	local ticks  = args.ticks or 3
	local easing = args.easing or 'linear'
	local pos    = { y = args.ey + 1 }
	local tween  = Tween.new(ticks, pos, { y = args.y }, easing)

	args.canvas:move(args.x, pos.y)

	return function()
		local finished = tween:update(1)
		args.canvas:move(args.x, math.floor(pos.y))
		args.canvas:dirty()
		return not finished
	end
end

return Transition
