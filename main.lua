local mod = RegisterMod("My Mod", 1)
local partypopper = Isaac.GetItemIdByName("Party Popper")
local sfxReforger = SFXManager()
local sfxPopper = SFXManager()
local sfxCrit = SFXManager()
local teargas = Isaac.GetItemIdByName("Tear Gas")
local rock = Isaac.GetItemIdByName("Scroll of Earthbending")
local supportfire = Isaac.GetItemIdByName("Holy Spirit")
local scraper = Isaac.GetItemIdByName("Scraper")
local pierogis = Isaac.GetItemIdByName("Pierogis")
local reforger = Isaac.GetItemIdByName("Reforger")
local nebulizer = Isaac.GetItemIdByName("Nebulizer")
local pierogicounter = 0;
function mod:EvaluateCache(player, cacheFlags)
    if cacheFlags & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
        -- Damage Multiplier down for teargas
        if(player:GetCollectibleNum(teargas)>=1) then
            player.Damage = player.Damage * 0.5
        end
    elseif cacheFlags & CacheFlag.CACHE_FIREDELAY == CacheFlag.CACHE_FIREDELAY then
        --Calculate Tears Up for teargas
        local itemCount = player:GetCollectibleNum(teargas)
        if(itemCount>=1) then
            local TearBonus = math.max((player.MaxFireDelay/2) - (2+(0.5*player:GetCollectibleNum(teargas)-1)),0.25)
            player.MaxFireDelay = TearBonus
        end
    elseif cacheFlags & CacheFlag.CACHE_RANGE == CacheFlag.CACHE_RANGE then
        -- Range Down for teargas
        if (player:HasCollectible(teargas)) then
            local rangeModifier = player.TearRange * 0.7
            player.TearRange = rangeModifier
        end
    elseif cacheFlags & CacheFlag.CACHE_LUCK == CacheFlag.CACHE_LUCK then
        -- Luck up and HP up for pierogis
        local itemCount = player:GetCollectibleNum(pierogis)
        player.Luck = player.Luck + itemCount
        -- Gives 2 heart containers, 2 bone hearts, and heals to full
        if(pierogicounter<itemCount) then
            player:AddMaxHearts(4,true)
            player:AddBoneHearts(2)
            player:AddHearts(99999)
            pierogicounter=pierogicounter+1
        end
    end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.EvaluateCache)
local rocktimer = 0
local lastshootdirection = Vector(0,0)
function mod:onPassive(player) 
    -- Code for random spray of tears for teargas
    if (player:HasCollectible(teargas)) then
        for _, entity in pairs(Isaac.GetRoomEntities()) do
            if entity.Type == EntityType.ENTITY_TEAR then
                local tearData = entity:GetData()
                local tear = entity:ToTear()
                if (tearData.teargas == nil and tearData.rock == nil) then
                    math.randomseed(Game():GetFrameCount())
                    local rand = math.random()
                    local direction = math.random(1,2)
                    if (direction==1) then
                        rand = rand*-1
                    end
                    local face = player:GetFireDirection()
                    if (face==Direction.UP or face==Direction.DOWN) then
                        local tearvector = Vector(rand*3, 0)
                        tear:AddVelocity(tearvector)
                    end
                    if(Direction.LEFT or Direction.RIGHT) then
                        local tearvector = Vector(0, rand*3)
                        tear:AddVelocity(tearvector)
                    end
                    tearData.teargas = true
                end
            end
        end
    end
    if(player:HasCollectible(rock) and (not player:HasCollectible(52)) and (not player:HasCollectible(168)) and (not player:HasCollectible(329)) and (not player:HasCollectible(394))) then -- Code for throwing rock for rock item
        if (not (player:GetShootingJoystick().X == 0) or not (player:GetShootingJoystick().Y == 0) or player:GetFireDirection()>-1) then
            -- Character pulse when rock is ready
            if(rocktimer>=150) then
                local offset = (Game():GetFrameCount()%60)
                if offset>30 then
                    offset = 30-(offset-30)
                end
                offset=offset/60+0.5
                local colorset = Color(53/255,27/255,0,1,0,0,0)
                colorset:SetTint(offset,offset,offset,1)
                player:SetColor(colorset, 1, 0, false, false)
            end
            rocktimer=rocktimer+1
            lastshootdirection = player:GetShootingJoystick()
        -- Fire Rock when released
        elseif (rocktimer>=150) then
            local shoot = lastshootdirection
            shoot = shoot*10
            shoot = shoot + player:GetMovementVector()*3
            local tearEntity = player:FireTear( player.Position, shoot, true, false, true, player, 4 )
            tearEntity.TearFlags = TearFlags.TEAR_NORMAL
            local tearData = tearEntity:GetData()
            tearEntity.FallingAcceleration = 1
            tearEntity.FallingSpeed = -20
            tearEntity:ChangeVariant(TearVariant.ROCK)
            tearEntity:AddTearFlags(TearFlags.TEAR_ACID)
            tearEntity.Scale = tearEntity.Scale * 1.3
            tearData.rock = true
            rocktimer=0
        else
            rocktimer=0
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.onPassive)

