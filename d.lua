repeat wait() until game:IsLoaded()

-- Services
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- Notification
StarterGui:SetCore("SendNotification", {
	Title = "Leap Exploits",
	Text = "Subscribe to Leap Exploits",
	Duration = 4
})

-- Request handler
local Request = (syn and syn.request) or request or http_request

-- GUI setup
if game.CoreGui:FindFirstChild("SniperGUI") then game.CoreGui.SniperGUI:Destroy() end
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "SniperGUI"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 250, 0, 150)
frame.Position = UDim2.new(0.35, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderColor3 = Color3.fromRGB(70, 70, 70)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame)

local function createBox(y, placeholder, default)
	local box = Instance.new("TextBox", frame)
	box.Size = UDim2.new(0.9, 0, 0.3, 0)
	box.Position = UDim2.new(0.05, 0, y, 0)
	box.PlaceholderText = placeholder
	box.Text = default or ""
	box.TextScaled = true
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.TextColor3 = Color3.fromRGB(170, 170, 170)
	box.BorderColor3 = Color3.fromRGB(50, 50, 50)
	return box
end

local placeBox = createBox(0.05, "Place ID (readonly)", tostring(game.PlaceId))
placeBox.ClearTextOnFocus = false
placeBox.TextEditable = false

local userBox = createBox(0.4, "Username or UserId")

local btn = Instance.new("TextButton", frame)
btn.Size = UDim2.new(0.9, 0, 0.3, 0)
btn.Position = UDim2.new(0.05, 0, 0.7, 0)
btn.Text = "Snipe (Teleport)"
btn.TextScaled = true
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btn.TextColor3 = Color3.fromRGB(170, 170, 170)
btn.BorderColor3 = Color3.fromRGB(70, 70, 70)

-- Avatar fetch function
local function getAvatar(userId)
	local res = Request({
		Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. userId .. "&size=150x150&format=Png",
		Method = "GET"
	})
	local data = HttpService:JSONDecode(res.Body)
	return data.data and data.data[1] and data.data[1].imageUrl or nil
end

-- Safe token fetcher with pagination and error handling
local function fetchTokens(placeId, maxPages)
	local tokens, cursor, pages = {}, "", 0
	while true do
		local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/0?limit=100"
		if cursor ~= "" then url = url .. "&cursor=" .. cursor end

		local success, response = pcall(function()
			return Request({Url = url, Method = "GET"})
		end)
		if not success or not response then
			btn.Text = "Failed @ page " .. pages
			break
		end

		local ok, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
		if not ok or not data or not data.data then
			btn.Text = "Data error @ page " .. pages
			break
		end

		for _, server in ipairs(data.data) do
			if server.playerTokens then
				for _, token in ipairs(server.playerTokens) do
					table.insert(tokens, {placeId, server.id, token})
				end
			end
		end

		pages += 1
		btn.Text = "Scanning page " .. pages

		if not data.nextPageCursor or pages >= maxPages then break end
		cursor = data.nextPageCursor
		task.wait(0.15)
	end
	return tokens
end

-- Batch check tokens for matching avatar
local function checkBatch(batch, targetImage)
	local payload = {}
	for _, entry in ipairs(batch) do
		table.insert(payload, {
			requestId = "0:" .. entry[3] .. ":AvatarHeadshot:150x150:png:regular",
			type = "AvatarHeadShot",
			token = entry[3],
			format = "png",
			size = "150x150"
		})
	end

	local res = Request({
		Url = "https://thumbnails.roblox.com/v1/batch",
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = HttpService:JSONEncode(payload)
	})
	local decoded = HttpService:JSONDecode(res.Body)
	for i, v in ipairs(decoded.data) do
		if v.imageUrl == targetImage then
			local entry = batch[i]
			return entry[1], entry[2]
		end
	end
end

-- Process batches of tokens
local function runBatches(tokens, image)
	for i = 1, #tokens, 100 do
		local batch = {}
		for j = i, math.min(i + 99, #tokens) do
			table.insert(batch, tokens[j])
		end
		local pid, sid = checkBatch(batch, image)
		if pid and sid then return pid, sid end
		task.wait(0.05)
	end
end

-- Main sniper function (auto TP mode)
local function run(placeId, target)
	btn.Text = "Loading..."
	local userId = tonumber(target)
	if not userId then
		local ok, uid = pcall(function()
			return Players:GetUserIdFromNameAsync(target)
		end)
		if not ok then
			btn.Text = "Invalid username"
			task.delay(2, function() btn.Text = "Snipe (Teleport)" end)
			return
		end
		userId = uid
	end

	local image = getAvatar(userId)
	if not image then
		btn.Text = "Avatar error"
		task.delay(2, function() btn.Text = "Snipe (Teleport)" end)
		return
	end

	btn.Text = "Fetching servers..."
	local tokens = fetchTokens(placeId, 1000)
	if #tokens == 0 then
		btn.Text = "No servers found"
		task.delay(2, function() btn.Text = "Snipe (Teleport)" end)
		return
	end

	btn.Text = "Matching avatar..."
	local pid, sid = runBatches(tokens, image)
	if pid and sid then
		btn.Text = "Found! Teleporting..."
		TeleportService:TeleportToPlaceInstance(pid, sid)
	else
		btn.Text = "Player not found"
		task.delay(2, function() btn.Text = "Snipe (Teleport)" end)
	end
end

-- Button click handler
btn.MouseButton1Click:Connect(function()
	local place = tonumber(placeBox.Text)
	local target = userBox.Text
	if not place or #target < 2 then
		btn.Text = "Invalid input"
		task.delay(2, function() btn.Text = "Snipe (Teleport)" end)
		return
	end
	task.spawn(function()
		run(place, target)
	end)
end)

-- Hotkey to toggle GUI
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.RightShift then
		gui.Enabled = not gui.Enabled
	end
end)
