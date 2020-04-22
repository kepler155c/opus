local Tween  = require('opus.ui.tween')

local Transition = { }

function Transition.slideLeft(canvas, args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or 'inCirc'
	local pos        = { x = canvas.ex }
	local tween      = Tween.new(ticks, pos, { x = canvas.x }, easing)

	canvas:move(pos.x, canvas.y)

	return function()
		local finished = tween:update(1)
		canvas:move(math.floor(pos.x), canvas.y)
		canvas:dirty(true)
		return not finished
	end
end

function Transition.slideRight(canvas, args)
	local ticks      = args.ticks or 6
	local easing     = args.easing or 'inCirc'
	local pos        = { x = -canvas.width }
	local tween      = Tween.new(ticks, pos, { x = 1 }, easing)

	canvas:move(pos.x, canvas.y)

	return function()
		local finished = tween:update(1)
		canvas:move(math.floor(pos.x), canvas.y)
		canvas:dirty(true)
		return not finished
	end
end

function Transition.expandUp(canvas, args)
	local ticks  = args.ticks or 3
	local easing = args.easing or 'linear'
	local pos    = { y = canvas.ey + 1 }
	local tween  = Tween.new(ticks, pos, { y = canvas.y }, easing)

	canvas:move(canvas.x, pos.y)

	return function()
		local finished = tween:update(1)
		canvas:move(canvas.x, math.floor(pos.y))
		canvas.parent:dirty(true)
		return not finished
	end
end

function Transition.shake(canvas, args)
	local ticks  = args.ticks or 8
	local i = ticks

	return function()
		i = -i
		canvas:move(canvas.x + i, canvas.y)
		if i > 0 then
			i = i - 2
		end
		return i ~= 0
	end
end

function Transition.shuffle(canvas, args)
	local ticks  = args.ticks or 4
	local easing = args.easing or 'linear'
	local t = { }

	for _,child in pairs(canvas.children) do
		t[child] = Tween.new(ticks, child, { x = child.x, y = child.y }, easing)
		child.x = math.random(1, canvas.parent.width)
		child.y = math.random(1, canvas.parent.height)
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