-- Explosion of rock into smaller rocks, similar to Haemolacria
function mod:rockExplode()
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Type == EntityType.ENTITY_TEAR then
            local tearData = entity:GetData()
            local tear = entity:ToTear()
            --Checking if entities in room have rock flag, and creating explosion from death point
            if (tearData.rock == true and tearData.explode == nil and entity:IsDead()) then
                for i = 1, 5 do
                    local damage = tear.BaseDamage/math.random(4,10)
                    local splashTear = Isaac.GetPlayer():FireTear(tear.Position, Vector(Isaac.GetPlayer().ShotSpeed*10,0):Rotated(math.random(360)), true,true,false, player, damage)
                    splashTear.TearFlags = TearFlags.TEAR_NORMAL
                    local tearBonus = math.random()*.5+.75
                    splashTear:ToTear().Scale = tear.Scale*tearBonus*0.52192982456
                    splashTear:ToTear().FallingSpeed = (tear.FallingSpeed*.5*(math.random()*.75+.5))*-2
                    splashTear:ToTear().FallingAcceleration = 1.3
                    splashTear:ToTear():ChangeVariant(TearVariant.ROCK)
                    tearData.explode = true
                end
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.rockExplode)

-- Function for spawning secondary supportfire tears when Isaac deals damage
function mod:supportFire(entity, amount, damageflags, source, countdownframes)
    if Isaac.GetPlayer():HasCollectible(supportfire) then
        if (source.SpawnerType == EntityType.ENTITY_PLAYER or source.Type == EntityType.ENTITY_PLAYER) and source.Entity:GetData().SupportFire == nil and entity:IsVulnerableEnemy() == true and entity:IsDead() == false then
            for i=1, Isaac.GetPlayer():GetCollectibleNum(supportfire) do
                -- Angle to fire tear behind Isaac
                local rotate = 140
                if(math.random(0,1)==0) then
                    rotate = -140
                end
                -- Construction of tear and its attributes
                local tearEntity = Isaac.GetPlayer():FireTear(Isaac.GetPlayer().Position, (lastshootdirection*math.random(8,15)):Rotated(rotate), false,true,false, Isaac.GetPlayer(), 1)
                tearEntity:ChangeVariant(TearVariant.DARK_MATTER)
                tearEntity.CollisionDamage = amount * 0.5
                local color = Color.Default
                tearEntity:SetColor(Color(1, 1, 1, 1, 255, 255, 255), 9999999, 1, false, false)
                tearEntity:SetKnockbackMultiplier(0)
                tearEntity.TearFlags = TearFlags.TEAR_NORMAL
                tearEntity:AddTearFlags(TearFlags.TEAR_HOMING)
                tearEntity:AddTearFlags(TearFlags.TEAR_SPECTRAL)
                tearEntity.SpriteScale = tearEntity.SpriteScale * 0.4
                tearEntity:GetData().AggressiveHoming = true
                tearEntity:GetData().HomingStrength = 1
                tearEntity:GetData().SupportFire = true
                tearEntity.FallingSpeed = 0
                tearEntity.FallingAcceleration = -0.1
                -- Construction of tear trail and its attributes
                local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SPRITE_TRAIL, 0, tearEntity.Position,Vector(0,0),tearEntity)
                effect = effect:ToEffect()
                effect:FollowParent(tearEntity)
                effect.SpriteScale = effect.SpriteScale * (1.9*0.66)
                tearEntity.SpriteOffset = Vector(0,16)
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.supportFire)

