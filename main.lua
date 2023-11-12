-- main.lua

-- Global constants
local bgColor = {0, 0, 30/255}  -- Blue sky color
local platformColor = {0, 1, 0}  -- Green platform color
local frameWidth = 32
local frameHeight = 64
local platformWidth = love.graphics.getWidth() - 200
local platformHeight = 100
local platform = {x = 100, y = love.graphics.getHeight() - 120, width = platformWidth, height = platformHeight}
local loveBaitRange = 200
local krisDamageRadius = 150
local gravityPushRange = 150
local bg = love.graphics.newImage("background.png")
local pf = love.graphics.newImage("platform.png")

-- Global variables
local currentScene = 1
local scenes = {}
local widgets = {}
local isRebinding = false
local keyBeingRebound = 1

local characterSelectionFont = love.graphics.newFont(20)
local victoryFont = love.graphics.newFont(40)



-- Game state
local deathZoneHeight = 90
local isGameOver = false
local standingPlayers = 0

-- Function to transition to a new scene
local function transitionToScene(sceneIndex)
    -- Clear existing widgets
    widgets = {}

    -- Load the new scene
    if scenes[sceneIndex].load then
        scenes[sceneIndex].load()
    end

    -- Set the current scene
    currentScene = sceneIndex
end


-- Global animations array
local animations = {
    {fromIndex = 0, toIndex = 0, fps = 1},  -- Idle animation
    {fromIndex = 0, toIndex = 1, fps = 6},   -- Walk animation
    {fromIndex = 1, toIndex = 1, fps = 1},      -- jumping
    {fromIndex = 2, toIndex = 2, fps = 1},   -- Punching animation
}

