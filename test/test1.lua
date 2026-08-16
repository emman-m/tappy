-- Create a ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Create the popup frame
local popup = Instance.new("Frame")
popup.Size = UDim2.new(0, 250, 0, 200)
popup.Position = UDim2.new(0.5, -125, 0.5, -100) -- center
popup.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
popup.Parent = screenGui

-- Title label
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
title.Text = "Storage Bag"
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

-- Storage bag (table to hold items)
local storageBag = {}

-- Add Item button
local addItemBtn = Instance.new("TextButton")
addItemBtn.Size = UDim2.new(0, 180, 0, 30)
addItemBtn.Position = UDim2.new(0.5, -90, 0, 40)
addItemBtn.Text = "Add Item to Bag"
addItemBtn.Parent = popup

-- Label to show bag contents
local bagContents = Instance.new("TextLabel")
bagContents.Size = UDim2.new(1, -20, 0, 80)
bagContents.Position = UDim2.new(0, 10, 0, 80)
bagContents.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bagContents.TextColor3 = Color3.fromRGB(255, 255, 255)
bagContents.TextWrapped = true
bagContents.Text = "Bag is empty."
bagContents.Parent = popup

-- Button actions
closeBtn.MouseButton1Click:Connect(function()
    popup.Visible = false
end)

minimizeBtn.MouseButton1Click:Connect(function()
    if popup.Size == UDim2.new(0, 250, 0, 200) then
        popup.Size = UDim2.new(0, 250, 0, 30) -- shrink to title bar
    else
        popup.Size = UDim2.new(0, 250, 0, 200) -- restore
    end
end)

-- Function to update bag contents label
local function updateBagLabel()
    if #storageBag == 0 then
        bagContents.Text = "Bag is empty."
    else
        local text = "Items in Bag:\n"
        for i, item in ipairs(storageBag) do
            text = text .. i .. ". " .. item .. "\n"
        end
        bagContents.Text = text
    end
end

-- Add item button logic
addItemBtn.MouseButton1Click:Connect(function()
    local newItem = "HealthPotion" -- example item
    table.insert(storageBag, newItem)
    updateBagLabel()
end)