-- Minimalizing knockback from supportfire tears
function mod:noKnockback(tear, collider, low)
    if tear:GetData().SupportFire == true then
        tear.Velocity = Vector(0,0)
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, mod.noKnockback)

--Advanced Homing algorithm so supportfire tears will seek enemies no matter what
function mod:UpdateTears()
    if (not (Isaac.GetPlayer():GetShootingJoystick().X == 0) or not (Isaac.GetPlayer():GetShootingJoystick().Y == 0) or Isaac.GetPlayer():GetFireDirection()>-1) then
        lastshootdirection = Isaac.GetPlayer():GetShootingJoystick()
    end
    --Scanning through all entities and checking for elligible AggressiveHoming entities
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Type == EntityType.ENTITY_TEAR and entity:GetData().AggressiveHoming then
            local tear = entity:ToTear()
            local nearestEnemy = nil
            local nearestDistance = math.huge
            --Finding the nearest vulnerable enemy to tear
            for _, target in pairs(Isaac.GetRoomEntities()) do
                local game = Game()
                if target:IsVulnerableEnemy() then
                    local distance = target.Position:Distance(tear.Position)
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestEnemy = target
                    end
                end
            end
            -- Modifying velocity to home towards enemy
            if nearestEnemy then
                local direction = (nearestEnemy.Position - tear.Position):Normalized()
                local homingStrength = tear:GetData().HomingStrength
                tear.Velocity = tear.Velocity + direction * homingStrength * 2
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.UpdateTears)

local SOUND_REFORGER = Isaac.GetSoundIdByName("Reforger")
-- Code for Reforger, its sfx, and its pickup upgrades
function mod:ReforgerUse(item)
    sfxReforger:Play(SOUND_REFORGER)
    local roomEntities = Isaac.GetRoomEntities()
    -- Ensuring pickup is elligible for Reforger
    for _, entity in ipairs(roomEntities) do
        if entity.Type == EntityType.ENTITY_PICKUP then
            -- All possible reforges
            if not (entity:ToPickup():IsShopItem()) then
                if entity.Variant == PickupVariant.PICKUP_HEART then
                    if entity.SubType == HeartSubType.HEART_FULL or entity.SubType == HeartSubType.HEART_HALF then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_DOUBLEPACK)
                    elseif entity.SubType == HeartSubType.HEART_DOUBLEPACK or entity.SubType == HeartSubType.HEART_HALF_SOUL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL)
                    elseif entity.SubType == HeartSubType.HEART_SOUL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_BLACK)
                    elseif entity.SubType == HeartSubType.HEART_BLACK then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_BONE)
                    elseif entity.SubType == HeartSubType.HEART_BONE then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_ETERNAL)
                    end
                elseif entity.Variant == PickupVariant.PICKUP_COIN then
                    if entity.SubType == CoinSubType.COIN_PENNY or entity.SubType == CoinSubType.COIN_STICKYNICKEL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK)
                    elseif entity.SubType == CoinSubType.COIN_NICKEL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME)
                    elseif entity.SubType == CoinSubType.COIN_DOUBLEPACK then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL)
                    end
                elseif entity.Variant == PickupVariant.PICKUP_BOMB then
                    if entity.SubType == BombSubType.BOMB_NORMAL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK)
                    elseif entity.SubType == BombSubType.BOMB_DOUBLEPACK then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDEN)
                    end
                elseif entity.Variant == PickupVariant.PICKUP_KEY then
                    if entity.SubType == KeySubType.KEY_NORMAL then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK)
                    elseif entity.SubType == KeySubType.KEY_DOUBLEPACK then
                        entity:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_GOLDEN)
                    end
                end
            end
        end
    end

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end

mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.ReforgerUse, reforger)

local SOUND_PARTYPOPPER = Isaac.GetSoundIdByName("Party Popper") 
-- Code for Party Popper, random effect to all non-boss enemies and sfx
function mod:PartyPopperUse(item)
    local roomEntities = Isaac.GetRoomEntities()
    math.randomseed(Game():GetFrameCount())
    sfxPopper:Play(SOUND_PARTYPOPPER)
    -- Apply random status effect to all non-boss enemies
    for _, entity in ipairs(roomEntities) do
        local x = math.random(0,4)
        if entity:IsVulnerableEnemy() == true then
            if (x==0) then
                entity:AddBurn(EntityRef(entity), 63, 3.5)
            elseif(x==1) then
                entity:AddCharmed(EntityRef(entity), 126)
            elseif(x==2) then
                entity:AddConfusion(EntityRef(entity), 126, true)
            elseif(x==3) then
                entity:AddFear(EntityRef(entity), 126)
            elseif(x==4) then
                entity:AddPoison(EntityRef(entity), 63, 3.5)
            end
        end
    end

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end

mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.PartyPopperUse, partypopper)

-- Code for Scraper, damage for 1-2 minisaacs
function mod:ScraperUse(item)
    local player = Isaac.GetPlayer()
    if player:GetDamageCooldown()==0 then
        player:TakeDamage(1, DamageFlag.DAMAGE_RED_HEARTS, EntityRef(nil), 0)
        player:AddMinisaac(player.Position, true)
        if(math.random(0,1)==0) then
            player:AddMinisaac(player.Position, true)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.ScraperUse, scraper)

--Code for Nebulizer, critical hits
local SOUND_CRIT = Isaac.GetSoundIdByName("Crit") 
function mod:Nebulizer(entity, damageamount, damageflags, source, countdown)
    if not entity:ToNPC() or damageamount <= 0 then return end
    if (damageflags & 1073742080) == (1073742080) then return end
    if (Isaac.GetPlayer():HasCollectible(nebulizer)) then
        if (source.SpawnerType == EntityType.ENTITY_PLAYER or source.Type == EntityType.ENTITY_PLAYER) and source.Entity:GetData().SupportFire == nil then
            if math.random() < (0.2 + 0.05 * Isaac.GetPlayer().Luck) then
                --Halve the volume
                sfxCrit:Play(SOUND_CRIT, 0.3, 0, false, 1.0)
                SPAWN_CRIT_TEXT(entity.Position)
                --DamageFlag clone and DamageFlag ignore armor
                entity:TakeDamage(damageamount * 0.5, damageflags | 1073742080, source, countdown)
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.Nebulizer, EntityType.Entity_NPC)
-- Animation handling for critical hits
local critSprite = Sprite()
critSprite:Load("gfx/effects/crit_text.anm2", true)
local activeCrits = {}
function SPAWN_CRIT_TEXT(position)
    local critAnim = {
        sprite = Sprite(),
        position = position,
        timer = 30,  -- How many frames the animation lasts
        offsetX = math.random(-10,10),
        offsetY = math.random(-10, 10)
    }
    critAnim.sprite:Load("gfx/effects/crit_text.anm2", true)
    critAnim.sprite:Play("Appear", true)
    table.insert(activeCrits, critAnim)
end
function mod:onRender()
    for i = #activeCrits, 1, -1 do
        local crit = activeCrits[i]
        
        -- Update animation
        crit.sprite:Update()
        
        -- Get the screen position from the room position
        local screenPos = Isaac.WorldToScreen(crit.position)
        
        -- Render at the converted position
        local offsetX = 0
        local offsetY = -20
        crit.sprite:RenderLayer(0, Vector(screenPos.X + offsetX + crit.offsetX, screenPos.Y + offsetY + crit.offsetY))
        
        -- Make text float upward (in room coordinates)
        crit.position = Vector(crit.position.X, crit.position.Y - 1)
        
        -- Decrease timer and remove if expired
        crit.timer = crit.timer - 1
        if crit.timer <= 0 then
            table.remove(activeCrits, i)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)
