local board = require 'board'
local tween = require 'tween'
local scheduler  = require 'scheduler'

local g = love.graphics

local b -- the board
local bg_color = {0,0,0} -- background color
local centered_text -- the text centered in the screen, has several usage
local CURRENT_BOX_SIDE_LEN = 2
local current_fragment -- current piece ready to launch by player
local current_pos = 0 -- current launch position; should never be nil
local DEFAULT_STEP_LEN = 1
local hasFocus = true -- does my window has focus?
local kill_count
local scene -- current scene (string)
local scr_w, scr_h -- screen size
local sounds
local stepping_task -- the task which calls `step()`; change `interval` property of this will make blocks drop faster
local t_matrix = {x=0,y=0,scaleX=1,scaleY=1} -- the transformation
local tweens
SCALE_FACTOR = 32

-- colors
COLOR_DANGER = {255,92,93} -- empty grid
COLOR_EMPTY = {200,200,200, 64} -- empty grid
COLOR_FILL = {220,220,220} -- filled grid
COLOR_FRAME = {200,200,200} -- the frame outside board
COLOR_HIGHLIGHT = {32,32,64} -- used to highlight several columns
COLOR_PREDICT = {235,252,18,100}
COLOR_TEXT = {0xCD, 0xC4, 0xFF}
COLOR_TEXTBG = {50,50,50}
COLOR_TEXTLINE = {200,200,200}


function load(arg)
	math.randomseed(os.time()) -- I do not want to use love.math.random
	t_matrix.x = SCALE_FACTOR/2
	t_matrix.y = SCALE_FACTOR/2
	t_matrix.scaleX = SCALE_FACTOR
	t_matrix.scaleY = SCALE_FACTOR
	local font = g.newFont("arial.ttf", 30) -- TODO get a easy recognizable font
	centered_text = g.newText(font)
	sounds = {}
	-- assert(love.filesystem.exists("sound"), "sound files missing.")
	load_sound("die")
	load_sound("fire")
	load_sound("decay")
	play()
end

function load_sound(name)
	local filename = "sound/"..name..".wav"
	assert(love.filesystem.exists(filename), "file `"..filename.."` missing.")	
	local sound_data = love.sound.newSoundData(filename)
	assert(sound_data, "load sound `"..name.."` failed")
	sounds[name] = sound_data
	return sound_data
end

function play_sound(name)
	local sound_data = sounds[name]
	assert(sound_data, "no sound `"..name.."`.")
	local src = love.audio.newSource(sound_data)
	src:play()
end

function draw()
	scr_w, scr_h = g.getDimensions()
	love.graphics.clear(bg_color)
	love.graphics.origin()

	g.push()
	g.translate(t_matrix.x, t_matrix.y)
	g.scale(t_matrix.scaleX, t_matrix.scaleY)

	if scene == 'play' then
		b:draw_highlight(current_pos,current_fragment.width)
	end
	b:draw()
	if scene == 'play' then
		draw_prediction()
	end
	g.translate(b.width + 1, b.height - CURRENT_BOX_SIDE_LEN)
	draw_current()
	g.pop()

	if scene == 'play' and not hasFocus then
		draw_centered_text()
	elseif scene == 'dead' then
		draw_centered_text()
	end

	love.graphics.present()
end

function draw_prediction()
	g.setColor(board.COLOR_PREDICT)
	predict_dest(function(x,y,c)
		if y>=0 then
			board.draw_single(x,y)
		end
		c[x][y] = true
	end, true)
end

function draw_current()
	love.graphics.setColor(board.COLOR_FRAME)
	board.draw_round_rect(CURRENT_BOX_SIDE_LEN, CURRENT_BOX_SIDE_LEN, board.FRAME_WIDTH)
	for i,v in ipairs(current_fragment) do
		love.graphics.setColor(board.COLOR_FILL)
		board.draw_single(v.x + (CURRENT_BOX_SIDE_LEN - current_fragment.width) / 2,
			v.y + (CURRENT_BOX_SIDE_LEN - current_fragment.height) / 2)
	end
end

function draw_centered_text()
	local posx = math.floor((scr_w-centered_text:getWidth())/2) -- if text is not drawn with integer coordinates, it will be obscure
	local posy = math.floor((scr_h-centered_text:getHeight())/2)
	local bound = 20 -- measures the margins or the "textbox"
	local r = 4 -- radius of round corners of the "textbox"
	g.setColor(COLOR_TEXTBG)
	g.rectangle("fill", posx-bound, posy-bound, centered_text:getWidth()+bound*2, centered_text:getHeight()+bound*2, r, r)
	g.setColor(COLOR_TEXTLINE)
	g.setLineWidth(4)
	g.rectangle("line", posx-bound, posy-bound, centered_text:getWidth()+bound*2, centered_text:getHeight()+bound*2, r, r)
	g.setColor(COLOR_TEXT)
	g.draw(centered_text, posx, posy)
end

local function update(dt)
	scheduler.update(dt)
	update_tweens(dt)
end

function step()
	b:shift(0, 1)
	local dead = false
	for x = 0, b.width - 1 do
		if b.fixed[x][b.height-1] then
			dead = true
			break
		end
	end
	if dead then
		die()
	end
	b:spawn()
	draw()
end

function play()
	scene = 'play'
	kill_count = 0
	another_counter = 0
	tweens = {}
	stepping_task = scheduler.add(step, DEFAULT_STEP_LEN) -- starting speed: 1 block down/1 sec
	b = board.new_board(10,20,6)
	current_pos = math.floor(b.width / 2)
	current_fragment = board.rndFragment()
	step() -- refresh all
end

