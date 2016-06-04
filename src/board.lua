module(..., package.seeall)
board_mt = {}
board_mt.__index = board_mt

BLOCK_OFFSET = 0.05
FRAME_WIDTH = 0.2

local BLOCK_SIDE_LEN = 1 - 2*BLOCK_OFFSET

-- construct a new board
-- w		width
-- h		height
-- nbuf 	number of lines above the visible area/ new shapes spawn in this area
function new_board(w, h, nbuf)
	local b = {}
	_G.setmetatable(b,board_mt)
	b.fixed = {} -- fixed blocks
	b:set_size(w, h, nbuf)
	return b
end

function board_mt:get(x, y)
	local row = self.fixed[x]
	if row then
		return row[y]
	else
		return nil
	end
end

-- @value  default false
function board_mt:set(x, y, value)
	if x >= 0 and x < self.width and y >= -self.nbuf and y < self.height then
		self.fixed[x][y] = value or false
		return true
	else
		return false
	end
end

function board_mt:draw()
	self:draw_outline()
	self:draw_blocks()
end

-- w 		width
-- h 		the height of visible part of board
-- nbuf		the numbers of lines above the visible field; i.e. y<0
function board_mt:set_size(w, h, nbuf)
	self.width = w
	self.height = h
	self.nbuf = nbuf
	for x = 0, w-1 do
		self.fixed[x] = {}
		for y = -nbuf, h-1 do
			self.fixed[x][y] = false -- false or nil, this is a question
		end
	end
	love.window.setMode(SCALE_FACTOR * (w+4), SCALE_FACTOR * (h+1))
end

function board_mt:resize(dw, dh)
	for x=self.width,self.width+dw-1 do
		self.fixed[x] = {}
		for y=0,self.height-1 do
			self:set(x, y, false)
		end
	end
	self.width = self.width + dw
	for y=self.height,self.height+dh-1 do
		for x=0,self.width-1 do
			self:set(x, y, false)
		end
	end
	self.height = self.height + dh
	love.window.setMode(SCALE_FACTOR * (self.width+4), SCALE_FACTOR * (self.height+1))
end

function draw_single(x, y)
	love.graphics.rectangle("fill", x+BLOCK_OFFSET, y+BLOCK_OFFSET, BLOCK_SIDE_LEN, BLOCK_SIDE_LEN, 0.1, 0.1)
end


function draw_round_rect(w, h, linewidth)
	love.graphics.setLineWidth(linewidth)
	love.graphics.rectangle("line", -linewidth, -linewidth, w+2*linewidth, h+2*linewidth, 0.2, 0.2) -- outer frame
end

-- draw the content of a board
-- remember to do `graphics.push()` and `pop`
function board_mt:draw_blocks()
	for x = 0, self.width - 1 do
		for y = 0, self.height - 1 do
			if self:get(x, y) then
				-- draw when there is a block
				love.graphics.setColor(COLOR_FILL)
				draw_single(x, y)
			elseif y < self.height - 1 then
				-- draw when there is not a block (empty)
				love.graphics.setColor(COLOR_EMPTY)
				draw_single(x, y)
			end
		end
	end
end


function board_mt:draw_outline()
	love.graphics.setColor(COLOR_FRAME)
	draw_round_rect(self.width, self.height, FRAME_WIDTH) -- outer frame
	love.graphics.setColor(COLOR_DANGER)
	love.graphics.rectangle("fill", 0, self.height-1, self.width, 1, 0.1, 0.1) -- the most bottom red row
end


function board_mt:draw_highlight(start, across)
	love.graphics.setColor(COLOR_HIGHLIGHT)
	love.graphics.rectangle("fill", start, 0, across, self.height) -- the most bottom red row
end

-- draw small triangles at the top of frame
-- to indicate which columns have block coming
function board_mt:draw_indicator()
	-- TODO
end


-- move all blocks by (dx,dy)
function board_mt:shift(dx, dy)
	local new_b = {} -- fixed blocks
	for x = 0, self.width - 1 do
		new_b[x] = {}
		for y = -self.nbuf, self.height - 1 do
			new_b[x][y] = self:get(x-dx, y-dy) or false
		end
	end
	self.fixed = new_b
