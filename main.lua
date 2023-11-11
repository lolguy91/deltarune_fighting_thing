-- main.lua

-- Global variables
local bgColor = {0, 0, 1}  -- Blue sky color
local platformColor = {0, 1, 0}  -- Green platform color
local deathZoneColor = {1, 0, 0}  -- Red death zone color

-- Global variables
local frameWidth = 32
local frameHeight = 64


-- Global animations array
local animations = {
    {fromIndex = 0, toIndex = 0, fps = 1},  -- Idle animation
    {fromIndex = 0, toIndex = 1, fps = 6},   -- Walk animation
    {fromIndex = 1, toIndex = 1, fps = 1},      -- jumping
    {fromIndex = 2, toIndex = 2, fps = 1},   -- Punching animation
}

-- Character definitions
local characters = {
    {
        name = "Kris",
        spriteSheet = love.graphics.newImage("kris.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 500,
        height = 19,
        speed = 180,
        strength = 10,
        maxHp = 300,
        jumpVelocity = -300,
        specialAbility = function(player)
            print("Special ability of Kris activated!")
        end
    },
    {
        name = "Susie",
        spriteSheet = love.graphics.newImage("susie.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 600,
        height = 19,
        speed = 200,
        strength = 12,
        maxHp = 420,
        jumpVelocity = -300,
        specialAbility = function(player)
            print("Special ability of Susie activated!")
        end
    },
    -- Add more characters as needed
}

-- Game state
local platformWidth = love.graphics.getWidth() - 200
local platformHeight = 100
local platform = {x = 100, y = love.graphics.getHeight() - 120, width = platformWidth, height = platformHeight}
local deathZoneHeight = 90
local victoryFont = love.graphics.newFont(40)
local isGameOver = false

-- Player state
local players = {
    {
        characterIndex = 1,
        x = 100,
        y = 100,
        hp = characters[1].maxHp,
        velocityY = 0,
        isOnGround = false,
        sFacingLeft = false,
        pounchTimer = 0,
        action = 0,
        xvel = 0,
        controls = {up = "w", left = "a", right = "d", special = "q", pounch = "e"}
    },
    {
        characterIndex = 2,
        x = 200,
        y = 100,
        hp = characters[2].maxHp,
        velocityY = 0,
        isOnGround = false,
        sFacingLeft = false,
        pounchTimer = 0,
        action = 0,
        xvel = 0,
        controls = {up = "i", left = "j", right = "l", special = "u", pounch = "o"}
    },
    -- Add entries for other players as needed
}

local standingPlayers = #players -- Initially, all players are standing

-- Function to take damage from the death zone
local function takeDamage(player, amount)
    player.hp = math.max(0, player.hp - amount)

    if player.hp == 0 then
        standingPlayers = standingPlayers - 1
        if standingPlayers == 1 then
            isGameOver = true
        end
    end
end

-- Function to activate special ability
local function activateSpecialAbility(player)
    characters[player.characterIndex].specialAbility(player)
end

-- Function to check player-to-player collisions
local function checkPlayerCollisions(players)
    for i, player1 in ipairs(players) do
        for j, player2 in ipairs(players) do
            if i ~= j then  -- Avoid checking a player against itself
                local halfFrameWidth = frameWidth / 2
                local halfFrameHeight = frameHeight / 2

                -- Check if the bounding boxes overlap
                if player1.x + halfFrameWidth > player2.x - halfFrameWidth and
                   player1.x - halfFrameWidth < player2.x + halfFrameWidth and
                   player1.y + halfFrameHeight > player2.y - halfFrameHeight and
                   player1.y - halfFrameHeight < player2.y + halfFrameHeight then

                    -- Resolve the collision (push players away from each other)
                    local overlapX = (player1.x + player2.x) / 2

                    if math.abs(player1.xvel) == math.abs(player2.xvel) then
                        if player1.xvel < player2.x then
                            player1.x = overlapX - frameWidth
                            player2.x = overlapX + frameWidth
                        else
                            player1.x = overlapX + frameWidth
                            player2.x = overlapX - frameWidth
                        end
                    elseif math.abs(player1.xvel) > math.abs(player2.xvel) then 
                        if player1.xvel < player2.x then
                            player2.x = overlapX + frameWidth
                        else
                            player2.x = overlapX - frameWidth
                        end
                    else
                        if player1.xvel < player2.x then
                            player1.x = overlapX - frameWidth
                        else
                            player1.x = overlapX + frameWidth
                        end
                    end
                end
            end
        end
    end
end

-- Function to check collisions
local function checkCollisions(player)
    local halfFrameWidth = frameWidth / 2
    local halfFrameHeight = frameHeight / 2

    -- Simple collision with platform
    if player.y + halfFrameHeight > platform.y - halfFrameHeight and
        player.x + halfFrameWidth < platform.x + platform.width and
        player.x + halfFrameWidth > platform.x then
        player.y = platform.y - frameHeight
        player.velocityY = 0
        if player.action == 2 then
            player.action = 0
        end
        player.isOnGround = true
    else
        player.isOnGround = false
    end
    checkPlayerCollisions(players)

    -- Death zone
    if player.y > love.graphics.getHeight() - deathZoneHeight then
        player.y = love.graphics.getHeight() - deathZoneHeight
        player.velocityY = characters[player.characterIndex].jumpVelocity * 3  -- Shoot the player upwards
        takeDamage(player, 10)
    end
end

-- Function to draw the player with animation
local function drawPlayer(player)
    local character = characters[player.characterIndex]
    local currentAnimation = animations[player.action + 1]

    local frameCount = currentAnimation.toIndex - currentAnimation.fromIndex + 1
    local currentFrame = currentAnimation.fromIndex + (math.floor(love.timer.getTime() * currentAnimation.fps) % frameCount + 1)
    local frameX = (currentFrame - 1) % 4 * frameWidth
    local frameY = math.floor((currentFrame - 1) / 4) * frameHeight

    -- Set the mag filter to nearest for pixel art
    character.spriteSheet:setFilter("nearest", "nearest")

    -- Double the visual size using the scale option
    local scale = 2
    -- Draw the player with animation and facing angle (flip or not)
    love.graphics.draw(
        character.spriteSheet,
        love.graphics.newQuad(frameX, frameY, frameWidth, frameHeight,
        character.spriteSheet),
        player.x, player.y,
        0,  -- Rotation angle
        player.isFacingLeft and -scale or scale,
        scale,
        frameWidth / 2,
        frameHeight / 2
    )

    -- Display health
    love.graphics.print("HP: " .. player.hp, player.x - (frameWidth * scale) / 2, player.y - (character.height * scale))
end

-- Function to handle player input and movement
local function handlePlayerMovement(player, dt)
    if player.hp ~= 0 then
        -- Player movement based on controls
        player.xvel = 0
        if player.action == 1 and player.isOnGroundthen then
            player.action = 0
        end
        if player.action == 3 and player.pounchTimer == 0 then
            if player.isOnGround then 
                player.action = 0
            else
                player.action = 2
            end
        end

        if player.pounchTimer ~= 0 then
            player.pounchTimer = player.pounchTimer - 1
        end

        if player.action > -1 and player.action < 3 then
            if love.keyboard.isDown(player.controls.up) and player.isOnGround then
                player.velocityY = characters[player.characterIndex].jumpVelocity
                player.isOnGround = false
                player.action = 2
            end

            if love.keyboard.isDown(player.controls.left) and player.x > 0 then
                player.x = player.x - characters[player.characterIndex].speed * dt
                player.isFacingLeft = true  -- Facing left
                if player.action == 2 then
                    player.action = 1
                end
                player.xvel = -1
            end

            if love.keyboard.isDown(player.controls.right) and player.x < love.graphics.getWidth() - frameWidth then
                player.x = player.x + characters[player.characterIndex].speed * dt
                player.isFacingLeft = false  -- Facing right
                if player.action == 2 then
                    player.action = 1
                end
                player.xvel = 1
            end
        end

        -- Gravity
        player.velocityY = player.velocityY + characters[player.characterIndex].gravity * dt
        player.y = player.y + player.velocityY * dt

        -- Special ability activation
        if love.keyboard.isDown(player.controls.special) then
            activateSpecialAbility(player)
        end
        -- Special ability activation
        if love.keyboard.isDown(player.controls.pounch) then
            player.action = 3
            player.pounchTimer = 3
            if player.pounchTimer == 3 then
            for _, targetPlayer in ipairs(players) do
                if targetPlayer ~= player and targetPlayer.hp > 0 then
                    -- Check if the target is within punching range
                    local punchRange = frameWidth * 2  -- Adjust as needed
                    if math.abs(player.x - targetPlayer.x) < punchRange and
                        ((player.isFacingLeft and player.x > targetPlayer.x) or (not player.isFacingLeft and player.x < targetPlayer.x)) then
                        -- Deal damage
                        takeDamage(targetPlayer, characters[player.characterIndex].strength)

                        -- Apply knockback
                        local direction = (player.x < targetPlayer.x) and 1 or -1
                        targetPlayer.x = targetPlayer.x + direction * (characters[player.characterIndex].strength * 10)
                    end
                end
            end
            end
        end

        checkCollisions(player)
    end
end

-- Function to draw the game
local function drawGame()
    for _, player in ipairs(players) do
        if player.hp ~= 0 then
            drawPlayer(player)
        end
    end

    -- Death zone gradient
    love.graphics.setColor(deathZoneColor)
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() - deathZoneHeight, love.graphics.getWidth(), deathZoneHeight)
    love.graphics.setColor(1, 1, 1) -- Reset color

    -- Green platform
    love.graphics.setColor(platformColor)
    love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)
    love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Function to draw the victory screen
local function drawVictoryScreen()
    love.graphics.setColor(platformColor)
    love.graphics.setFont(victoryFont)
    love.graphics.print("VICTORY!", love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    
    local last_standing = 0
    for i, p in ipairs(players) do
        if p.hp ~= 0 then
            love.graphics.print(characters[p.characterIndex].name .. " Won!", love.graphics.getWidth() / 2, (love.graphics.getHeight() / 2) + 51)
            break
        end
    end
    love.graphics.setColor(1, 1, 1) -- Reset color
end

function love.load()
    love.window.setTitle("Deltarune Fighting thing IDFK")
    
    -- Set initial health for each player
    for _, player in ipairs(players) do
        player.hp = characters[player.characterIndex].maxHp
    end
end

function love.update(dt)
    if not isGameOver then
        for _, player in ipairs(players) do
            handlePlayerMovement(player, dt)
        end
    end
end

function love.draw()
    love.graphics.setBackgroundColor(bgColor) -- Set background color

    if not isGameOver then
        drawGame()
    else
        drawVictoryScreen()
    end
end
