local function pos(x, y)
    return {x=x, y=y}
end

local function equalPositions(pos1, pos2)
    return pos1.x == pos2.x && pos2.y == pos2.y
end

local M = {}

function M.new()
    return setmetatable({},{__index=M})
end

function M:init(name)
    self.isLoaded = false
    self.path = name
end

function M:load()
    local f = io.open(self.path,"rb")
    local data = f:read("*a")
    f:close()
    local data = json.decode(data)
    self:initMap(data)
end

function M:initMap(data)
    self.width = data.width
    self.height = data.height
    self.collisions = data.collisions
    self.mobAreas = data.roamingAreas
    self.chestAreas = data.chestAreas
    self.staticChests = data.staticChests
    self.staticEntities = data.staticEntities
    self.isLoaded = true
    
    -- zone groups
    self.zoneWidth = 28
    self.zoneHeight = 12
    self.groupWidth = math.floor(self.width / self.zoneWidth)
    self.groupHeight = math.floor(self.height / self.zoneHeight)

    self.initConnectedGroups(data.doors)
    self.initCheckpoints(data.checkpoints)

    if self.ready_func then
        self.ready_func()
    end
end

function M:ready(f)
    self.ready_func = f
end

function M:tileIndexToGridPosition(tileNum)
    local x = 0,y = 0
    
    local getX = function(num, w)
        if(num == 0) then
            return 0
        end
        return (num % w == 0) and (w - 1)  ((num % w) - 1)
    end

    tileNum = tileNum - 1
    x = getX(tileNum + 1, self.width)
    y = Math.floor(tileNum / self.width)

    return { x=x, y=y }
end

function M:GridPositionToTileIndex(x, y)
    return (y * self.width) + x + 1
end

function M:generateCollisionGrid()
    self.grid = {}

    if self.isLoaded then
        local tileIndex = 0
        for i = 1,self.height-1 do
            self.grid[i] = {}
            for j = 1,self.width do
                if(include(self.collisions, tileIndex)) then
                    self.grid[i][j] = 1
                else
                    self.grid[i][j] = 0
                end
                tileIndex = tileIndex + 1
            end
        end
    end
end

function M:isOutOfBounds(x, y)
    return x <= 0  x >= self.width  y <= 0  y >= self.height
end

function M:isColliding (x, y)
    if self.isOutOfBounds(x, y) then
        return false
    end
    return self.grid[y][x] == 1
end

function M:GroupIdToGroupPosition(id)
    local posArray = id.split('-')

    return pos(parseInt(posArray[0]), parseInt(posArray[1]))
end

function M:forEachGroup:(callback)
    local width = self.groupWidth,
        height = self.groupHeight
    
    for x=0,width-1 do
        for y=0,height-1 do
            callback(tostring(x)..'-'..tostring(y))
        end
    end
end

function M:getGroupIdFromPosition(x, y)
    local w = self.zoneWidth,
        h = self.zoneHeight,
        gx = Math.floor((x - 1) / w),
        gy = Math.floor((y - 1) / h)

    return tostring(gx) .. '-' .. tostring(gy)
end

function M:getAdjacentGroupPositions(id)
    local position = self:GroupIdToGroupPosition(id)
    local x = position.x
    local y = position.y
    -- surrounding groups
    local list = {pos(x-1, y-1), pos(x, y-1), pos(x+1, y-1),
                pos(x-1, y),   pos(x, y),   pos(x+1, y),
                pos(x-1, y+1), pos(x, y+1), pos(x+1, y+1)}
    
    -- groups connected via doors
    each(self.connectedGroups[id], function(position)
        -- don't add a connected group if it's already part of the surrounding ones.
        if(!_.any(list, function(groupPos) return equalPositions(groupPos, position) }))
            list.push(position)
        end
    end)
    
    return reject(list, function(pos) 
        return pos.x < 0 || pos.y < 0 || pos.x >= self.groupWidth || pos.y >= self.groupHeight
    end)
end

function M:forEachAdjacentGroup(groupId, callback)
    if groupId then
        each(self.getAdjacentGroupPositions(groupId), function(pos)
            callback(tostring(pos.x)..'-'..tostring(pos.y))
        end)
    end
end

function M.initConnectedGroups(doors)
    self.connectedGroups = {}
    _.each(doors, function(door)
        local groupId = self.getGroupIdFromPosition(door.x, door.y),
            connectedGroupId = self.getGroupIdFromPosition(door.tx, door.ty),
            connectedPosition = self.GroupIdToGroupPosition(connectedGroupId)
        
        if(groupId in self.connectedGroups)
            self.connectedGroups[groupId].push(connectedPosition)
        } else {
            self.connectedGroups[groupId] = [connectedPosition]
        }
    })
end

function initCheckpoints(cpList)
    self.checkpoints = {}
    self.startingAreas = []
    
    each(cpList, function(cp)
        local checkpoint = Checkpoint.new(cp.id, cp.x, cp.y, cp.w, cp.h)
        self.checkpoints[checkpoint.id] = checkpoint 
        if cp.s == 1 then
            self.startingAreas.push(checkpoint)
        end
    end)
end

function M:getCheckpoint(id)
    return self.checkpoints[id]
end

function M:getRandomStartingPosition()
    local nbAreas = size(self.startingAreas),
        i = Utils.randomInt(0, nbAreas-1),
        area = self.startingAreas[i]
    
    return area.getRandomPosition()
end



return M