-- Player state
local players = {
    {
        characterIndex = 1,
        x = 100,
        y = 100,
        hp = 1,
        velocityY = 0,
        isOnGround = false,
        isFacingLeft = false,
        pounchTimer = 0,
        saTimer = 0,
        action = 0,
        xvel = 0,
        controls = {"w", "a", "d", "q","e"}
    },
    {
        characterIndex = 2,
        x = 200,
        y = 100,
        hp = 1,
        velocityY = 0,
        isOnGround = false,
        isFacingLeft = false,
        pounchTimer = 0,
        saTimer = 0,
        action = 0,
        xvel = 0,
        controls = {"i", "j", "l","u", "o"}
    },
    {
        characterIndex = 3,
        x = 200,
        y = 100,
        hp = 0,
        velocityY = 0,
        isOnGround = false,
        isFacingLeft = false,
        pounchTimer = 0,
        saTimer = 0,
        action = 0,
        xvel = 0,
        controls = {"up", "left", "right","kp0", "kp."}
    },
    {
        characterIndex = 4,
        x = 200,
        y = 100,
        hp = 0,
        velocityY = 0,
        isOnGround = false,
        isFacingLeft = false,
        pounchTimer = 0,
        saTimer = 0,
        action = 0,
        xvel = 0,
        controls = {"kp8", "kp4", "kp6","kp7", "kp9"}
    },
    -- Add entries for other players as needed
}
-- Character definitions
local characters = {
    {
        name = "Kris",
        spriteSheet = love.graphics.newImage("kris.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 600,
        height = 19,
        speed = 180,
        strength = 10,
        maxHp = 300,
        jumpVelocity = -400,
        specialAbilityName = "DamageBurst",
        specialAbility = function(player)
            local x1, y1 = player.x, player.y
            
            for _, otherPlayer in ipairs(players) do
                if otherPlayer ~= player then
                    local x2, y2 = otherPlayer.x, otherPlayer.y
                    local distance = math.sqrt((x1 - otherPlayer.x)^2 + (y1 - otherPlayer.y)^2)
                
                    if distance <= krisDamageRadius then
                        local dx, dy = x1 + x2, y1 + y2
                        local length = math.sqrt(dx^2 + dy^2)
                        local normalized_dx, normalized_dy = dx / length, dy / length
                        -- Apply damage to other players within the radius
                        otherPlayer.hp = math.floor(otherPlayer.hp - (krisDamageRadius - distance) / 7) -- Adjust the damage value as needed
                        otherPlayer.x = otherPlayer.x + normalized_dx * ((krisDamageRadius - distance) / 4)
                        otherPlayer.y = otherPlayer.y + normalized_dy * ((krisDamageRadius - distance) / 4)
                    end
                end
            end
        end
    },
    {
        name = "Susie",
        spriteSheet = love.graphics.newImage("susie.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 600,
        height = 25,
        speed = 200,
        strength = 12,
        maxHp = 420,
        jumpVelocity = -500,
        specialAbilityName = "LoveBait",
        specialAbility = function(player)
            local susieX, susieY = player.x, player.y
        
            for _, otherPlayer in ipairs(players) do
                if otherPlayer ~= player and otherPlayer.characterIndex == 3 then
                    local distance = math.sqrt((susieX - otherPlayer.x)^2 + (susieY - otherPlayer.y)^2)
        
                    if distance <= loveBaitRange then
                        -- Make the other player look at Susie and get a bit closer
                        local angle = (susieX - otherPlayer.x) / math.abs(susieX - otherPlayer.x)
                        otherPlayer.x = otherPlayer.x + angle * 5 -- Move 10 pixels closer
                        otherPlayer.isFacingLeft = angle == -1 
                    end
                end
            end
        end
    },
    {
        name = "Noelle",
        spriteSheet = love.graphics.newImage("noelle.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 600,
        height = 25,
        speed = 190,
        strength = 11,
        maxHp = 350,
        jumpVelocity = -400,

        specialAbilityName = "MagneticPush",
        specialAbility = function(currentPlayer)
            local x1, y1 = currentPlayer.x, currentPlayer.y
    
            for _, opponentPlayer in ipairs(players) do
                if opponentPlayer ~= currentPlayer then
                    local x2, y2 = opponentPlayer.x, opponentPlayer.y
                    local distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    
                    if distance <= gravityPushRange then
                        -- Calculate the direction vector
                        local dx, dy = x1 - x2, y1 - y2
                        local length = math.sqrt(dx^2 + dy^2)
                        local normalized_dx, normalized_dy = dx / length, dy / length
    
                        -- Update the opponent's position towards Noelle
                        opponentPlayer.x = opponentPlayer.x - normalized_dx * ((gravityPushRange - distance) / 2)
                        opponentPlayer.y = opponentPlayer.y - normalized_dy * ((gravityPushRange - distance) / 2)
                    end
                end
            end
        end
    },
    {
        name = "Ralsei",
        spriteSheet = love.graphics.newImage("ralsei.png"),
        numFrames = 4 * 4,  -- 4x4 frames in the spritesheet
        gravity = 600,
        height = 19,
        speed = 170,
        strength = 9,
        maxHp = 170,
        jumpVelocity = -400,
        specialAbilityName = "HealMyself",
        specialAbility = function(player)
            player.hp = math.max(170,player.hp + 10)
        end
    },
}

-- Function to take damage from the death zone
local function takeDamage(player, amount)
    player.hp = math.max(0, player.hp - amount)

    if player.hp <= 0 then
        standingPlayers = standingPlayers - 1
        if standingPlayers == 1 then
            transitionToScene(3)
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
        player.isOnGround = true
    else
        player.isOnGround = false
    end
    checkPlayerCollisions(players)

    -- Death zone
    if player.y > love.graphics.getHeight() - deathZoneHeight then
        player.y = love.graphics.getHeight() - deathZoneHeight
        player.velocityY = characters[player.characterIndex].jumpVelocity * 2  -- Shoot the player upwards
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
        if player.action < 3 and player.isOnGround then
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
            if love.keyboard.isDown(player.controls[1]) and player.isOnGround then
                player.velocityY = characters[player.characterIndex].jumpVelocity
                player.isOnGround = false
                player.action = 2
            end

            if love.keyboard.isDown(player.controls[2]) and player.x > 0 then
                player.x = player.x - characters[player.characterIndex].speed * dt
                player.isFacingLeft = true  -- Facing left
                if player.action == 0 then
                    player.action = 1
                end
                player.xvel = -1
            end

            if love.keyboard.isDown(player.controls[3]) and player.x < love.graphics.getWidth() - frameWidth then
                player.x = player.x + characters[player.characterIndex].speed * dt
                player.isFacingLeft = false  -- Facing right
                if player.action == 0 then
                    player.action = 1
                end
                player.xvel = 1
            end
        end

        -- Gravity
        player.velocityY = player.velocityY + characters[player.characterIndex].gravity * dt
        player.y = player.y + player.velocityY * dt

        -- Special ability activation
        if player.saTimer <= 0 then
            if love.keyboard.isDown(player.controls[5]) then
                activateSpecialAbility(player)
                player.saTimer = 3
            end
        else
            player.saTimer = player.saTimer - dt
        end
        -- Special ability activation
        if love.keyboard.isDown(player.controls[4]) then
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
    love.graphics.draw(pf, platform.x, platform.y - 30)
    for _, player in ipairs(players) do
        if player.hp ~= 0 then
            drawPlayer(player)
        end
    end
end
-- Widget system functions
local function createButton(x, y, width, height, text, onClick)
    return {x = x, y = y, width = width, height = height, text = text, onClick = onClick}
end

local function drawButton(button)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
    love.graphics.print(button.text, button.x + 10, button.y + 10)
end

local function handleMouseClick(x, y)
    for _, widget in ipairs(widgets) do
        if x > widget.x and x < widget.x + widget.width and
           y > widget.y and y < widget.y + widget.height then
            widget.onClick(_)
        end
    end
end

-- Main menu scene
scenes[1] = {
    load = function()
        -- Add buttons to the widget system
        widgets = {
            createButton(love.graphics.getWidth() / 2 - 50, love.graphics.getHeight() / 2 + 50, 100, 40, "Start Game", function()
                transitionToScene(2) -- Transition to character selection
            end),
        }
    end,
    draw = function()
        love.graphics.setFont(victoryFont)
        love.graphics.print("Deltarune Fighting Thing", love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() / 2 - 50)
        love.graphics.setFont(love.graphics.newFont())

        -- Draw buttons using the widget system
        for _, widget in ipairs(widgets) do
            drawButton(widget)
        end
    end,
    mousepressed = function(x, y, button, istouch, presses)
        -- Handle mouse click for main menu using the widget system
        handleMouseClick(x, y)
    end,
}

-- Character selection scene
local selectedPlayerIndex = 1
local currentTab = 1
function love.keypressed(key)
    if isRebinding and currentScene == 2 then
        players[selectedPlayerIndex].controls[keyBeingRebound] = key
        isRebinding = false
        scenes[2]:load() -- reload button labels
    end
end

scenes[2] = {
    load = function()
        -- Clear existing buttons
        widgets = {}

        -- Add common buttons to the widget system
        table.insert(widgets, createButton(50, love.graphics.getHeight() - 60, 100, 40, "Back", function()
            transitionToScene(1) -- Transition to main menu
        end))
        table.insert(widgets, createButton(love.graphics.getWidth() - 150, love.graphics.getHeight() - 60, 127, 40, "Start Game", function()
            transitionToScene(4) -- Transition to the main game
            for i, v in ipairs(players) do
                if v.hp > 0 then
                    standingPlayers = standingPlayers + 1
                end
                
            end
        end))
        table.insert(widgets, createButton(50, 80, 160, 40, "Character Tab", function()
            currentTab = 1
            scenes[2]:load() -- Reload buttons for the current tab
        end))
        table.insert(widgets, createButton(230, 80, 160, 40, "Controls Tab", function()
            currentTab = 2
            scenes[2]:load() -- Reload buttons for the current tab
        end))
        -- Add buttons for each player
        for i, player in ipairs(players) do
            if player.hp == 1 then
                player.hp = characters[player.characterIndex].maxHp
            end
            local button = createButton(50 + (i - 1) * 180, 20, 160, 40, "Player " .. i, function()
                selectedPlayerIndex = i
                scenes[2]:load() -- reload button labels
            end)
            table.insert(widgets, button)
        end

        -- Add tab-specific buttons
        if currentTab == 1 then

            if players[selectedPlayerIndex].hp == 0 then
                table.insert(widgets, createButton(50, 180, 185, 40, "Enable Player #" .. selectedPlayerIndex, function()
                    players[selectedPlayerIndex].hp = characters[players[selectedPlayerIndex].characterIndex].maxHp
                    scenes[2]:load() -- Reload buttons for the current tab
                end))
            else
                -- Add buttons for each character on the left
                for i, character in ipairs(characters) do
                    local button = createButton(50, 180 + i * 50, 160, 40, character.name, function()
                        players[selectedPlayerIndex].characterIndex = i
                        players[selectedPlayerIndex].hp = characters[i].maxHp
                        scenes[2]:load() -- Reload buttons for the current tab
                    end)
                    table.insert(widgets, button)
                end
            end
        elseif currentTab == 2 then
            if players[selectedPlayerIndex].hp == 0 then
                table.insert(widgets, createButton(50, 180, 185, 40, "Enable Player #" .. selectedPlayerIndex, function()
                    players[selectedPlayerIndex].hp = characters[players[selectedPlayerIndex].characterIndex].maxHp
                    scenes[2]:load() -- Reload buttons for the current tab
                end))
            else
                -- Add fixed buttons for controls rebinding
                local controls = {"Jump", "Left", "Right", "Special", "Punch"}
                for i, control in ipairs(controls) do
                    local button = createButton(50, 180 + i * 50, 160, 40, control .. " : " .. players[selectedPlayerIndex].controls[i], function()
                        isRebinding = true
                        keyBeingRebound = i
                    end)
                    table.insert(widgets, button)
                end
            end
        end
    end,
    draw = function()
        love.graphics.setColor(1, 1, 1) -- Reset color
        love.graphics.setFont(characterSelectionFont)

        -- Draw buttons using the widget system
        for _, widget in ipairs(widgets) do
            drawButton(widget)
        end

        love.graphics.setColor(1, 1, 1) -- Reset color

        -- Display selected player info
        love.graphics.print("Selected Player: " .. selectedPlayerIndex, 50, 140)

        -- Draw content based on the current tab
        if currentTab == 1 and players[selectedPlayerIndex].hp ~= 0 then
            -- Display character info
            love.graphics.print("Character: " .. characters[players[selectedPlayerIndex].characterIndex].name, 500, 400)
            love.graphics.print("Special Ability: " .. characters[players[selectedPlayerIndex].characterIndex].specialAbilityName, 500, 420)
            love.graphics.print("MaxHP: " .. characters[players[selectedPlayerIndex].characterIndex].maxHp, 500, 440)
            love.graphics.print("Strength: " .. characters[players[selectedPlayerIndex].characterIndex].strength, 500, 460)
            love.graphics.print("Speed: " .. characters[players[selectedPlayerIndex].characterIndex].speed, 500, 480)

            -- Draw animation display for the walking animation at 3x scale on the right
            local character = characters[players[selectedPlayerIndex].characterIndex]
            local currentAnimation = animations[2] -- Walking animation
            local frameCount = currentAnimation.toIndex - currentAnimation.fromIndex + 1
            local currentFrame = currentAnimation.fromIndex + (math.floor(love.timer.getTime() * currentAnimation.fps) % frameCount + 1)
            local frameX = (currentFrame - 1) % 4 * frameWidth
            local frameY = math.floor((currentFrame - 1) / 4) * frameHeight

            -- Set the mag filter to nearest for pixel art
            character.spriteSheet:setFilter("nearest", "nearest")

            love.graphics.draw(
                character.spriteSheet,
                love.graphics.newQuad(frameX, frameY, frameWidth, frameHeight,
                character.spriteSheet),
                600, 250,
                0,  -- Rotation angle
                3,  -- Scale
                3,
                frameWidth / 2,
                frameHeight / 2
            )
        elseif currentTab == 2 and players[selectedPlayerIndex].hp ~= 0 then
            -- Display controls rebinding UI
            love.graphics.print("Controls Tab", 50, 170)
            love.graphics.print("Select a control to rebind", 50, 190)
        end
    end,
    mousepressed = function(x, y, button, istouch, presses)
        -- Handle mouse click for character selection using the widget system
        handleMouseClick(x, y)
    end,
}





-- Victory menu scene
scenes[3] = {
    load = function()
        -- Add buttons to the widget system
        widgets = {
            createButton(love.graphics.getWidth() / 2 - 50, love.graphics.getHeight() / 2 + 50, 100, 40, "Back to Main Menu", function()
                transitionToScene(1) -- Transition to main menu
            end),
        }
    end,
    draw = function()
        love.graphics.setColor(platformColor)
        love.graphics.setFont(victoryFont)
        love.graphics.print("VICTORY!", love.graphics.getWidth() / 2, love.graphics.getHeight() / 2 - 50)

        for i, p in ipairs(players) do
            if p.hp ~= 0 then
                love.graphics.print(characters[p.characterIndex].name .. " Won!", love.graphics.getWidth() / 2, (love.graphics.getHeight() / 2) + 1)
                break
            end
        end
        love.graphics.setFont(love.graphics.newFont())
        love.graphics.setColor(1,1,1)

        -- Draw buttons using the widget system
        for _, widget in ipairs(widgets) do
            drawButton(widget)
        end
    end,
    mousepressed = function(x, y, button, istouch, presses)
        -- Handle mouse click for victory menu using the widget system
        handleMouseClick(x, y)
    end,
}
-- Main game scene
scenes[4] = {
    load = function()
        -- No additional widgets for the main game scene
    end,
    update = function(dt)
        for _, player in ipairs(players) do
            handlePlayerMovement(player, dt)
        end
    end,
    draw = function()
        love.graphics.draw(bg,0,0)
        drawGame()
    end,
    mousepressed = function(x, y, button, istouch, presses)
        -- Handle mouse click for main game using the widget system
        handleMouseClick(x, y)
    end,
}

-- ... (rest of the code)

function love.load()
    love.window.setTitle("Deltarune Fighting thing IDFK")
    love.graphics.setBackgroundColor(bgColor) -- Set background color
    transitionToScene(1)
end

-- Modify the love.update and love.draw functions
function love.update(dt)
    if scenes[currentScene].update then
        scenes[currentScene].update(dt)
    end
end

function love.draw()
    if scenes[currentScene].draw then 
        scenes[currentScene].draw()
    end
end

-- Modify the love.mousepressed function
function love.mousepressed(x, y, button, istouch, presses)
    if scenes[currentScene].mousepressed then
        scenes[currentScene].mousepressed(x, y, button, istouch, presses)
    end
end