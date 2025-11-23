--!strict
-- Roblox Plugin: Object Inspector + GUI Converter
-- Выбирает любой объект и выводит/сохраняет все его свойства в LocalScript
-- Если выбран ScreenGui, также рекурсивно конвертирует GUI

local Toolbar = plugin:CreateToolbar("Object Inspector")
local Button = Toolbar:CreateButton("Open Inspector", "Open Object Inspector", "")

local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local WidgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    true,
    true,
    500,
    300,
    200,
    150
)

local Widget = plugin:CreateDockWidgetPluginGui("ObjectInspectorWidget", WidgetInfo)
Widget.Title = "Object Inspector"

local FrameUI = Instance.new("Frame")
FrameUI.Size = UDim2.new(1, 0, 1, 0)
FrameUI.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
FrameUI.Parent = Widget

local ConvertBtn = Instance.new("TextButton")
ConvertBtn.Size = UDim2.new(0, 460, 0, 40)
ConvertBtn.Position = UDim2.new(0, 20, 0, 20)
ConvertBtn.Text = "Inspect Selected Object"
ConvertBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ConvertBtn.TextColor3 = Color3.new(1,1,1)
ConvertBtn.Parent = FrameUI

-- Serialize value utility
local function serializeValue(v)
    if typeof(v) == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", v.R*255, v.G*255, v.B*255)
    elseif typeof(v) == "UDim2" then
        return string.format("UDim2.new(%s,%s,%s,%s)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif typeof(v) == "UDim" then
        return string.format("UDim.new(%s, %s)", v.Scale, v.Offset)
    elseif typeof(v) == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z)
    elseif typeof(v) == "CFrame" then
        return string.format("CFrame.new(%s, %s, %s)", v.X, v.Y, v.Z)
    elseif typeof(v) == "string" then
        return string.format("%q", v)
    elseif typeof(v) == "number" or typeof(v) == "boolean" then
        return tostring(v)
    end
    return "nil"
end

-- Inspect object and generate Lua code
local function inspectObject(obj)
    local lines = {}
    local varName = obj.Name:gsub("%s+", "_") .. "_" .. HttpService:GenerateGUID(false):gsub("-", "")
    table.insert(lines, string.format("local %s = %s", varName, obj.ClassName == "ScreenGui" and "Instance.new(\"ScreenGui\")" or "Instance.new(\""..obj.ClassName.."\")"))

    -- Get all known properties
    local success, props = pcall(function() return obj:GetAttributes() end)
    if success then
        for k,v in pairs(props) do
            table.insert(lines, string.format("%s:SetAttribute(%q, %s)", varName, k, serializeValue(v)))
        end
    end

    local commonProps = {"WalkSpeed","JumpPower","Health","Pitch","Transparency","Anchored","Size","Position","CFrame","Orientation"}
    for _, prop in ipairs(commonProps) do
        local ok, val = pcall(function() return obj[prop] end)
        if ok then
            table.insert(lines, string.format("%s.%s = %s", varName, prop, serializeValue(val)))
        end
    end

    -- LocalScripts inside
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("LocalScript") then
            local sVar = "LocalScript_" .. HttpService:GenerateGUID(false):gsub("-", "")
            table.insert(lines, string.format("local %s = Instance.new(\"LocalScript\")", sVar))
            table.insert(lines, string.format("%s.Source = [[%s]]", sVar, child.Source:gsub("]%]", "]]%]")))
            table.insert(lines, string.format("%s.Parent = %s", sVar, varName))
        end
    end

    -- If it's ScreenGui, recursively copy GUI elements
    if obj:IsA("ScreenGui") then
        for _, child in ipairs(obj:GetChildren()) do
            if not child:IsA("LocalScript") then
                local childLines = inspectObject(child)
                for _, l in ipairs(childLines) do table.insert(lines, l) end
                table.insert(lines, string.format("%s.Parent = %s", child.Name:gsub("%s+", "_") .. "_" .. HttpService:GenerateGUID(false):gsub("-", ""), varName))
            end
        end
    end

    -- Set parent
    if obj:IsA("ScreenGui") then
        table.insert(lines, string.format("%s.Parent = game.Players.LocalPlayer:WaitForChild(\"PlayerGui\")", varName))
    end

    return lines
end

ConvertBtn.MouseButton1Click:Connect(function()
    local selected = Selection:Get()
    if #selected == 0 then warn("Nothing selected!") return end
    local obj = selected[1]

    local codeLines = inspectObject(obj)
    local scriptCode = table.concat(codeLines, "\n")

    local newScript = Instance.new("LocalScript")
    newScript.Name = "InspectedObject"
    newScript.Source = scriptCode
    newScript.Parent = StarterGui
    print("Object inspection script created in StarterGui")
end)

Button.Click:Connect(function()
    Widget.Enabled = not Widget.Enabled
end)
