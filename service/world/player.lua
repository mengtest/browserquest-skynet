local Character = require "character"
local class = require "class"

local M = class.Class(Character)

function M.new()
    local o = {}
    setmetatable(o,M)
    return o
end

function M:init(connection, worldServer)
    self.server = worldServer
    self.connection = connection

    Character.init(self,self.connection.id, "player", Types.Entities.WARRIOR, 0, 0, "")

    self.hasEnteredGame = false
    self.isDead = false
    self.haters = {}
    self.lastCheckpoint = nil
    self.formatChecker = FormatChecker.new()
    self.disconnectTimeout = nil
    
    self.connection.listen(function(message)
        local action = parseInt(message[0])
        
        log.debug("Received: "+message)
        if !check(message))
            self.connection.close("Invalid "+Types.getMessageTypeAsString(action)+" message format: "+message)
            return
        }
        
        if !self.hasEnteredGame && action !== Types.Messages.HELLO) // HELLO must be the first message
            self.connection.close("Invalid handshake message: "+message)
            return
        }
        if self.hasEnteredGame && !self.isDead && action == Types.Messages.HELLO) // HELLO can be sent only once
            self.connection.close("Cannot initiate handshake twice: "+message)
            return
        }
        
        self.resetTimeout()
        
        if action == Types.Messages.HELLO)
            local name = Utils.sanitize(message[1])
            
            // If name was cleared by the sanitizer, give a default name.
            // Always ensure that the name is not longer than a maximum length.
            // (also enforced by the maxlength attribute of the name input element).
            self.name = (name == "") ? "lorem ipsum" : name.substr(0, 15)
            
            self.kind = Types.Entities.WARRIOR
            self.equipArmor(message[2])
            self.equipWeapon(message[3])
            self.orientation = Utils.randomOrientation()
            self.updateHitPoints()
            self.updatePosition()
            
            self.server.addPlayer(self)
            self.server.enter_callback(self)

            self.send([Types.Messages.WELCOME, self.id, self.name, self.x, self.y, self.hitPoints])
            self.hasEnteredGame = true
            self.isDead = false
        }
        else if action == Types.Messages.WHO)
            message.shift()
            self.server.pushSpawnsToPlayer(self, message)
        }
        else if action == Types.Messages.ZONE)
            self.zone_callback()
        }
        else if action == Types.Messages.CHAT)
            local msg = Utils.sanitize(message[1])
            
            // Sanitized messages may become empty. No need to broadcast empty chat messages.
            if msg && msg !== "")
                msg = msg.substr(0, 60) // Enforce maxlength of chat input
                self.broadcastToZone(new Messages.Chat(self, msg), false)
            }
        }
        else if action == Types.Messages.MOVE)
            if self.move_callback)
                local x = message[1],
                    y = message[2]
                
                if self.server.isValidPosition(x, y))
                    self.setPosition(x, y)
                    self.clearTarget()
                    
                    self.broadcast(new Messages.Move(self))
                    self.move_callback(self.x, self.y)
                }
            }
        }
        else if action == Types.Messages.LOOTMOVE)
            if self.lootmove_callback)
                self.setPosition(message[1], message[2])
                
                local item = self.server.getEntityById(message[3])
                if item)
                    self.clearTarget()

                    self.broadcast(new Messages.LootMove(self, item))
                    self.lootmove_callback(self.x, self.y)
                }
            }
        }
        else if action == Types.Messages.AGGRO)
            if self.move_callback)
                self.server.handleMobHate(message[1], self.id, 5)
            }
        }
        else if action == Types.Messages.ATTACK)
            local mob = self.server.getEntityById(message[1])
            
            if mob)
                self.setTarget(mob)
                self.server.broadcastAttacker(self)
            }
        }
        else if action == Types.Messages.HIT)
            local mob = self.server.getEntityById(message[1])
            if mob)
                local dmg = Formulas.dmg(self.weaponLevel, mob.armorLevel)
                
                if dmg > 0)
                    mob.receiveDamage(dmg, self.id)
                    self.server.handleMobHate(mob.id, self.id, dmg)
                    self.server.handleHurtEntity(mob, self, dmg)
                }
            }
        }
        else if action == Types.Messages.HURT)
            local mob = self.server.getEntityById(message[1])
            if mob && self.hitPoints > 0)
                self.hitPoints -= Formulas.dmg(mob.weaponLevel, self.armorLevel)
                self.server.handleHurtEntity(self)
                
                if self.hitPoints <= 0)
                    self.isDead = true
                    if self.firepotionTimeout)
                        clearTimeout(self.firepotionTimeout)
                    }
                }
            }
        }
        else if action == Types.Messages.LOOT)
            local item = self.server.getEntityById(message[1])
            
            if item)
                local kind = item.kind
                
                if Types.isItem(kind))
                    self.broadcast(item.despawn())
                    self.server.removeEntity(item)
                    
                    if kind == Types.Entities.FIREPOTION)
                        self.updateHitPoints()
                        self.broadcast(self.equip(Types.Entities.FIREFOX))
                        self.firepotionTimeout = setTimeout(function()
                            self.broadcast(self.equip(self.armor)) // return to normal after 15 sec
                            self.firepotionTimeout = nil
                        end 15000)
                        self.send(new Messages.HitPoints(self.maxHitPoints).serialize())
                    } else if Types.isHealingItem(kind))
                        local amount
                        
                        switch(kind)
                            case Types.Entities.FLASK: 
                                amount = 40
                                break
                            case Types.Entities.BURGER: 
                                amount = 100
                                break
                        }
                        
                        if !self.hasFullHealth())
                            self.regenHealthBy(amount)
                            self.server.pushToPlayer(self, self.health())
                        }
                    } else if Types.isArmor(kind) || Types.isWeapon(kind))
                        self.equipItem(item)
                        self.broadcast(self.equip(kind))
                    }
                }
            }
        }
        else if action == Types.Messages.TELEPORT)
            local x = message[1],
                y = message[2]
            
            if self.server.isValidPosition(x, y))
                self.setPosition(x, y)
                self.clearTarget()
                
                self.broadcast(new Messages.Teleport(self))
                
                self.server.handlePlayerVanish(self)
                self.server.pushRelevantEntityListTo(self)
            }
        }
        else if action == Types.Messages.OPEN)
            local chest = self.server.getEntityById(message[1])
            if chest && chest instanceof Chest)
                self.server.handleOpenedChest(chest, self)
            }
        }
        else if action == Types.Messages.CHECK)
            local checkpoint = self.server.map.getCheckpoint(message[1])
            if checkpoint)
                self.lastCheckpoint = checkpoint
            }
        }
        else {
            if self.message_callback)
                self.message_callback(message)
            }
        }
    })
    
    self.connection.onClose(function()
        if self.firepotionTimeout)
            clearTimeout(self.firepotionTimeout)
        }
        clearTimeout(self.disconnectTimeout)
        if self.exit_callback)
            self.exit_callback()
        }
    })
    
    self.connection.sendUTF8("go") // Notify client that the HELLO/WELCOME handshake can start
