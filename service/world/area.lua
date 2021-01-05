local M = {}

function M:init(id, x, y, width, height, world)
    self.id = id
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.world = world
    self.entities = {}
    self.hasCompletelyRespawned = true
end

function M:getType()
    return "unknown"
end

function M:_getRandomPositionInsideArea()
    local pos = {}
    local valid = false
    
    while not valid do
        pos.x = self.x + math.random(self.width + 1)
        pos.y = self.y + math.random(self.height + 1)
        valid = self.world:isValidPosition(pos.x, pos.y)
    end
    return pos
end

function M:removeFromArea(entity)
    local i = indexOf(_.pluck(self.entities, 'id'), entity.id)
    self.entities.splice(i, 1)
    
    if self.isEmpty() and self.hasCompletelyRespawned and self.empty_callback then
        self.hasCompletelyRespawned = false
        self.empty_callback()
    end
end

function M:addToArea(entity)
    if entity then
        self.entities.push(entity)
        entity.area = self
        if entity:getType() == "mob" then
            self.world:addMob(entity)
        end
    end
    
    if self.isFull() then
        self.hasCompletelyRespawned = true
    end
end

function M:setNumberOfEntities(nb)
    self.nbEntities = nb
end

function M:isEmpty()
    return not any(self.entities, function(entity) return not entity.isDead end)
end

function M:isFull()
    return not self.isEmpty() and (self.nbEntities == _.size(self.entities))
end

function M:onEmpty(callback)
    self.empty_callback = callback
end

return M