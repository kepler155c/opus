local Tween  = require('opus.ui.tween')

local Transition = { }

function Transition.slideLeft(args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or 'inCirc'
	local pos        = { x = args.ex }
	local tween      = Tween.new(ticks, pos, { x = args.x }, easing)

	args.canvas:move(pos.x, args.canvas.y)

	return function()
		local finished = tween:update(1)
		args.canvas:move(math.floor(pos.x), args.canvas.y)
		args.canvas:dirty(true)
		return not finished
	end
end

function Transition.slideRight(args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or 'inCirc'
	local pos        = { x = -args.canvas.width }
	local tween      = Tween.new(ticks, pos, { x = 1 }, easing)

	args.canvas:move(pos.x, args.canvas.y)

	return function()
		local finished = tween:update(1)
		args.canvas:move(math.floor(pos.x), args.canvas.y)
		args.canvas:dirty(true)
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
		args.canvas.parent:dirty(true)
		return not finished
	end
end

function Transition.shake(args)
	local ticks  = args.ticks or 8
	local i = ticks

	return function()
		i = -i
		args.canvas:move(args.canvas.x + i, args.canvas.y)
		if i > 0 then
			i = i - 2
		end
		return i ~= 0
	end
end

function Transition.shuffle(args)
	local ticks  = args.ticks or 4
	local easing = args.easing or 'linear'
	local t = { }

	for _,child in pairs(args.canvas.children) do
		t[child] = Tween.new(ticks, child, { x = child.x, y = child.y }, easing)
		child.x = math.random(1, args.canvas.parent.width)
		child.y = math.random(1, args.canvas.parent.height)
	end

	return function()
		local finished
		for child, tween in pairs(t) do
			finished = tween:update(1)
			child:move(math.floor(child.x), math.floor(child.y))
		end
		return not finished
	end
end

return Transition