end


function board_mt:calc_coming()
	self.coming = {}
	for x = 0, self.width - 1 do
		self.coming[x] = false
		for y = -self.nbuf, 3 do
			if self:get(x, y) then
				self.coming[x] = true
				break
			end
		end
	end	
end


function board_mt:spawn()
	self:calc_coming()
	if not self.next then
		self.next = generate_chunk()
	end
	local l = -1
	while l < self.width do
		r = l - 1
		while not self.coming[r+1] and r < self.width do
			r = r + 1
		end
		local diff = r - l - self.next.width - 1
		if diff >= 0 then
			local offsetx = math.random(0, diff)
			local offsety = math.random(0, self.nbuf - self.next.maxheight)
			for x = 1, self.next.width do
				for y = -self.nbuf, -self.nbuf + self.next.heights[x] - 1 do
					self:set(x + l + offsetx, y + offsety,true)
				end
			end
			self.next = nil
			break
		end
		l = l + 1
	end
end


-- generate a chunk of blocks
-- format: {width = 5, heights = {1,2,4,2,3}}
-- # # # # #
--   # # # #
--     #   #
--     #    
function generate_chunk()
	local result = {}
	local rnd = math.random()
	local maxheight

	if rnd < 0.526 then
		rnd = 3
		maxheight = 2
	elseif rnd < 0.702 then
		rnd = 4
		maxheight = 3
	elseif rnd < 0.877 then
		rnd = 5
		maxheight = math.random(2, 4)
	elseif rnd < 0.965 then
		rnd = 2
		maxheight = 2
	else
		rnd = 6
		maxheight = 4
	end
	result.width = rnd
	result.maxheight = maxheight

	result.heights = {}
	for i=1,result.width do
		result.heights[i] = math.floor(random_height() * maxheight) + 1
	end

	-- make sure that the chunk is not already an rectangle
	local same = true
	for i=1,result.width-1 do
		if result.heights[i] ~= result.heights[i+1] then
			same = false
			break
		end
	end
	if same then
		local insurance
		local same_value = result.heights[1]
		if same_value == maxheight then
			insurance = maxheight - 1
		else
			insurance = same_value + 1
		end
		result.heights[math.random(1, result.width)] = insurance
	end

	return result
end

-- get a random height for a strip (vertical) in a chunk
-- return a value in between [0,1)
-- TODO make numbers distribute more natural
function random_height()
	local rnd = math.random()
	-- if rnd < 0.526 then
	-- 	rnd = 3
	-- elseif rnd < 0.702 then
	-- 	rnd = 4
	-- elseif rnd < 0.877 then
	-- 	rnd = 5
	-- elseif rnd < 0.965 then
	-- 	rnd = 2
	-- else
	-- 	rnd = 6
	-- end
	return rnd
end


-- generate a random fragment
function rndFragment()
	local rnd = math.random()
	if rnd < 3/12 then		
		return makeFragment(0,0)
	elseif rnd < 5/12 then
		return makeFragment(0,0,1,0)
	elseif rnd < 7/12 then
		return makeFragment(0,0,0,1)
	elseif rnd < 8/12 then
		return makeFragment(0,0,1,0,0,1)
	elseif rnd < 9/12 then
		return makeFragment(1,1,1,0,0,1)
	elseif rnd < 10/12 then
		return makeFragment(1,1,0,0,0,1)
	elseif rnd < 11/12 then
		return makeFragment(1,1,1,0,0,0)
	else
		return makeFragment(0,0,1,0,0,1,1,1)
	end
end

function makeFragment(...)
	local coords = {...}
	local result = {width=0, height=0}
	for i=1,#coords/2 do
		local x, y = coords[i*2-1], coords[i*2]
		table.insert(result, {x = x, y = y})
		if x > result.width-1 then
			result.width = x + 1
		end
		if y > result.height-1 then
			result.height = y + 1
		end
	end
	return result
end
