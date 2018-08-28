if (SERVER) then 
	AddCSLuaFile("autorun/sh_whore.lua")
end

-- # https://github.com/chuteuk/NetReadDataFix
local whoreReadData = net.ReadData
local maxLen = 62000
function net.ReadData(len)
	local size = len
	local clamp = math.Clamp(len, 0, maxLen)
	if (size > clamp) then
		MsgC(Color(255,0,255,255), Format("[NET] net.ReadData size: %d > maxLen: %d|%d\n", size, clamp, maxLen))
	end
	return whoreReadData(clamp) -- # maximum size of a net message (maxLen bytes)
end