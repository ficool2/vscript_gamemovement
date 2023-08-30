// Example script that runs VScript Gamemovement on the local host
// cl_smoothtime 0.05 is recommended to prevent too much smoothing from prediction

IncludeScript("gamemovement");

const IN_FORWARD = 8;
const IN_BACK = 16;
const IN_MOVELEFT = 512;
const IN_MOVERIGHT = 1024;
const MOVETYPE_NONE = 0;

// default values from client
cl_forwardspeed <- 450;
cl_backspeed <- 450;
cl_sidespeed <- 450;
cl_upspeed <- 320;

function AddPlayerMovement(player)
{
	player.ValidateScriptScope();
	player.GetScriptScope().movement <- CGameMovement(player, Vector(-24, -24, 0), Vector(24, 24, 82), 320.0);
	AddThinkToEnt(player, "OnPlayerThink");
}

function OnPlayerThink()
{
	if (NetProps.GetPropInt(self, "m_lifeState") != 0)
		return -1;
	
	if (self.GetMoveType() != MOVETYPE_NONE)
		self.SetMoveType(MOVETYPE_NONE, 0);
	
	local buttons = NetProps.GetPropInt(self, "m_nButtons");	
	movement.m_nButtons = buttons;
			
	local forward = 0.0;
	if (buttons & IN_FORWARD)
		forward += cl_forwardspeed;
	if (buttons & IN_BACK)
		forward -= cl_forwardspeed;
	movement.m_flForwardMove = forward;

	local side = 0.0;
	if (buttons & IN_MOVERIGHT)
		side += cl_sidespeed;
	if (buttons & IN_MOVELEFT)
		side -= cl_sidespeed;
	movement.m_flSideMove = side;
		
	movement.ProcessMovement(self.GetOrigin(), self.EyeAngles(), self.GetAbsVelocity(), DEFAULT_TICKRATE);
	
	ShowMovementInfo();
	
	self.SetAbsOrigin(movement.m_vecAbsOrigin);
	self.SetAbsVelocity(movement.m_vecVelocity);
	
	return -1;
}

function ShowMovementInfo()
{
	local i = 0;
	local x = 0.4, y = 0.6;
	local duration = 0.03;
	local m = movement;
	
	DebugDrawScreenTextLine(
		x, y, i++,
		format("origin: %f %f %f", m.m_vecAbsOrigin.x, m.m_vecAbsOrigin.y, m.m_vecAbsOrigin.z), 
		255, 255, 255, 255, duration
	);
	DebugDrawScreenTextLine(
		x, y, i++,
		format("angles: %f %f %f", m.m_vecViewAngles.x, m.m_vecViewAngles.y, m.m_vecViewAngles.z), 
		255, 255, 255, 255, duration
	);
	DebugDrawScreenTextLine(
		x, y, i++,
		format("velocity: %f %f %f", m.m_vecVelocity.x, m.m_vecVelocity.y, m.m_vecVelocity.z), 
		255, 255, 255, 255, duration
	);
	DebugDrawScreenTextLine(
		x, y, i++,
		format("basevelocity: %f %f %f", m.m_vecBaseVelocity.x, m.m_vecBaseVelocity.y, m.m_vecBaseVelocity.z), 
		255, 255, 255, 255, duration
	);		
	DebugDrawScreenTextLine(
		x, y, i++,
		format("forward: %g", m.m_flForwardMove),
		255, 255, 0, 255, duration
	);
	DebugDrawScreenTextLine(
		x, y, i++,
		format("side: %g", m.m_flSideMove),
		255, 255, 0, 255, duration
	);
	DebugDrawScreenTextLine(
		x, y, i++,
		format("ground: %s", m.m_ground ? m.m_ground.tostring() : "null"),
		0, 255, 255, 255, duration
	);	
	DebugDrawScreenTextLine(
		x, y, i++,
		format("speed: %g", m.m_vecVelocity.Length2D()),
		0, 255, 0, 255, duration
	);	
}

AddPlayerMovement(GetListenServerHost());