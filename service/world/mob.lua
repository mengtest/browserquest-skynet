local class = require "class"
local Character = require "character"
local M = class.Class(Character)

function M.new()
    return setmetatable({},M)
end

function M:init(id, kind, x, y)
    self._base.init(self,id, "mob", kind, x, y)
    
    self:updateHitPoints()
    self.spawningX = x
    self.spawningY = y
    self.armorLevel = Properties.getArmorLevel(self.kind)
    self.weaponLevel = Properties.getWeaponLevel(self.kind)
    self.hatelist = {}
    self.respawnTimeout = nil
    self.returnTimeout = nil
    self.isDead = false
end

function M:destroy()
    self.isDead = true
    self.hatelist = {}
    self:clearTarget()
    self:updateHitPoints()
    self:resetPosition()
    
    self:handleRespawn()
end

function M:receiveDamage(points, playerId)
    self.hitPoints = self.hitPoints - points
end

function M:hates(playerId)
    return any(self.hatelist, function(obj)
        return obj.id == playerId 
    end)
end

function M:increaseHateFor(playerId, points)
    if self:hates(playerId) then
        detect(self.hatelist, function(obj)
            return obj.id == playerId
        end).hate += points
    else
        self.hatelist.push({ id= playerId, hate=points })
    end
    
    if self.returnTimeout then
        -- Prevent the mob from returning to its spawning position
        -- since it has aggroed a new player
        clearTimeout(self.returnTimeout)
        self.returnTimeout = nil
    end
end

function M:getHatedPlayerId(hateRank)
    local i, playerId,
        sorted = _.sortBy(self.hatelist, function(obj) return obj.hate }),
        size = _.size(self.hatelist)
    
    if hateRank && hateRank <= size then
        i = size - hateRank
    else
        i = size - 1
    end
    if sorted and sorted[i] then
        playerId = sorted[i].id
    end
    
    return playerId
end

function M:forgetPlayer(playerId, duration)
    self.hatelist = reject(self.hatelist, function(obj) return obj.id == playerId })
    
    if self.hatelist.length == 0 then
        self:returnToSpawningPosition(duration)
    end
end

function M:forgetEveryone()
    self.hatelist = {}
    self:returnToSpawningPosition(1)
end

function M:drop(item)
    if item then
        return new Messages.Drop(self, item)
    end
end

function M:handleRespawn()
    local delay = 30000,
    if(self.area && self.area instanceof MobArea)
        -- Respawn inside the area if part of a MobArea
        self.area.respawnMob(self, delay)
    else
        if(self.area && self.area instanceof ChestArea) then
            self.area.removeFromArea(self)
        end
        setTimeout(function()
            if(self.respawn_callback)
                self.respawn_callback()
            }
        end, delay)
    end
end

function M:onRespawn(callback)
    self.respawn_callback = callback
end

function M:resetPosition()
    self:setPosition(self.spawningX, self.spawningY)
end

function M:returnToSpawningPosition(waitDuration)
    local delay = waitDuration || 4000

    self:clearTarget()
    
    self.returnTimeout = setTimeout(function()
        self:resetPosition()
        self:move(self.x, self.y)
    end, delay)
end

function M:onMove(callback)
    self.move_callback = callback
end

function M:move(x, y)
    self:setPosition(x, y)
    if self.move_callback then
        self:move_callback()
    end
end

function M:updateHitPoints()
    self:resetHitPoints(Properties.getHitPoints(self.kind))
end

function M:distanceToSpawningPoint(x, y)
    return Utils.distanceTo(x, y, self.spawningX, self.spawningY)
end

return M
