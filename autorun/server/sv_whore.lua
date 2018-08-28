-- # https://github.com/PAC3-Server/notagain/blob/master/lua/notagain/essential/autorun/server/net_receive_protection.lua
local SysTime = SysTime
local RealTime = RealTime

local function warn(ply, fmt, ...)
	ply.net_incoming_last_print_suppress = ply.net_incoming_last_print_suppress or {}
	ply.net_incoming_last_print_suppress[fmt] = ply.net_incoming_last_print_suppress[fmt] or RealTime()

	if ply.net_incoming_last_print_suppress[fmt] < RealTime() then
		ply.net_incoming_last_print_suppress[fmt] = RealTime() + 0.5

		fmt = fmt:Replace("PLAYER", ply:Nick() .. "( " .. ply:SteamID() .. " )")
		local str = fmt:format(...)
		MsgN("[net] " .. str)
	end
end

local function punish(ply, sec)
	ply.net_incoming_suppress = SysTime() + sec
	warn(ply, "dropping net messages from PLAYER for %f seconds", sec)
end

function net.Incoming(length, ply)
	do -- rate limit
		ply.net_incoming_rate_count = (ply.net_incoming_rate_count or 0) + 1
		ply.net_incoming_rate_next_check = ply.net_incoming_rate_next_check or 0

		if ply.net_incoming_rate_next_check < RealTime() then
			if ply.net_incoming_rate_count > 100 then
				warn(ply, "PLAYER is sending more than 100 net messages a second", ply)
				punish(ply, 2)
			end

			ply.net_incoming_rate_count = 0
			ply.net_incoming_rate_next_check = RealTime() + 1
		end
	end

	if ply.net_incoming_suppress and ply.net_incoming_suppress > SysTime() then
		return
	end

	do -- gmod's net.Incoming
		local i = net.ReadHeader()
		local id = util.NetworkIDToString(i)

		if id then
			local func = net.Receivers[id:lower()]

			if func then
				local ok = xpcall(
					func,
					function(msg)
						ErrorNoHalt(debug.traceback(("net message %q (%s) from %s (%s) errored:"):format(id, string.NiceSize(length), tostring(ply), ply:SteamID())))
					end,
					length - 16,
					ply
				)

				if not ok then
					punish(ply, 1)
				end
			end
		end
	end
end

-- # https://github.com/PAC3-Server/notagain/blob/master/lua/notagain/essential/autorun/server/fixPrecisionCrash.lua
local function precisionToolFix()
	local stool = weapons.Get('gmod_tool')
	local swep = stool.Tool['precision']

	if !swep then return end -- If the swep doesn't exist never run.

	swep.OldLeftClick = swep.OldLeftClick or swep.LeftClick
	swep.OldDoConstraint = swep.OldDoConstraint or swep.DoConstraint
	swep.OldDoMove = swep.OldDoMove or swep.DoMove

	function swep:LeftClick(trace)
		local cantool = 0
		local owner = self:GetOwner()
		local mode = self:GetClientNumber( "mode" )

		if mode == 4 then
			cantool = hook.Run("CanTool", owner, owner:GetEyeTrace(), "weld")
		elseif mode == 5 then
			cantool = hook.Run("CanTool", owner, owner:GetEyeTrace(), "axis")
		elseif mode == 6 then
			cantool = hook.Run("CanTool", owner, owner:GetEyeTrace(), "ballsocket")
		elseif mode == 7 then
			cantool = hook.Run("CanTool", owner, owner:GetEyeTrace(), "ballsocket")
		elseif mode == 8 then
			cantool = hook.Run("CanTool", owner, owner:GetEyeTrace(), "slider")
		end

		if cantool == false then
			self:Holster()
		else
			self:OldLeftClick(trace)
		end
	end

	function swep:DoConstraint(mode)
		local hitEnt = self:GetEnt(1)
		constraint.RemoveAll(hitEnt)
		self:OldDoConstraint(mode)
	end

	function swep:DoMove()
		local PhysA, PhysB = self:GetPhys(1), self:GetPhys(2)

		self:OldDoMove()

		PhysA:Sleep()
		PhysB:Sleep()
	end

	weapons.Register(stool,'gmod_tool')

	for _,v in next, ents.FindByClass('gmod_tool') do
	    v:Initialize()
	    v:Activate()
	end
end
hook.Add("PostGamemodeLoaded", "precision_fix", precisionToolFix)