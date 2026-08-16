-- Create a ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Create the popup frame
local popup = Instance.new("Frame")
popup.Size = UDim2.new(0, 250, 0, 150)
popup.Position = UDim2.new(0.5, -125, 0.5, -75)
popup.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
popup.Parent = screenGui

-- Title label
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
title.Text = "Current Held Item"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = popup

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 80, 0, 30)
closeBtn.Position = UDim2.new(0, 10, 1, -40)
closeBtn.Text = "Close"
closeBtn.Parent = popup

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 80, 0, 30)
minimizeBtn.Position = UDim2.new(1, -90, 1, -40)
minimizeBtn.Text = "Minimize"
minimizeBtn.Parent = popup

-- Label to show held item
local heldItemLabel = Instance.new("TextLabel")
heldItemLabel.Size = UDim2.new(1, -20, 0, 60)
heldItemLabel.Position = UDim2.new(0, 10, 0, 50)
heldItemLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
heldItemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
heldItemLabel.TextWrapped = true
heldItemLabel.Text = "No item equipped."
heldItemLabel.Parent = popup

-- Button actions
closeBtn.MouseButton1Click:Connect(function()
    popup.Visible = false
end)

minimizeBtn.MouseButton1Click:Connect(function()
    if popup.Size == UDim2.new(0, 250, 0, 150) then
        popup.Size = UDim2.new(0, 250, 0, 30)
    else
        popup.Size = UDim2.new(0, 250, 0, 150)
    end
end)

-- Function to update held item
local function updateHeldItem()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()

    -- Look for any Tool object inside the character
    local tool = character:FindFirstChildWhichIsA("Tool")
    if tool then
        heldItemLabel.Text = "Holding: " .. tool.Name
    else
        heldItemLabel.Text = "No item equipped."
    end
end

-- Connect events to detect when tools are equipped/unequipped
local player = game.Players.LocalPlayer
player.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            updateHeldItem()
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            updateHeldItem()
        end
    end)
end)

-- Initial check
updateHeldItem()