function die()
	scene = 'dead'
	tweens = {}
	scheduler.clear()
	play_sound("die")
	centered_text:set('Game Over\npress any KEY to restart')
	draw()
end
	
local function check_input()
	
end

function update_tweens(dt)
	for i = #tweens, 1, -1 do
		if tweens[i].update(dt) then
			table.remove(tweens, i)
		end
	end
end

function new_tween(duration, subject, target, easing)
	local new_tween_object = tween.new(duration, subject, target, easing)
	table.insert(tweens, new_tween_object)
	return new_tween_object
end

-- convert window coords -> graphics coords
function get_graphics_coord(x, y)
	return (x -t_matrix.x) / t_matrix.scaleX, (y - t_matrix.y) / t_matrix.scaleY
end

function limit(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end
end

function move_launch_pos(y)
	current_pos = limit(y, 0, b.width - current_fragment.width)
end

function fire()
	local lastx={}
	local lasty={}
	predict_dest(function(x, y)
		b:set(x, y, true)
		if y >= b.height - 1 then
			die()
			draw()
			return true
		end
		table.insert(lastx, x)
		table.insert(lasty, y)
	end)
	local do_eliminate = false
	for i=1,#lastx do
		do_eliminate = try_eliminate(lastx[i], lasty[i]) or do_eliminate
	end
	current_fragment = board.rndFragment()
	if do_eliminate then
		play_sound("decay")
	else
		play_sound("fire")
	end
	draw()
end

function try_eliminate(startx, starty)
	if not b:get(startx, starty) then
		return false
	end
	local y = starty
	while b:get(startx, y-1) do
		y = y - 1
	end
	while b:get(startx, starty+1) do
		starty = starty + 1
	end
	local l = startx
	while b:get(l-1, y) do
		l = l - 1
	end
	local r = startx
	while b:get(r+1, y) do
		r = r + 1
	end
	for x=l,r do
		for yy=y+1,starty do
			if not b:get(x, yy) then
				return false
			end
		end
		if b:get(x, starty+1) then
			return false
		end
	end
	eliminate(y, starty, l, r)
	return true
end

-- remember up < down
function eliminate(up, down, left, right)
	for x=left,right do
		for y=up,down do
			b:set(x,y,false)
		end
	end
	if b.width < 22 then
		kill_count = kill_count + (down-up+1) * (right-left+1)
		if kill_count >= b.width * 10 then
			local h = 0
			kill_count = 0
			another_counter = another_counter + 1
			if another_counter > 4 then
				another_counter = 0
				h = 1
			end
			b:resize(1, h)
		end
		-- if stepping_task.interval > 0.5 then
		-- 	stepping_task.interval = stepping_task.interval * 0.98
		-- end
	end
end

function predict_dest(callback, use_cache)
	if use_cache then
		cache = deepcopy(b.fixed)
	else
		cache = b.fixed
	end
	for i=1,#current_fragment do
		local x = current_fragment[i].x + current_pos
		if cache[x] then
			local y = b.height - 1
			while true do
				if cache[x][y-1] == nil then
					break
				elseif cache[x][y-1] == false then
					y = y - 1
				else
					if callback(x, y, cache) then
						return
					end
					break
				end
			end
		end
	end
end

-- copied from here: http://lua-users.org/wiki/CopyTable
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- rotate your "piece" clockwise
function rotate_cw()
	local offset = current_fragment.height - 1
	for i=1,#current_fragment do
		local pos = current_fragment[i]
		current_fragment[i] = {x = -pos.y + offset, y = pos.x}
	end
	local tmp = current_fragment.height
	current_fragment.height = current_fragment.width
	current_fragment.width = tmp
	draw()
end

function rotate_ccw()
	local offset = current_fragment.width - 1
	for i=1,#current_fragment do
		local pos = current_fragment[i]
		current_fragment[i] = {x = pos.y, y = -pos.x + offset}
	end
	local tmp = current_fragment.height
	current_fragment.height = current_fragment.width
	current_fragment.width = tmp
	draw()
end



function love.run()
	love.math.setRandomSeed(os.time())
	load(arg)
	love.timer.step()
	local dt = 0
	while true do
		love.event.pump()
		for name, a,b,c,d,e,f in love.event.poll() do
			if name == "quit" then
				return a
			end
			love.handlers[name](a,b,c,d,e,f)
		end
		love.timer.step()
		dt = love.timer.getDelta()
		if hasFocus then
			update(dt)
		end
		love.timer.sleep(0.001)
	end
end

function love.mousemoved(x, y)
	if scene == 'play' then
		x,y = get_graphics_coord(x,y)
		move_launch_pos(math.floor(x - (current_fragment.width - 1) / 2))
		draw()
	end
end

function love.mousepressed(x, y, button, isTouch)
	if scene == 'play' then
		if isTouch then
			rotate_cw()
		else
			if button == 1 then -- primary button
				fire()
			elseif button == 2 then -- secondary button
				rotate_cw()
				love.mousemoved(love.mouse.getPosition())
			end
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	if scene == 'play' then
		if key == 'left' then
			move_launch_pos(current_pos - 1)
		elseif key == 'right' then
			move_launch_pos(current_pos + 1)
		elseif key == 'space' then
			fire()
		elseif key == 'up' then
			rotate_cw()
		elseif key == 'down' then
			rotate_ccw()
		end
		draw()
	elseif scene == 'dead' then
		play()
	end
end

function love.focus(f)
	hasFocus = f
	if scene == 'play' and not f then
		centered_text:set('Paused')
	end
	draw()
end

function love.visible(v)
	draw()
end

function love.resize()
	draw()
end