end

destroy: function()
    local self = this
    
    self.forEachAttacker(function(mob)
        mob.clearTarget()
    })
    self.attackers = {}
    
    self.forEachHater(function(mob)
        mob.forgetPlayer(self.id)
    })
    self.haters = {}
end

function M:getState()
    local basestate = self._getBaseState()
    local state = {self.name, self.orientation, self.armor, self.weapon}

    if self.target  
        state.push(self.target)
    }
    
    return basestate.concat(state)
end

function M:send(message)
    self.connection.send(message)
end

function M:broadcast(message, ignoreSelf)
    if self.broadcast_callback)
        self.broadcast_callback(message, ignoreSelf == nil and true or ignoreSelf)
    end
end

function M:broadcastToZone(message, ignoreSelf)
    if self.broadcastzone_callback then
        self:broadcastzone_callback(message, ignoreSelf == nil and true or ignoreSelf)
    end
end

function M:onExit(callback)
    self.exit_callback = callback
end

function M:onMove(callback)
    self.move_callback = callback
end

function M:onLootMove(callback)
    self.lootmove_callback = callback
end

function M:onZone(callback)
    self.zone_callback = callback
end

function M:onOrient(callback)
    self.orient_callback = callback
end

function M:onMessage(callback)
    self.message_callback = callback
end

function M:onBroadcast(callback)
    self.broadcast_callback = callback
end

function M:onBroadcastToZone(callback)
    self.broadcastzone_callback = callback
end

function M:equip(item)
    return Messages.EquipItem.new(this, item)
end

function M:addHater(mob)
    self.haters[mob.id] = mob
end

function M:removeHater(mob)
    self.haters[mob.id] = nil
end

function M:forEachHater(callback)
    for _,mob in pairs(self.haters) do
        callback(mob)
    end
end

function M:equipArmor(kind)
    self.armor = kind
    self.armorLevel = Properties.getArmorLevel(kind)
end

function M:equipWeapon(kind)
    self.weapon = kind
    self.weaponLevel = Properties.getWeaponLevel(kind)
end

function M:equipItem(item)
    if item then
        log.debug(self.name + " equips " + Types.getKindAsString(item.kind))
        
        if Types.isArmor(item.kind) then
            self:equipArmor(item.kind)
            self:updateHitPoints()
            self:send(Messages.HitPoints.new(self.maxHitPoints).serialize())
        elseif Types.isWeapon(item.kind) then
            self.equipWeapon(item.kind)
        end
    end
end

function M:updateHitPoints()
    self.resetHitPoints(Formulas.hp(self.armorLevel))
end

function M:updatePosition()
    if self.requestpos_callback then
        local pos = self.requestpos_callback()
        self:setPosition(pos.x, pos.y)
    end
end

function M:onRequestPosition(callback)
    self.requestpos_callback = callback
end

function M:resetTimeout()
end

function M:timeout()
    self.connection.sendUTF8("timeout")
    self.connection.close("Player was idle for too long")
end

return M