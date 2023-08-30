// Made by ficool2

if (this != getroottable())
{
	printl("gamemovement.nut must be included in root scope. e.g. IncludeScript(\"gamemovement.nut\", getroottable())");
	return;
}

AXES <- ["x", "y", "z"];
DEFAULT_TICKRATE <- 0.015;
const MASK_PLAYERSOLID = 33636363; // CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_PLAYERCLIP|CONTENTS_WINDOW|CONTENTS_MONSTER|CONTENTS_GRATE;

// use manually defined constants for speed
const MOVETYPE_NONE = 0;
const MOVETYPE_ISOMETRIC = 1;
const MOVETYPE_WALK = 2;
const MOVETYPE_NOCLIP = 8;
const MOVETYPE_LADDER = 9;
const MOVETYPE_OBSERVER = 10;
const COLLISION_GROUP_PLAYER_MOVEMENT = 8;
const IN_JUMP = 2;
const DIST_EPSILON = 0.03125;

WORLD <- Entities.FindByClassname(null, "worldspawn");

class CGameMovement
{
	function constructor(_player, mins, maxs, maxspeed)
	{
		player = _player;

		m_movetype = MOVETYPE_WALK;
		m_vecBaseVelocity = Vector();
		m_surfaceFriction = 1.0;
		
		m_vecPlayerMins = mins;
		m_vecPlayerMaxs = maxs;
		m_flMaxSpeed = maxspeed;
		
		// movedata
		m_vecAbsOrigin = Vector();
		m_vecVelocity = Vector();

		m_nOldButtons = 0;
		m_flOldForwardMove = 0.0;
		
		sv_gravity = Convars.GetFloat("sv_gravity");
		sv_maxvelocity = Convars.GetFloat("sv_maxvelocity");
		sv_friction = Convars.GetFloat("sv_Friction");
		sv_stopspeed = Convars.GetFloat("sv_stopspeed");
		sv_accelerate = Convars.GetFloat("sv_accelerate");
		sv_airaccelerate = Convars.GetFloat("sv_airaccelerate");
		sv_bounce = Convars.GetFloat("sv_bounce");
		sv_stepsize = Convars.GetFloat("sv_stepsize");
		// TF value, HL2 value is 268.3281572999747
		sv_jump_impulse = 289.0;
	}
	
	function CheckParameters()
	{
		if (m_movetype != MOVETYPE_ISOMETRIC &&
			m_movetype != MOVETYPE_NOCLIP &&
			m_movetype != MOVETYPE_OBSERVER)
		{
			local spd = (m_flForwardMove * m_flForwardMove) + (m_flSideMove * m_flSideMove);
			if (spd != 0.0 && (spd > m_flMaxSpeed * m_flMaxSpeed))
			{
				local fRatio = m_flMaxSpeed / sqrt(spd);
				m_flForwardMove *= fRatio;
				m_flSideMove *= fRatio;
			}
		}
	}

	function CheckVelocity()
	{
		foreach (i in AXES)
		{
			if (m_vecVelocity[i] > sv_maxvelocity)
				m_vecVelocity[i] = sv_maxvelocity;
			else if (m_vecVelocity[i] < -sv_maxvelocity)
				m_vecVelocity[i] = -sv_maxvelocity;
		}
	}
	
	function CheckJumpButton()
	{
		if (m_ground == null)
		{
			m_nOldButtons = m_nOldButtons | IN_JUMP;
			return false;
		}
		
		if (m_nOldButtons & IN_JUMP)
			return false;
			
		SetGroundEntity(null);
		
		m_vecVelocity.z += sv_jump_impulse;
		
		FinishGravity();
		
		m_nOldButtons = m_nOldButtons | IN_JUMP;
		return true;
	}
	
	function CategorizePosition()
	{
		m_surfaceFriction = 1.0;
		
		local origin = m_vecAbsOrigin;
		local point = Vector(origin.x, origin.y, origin.z - 2.0);
		
		local zvel = m_vecVelocity.z;
		local bMovingUp = zvel > 0.0;
		local bMovingUpRapidly = zvel > 140.0;
		
		if (bMovingUpRapidly && m_ground && m_ground != WORLD)
			bMovingUpRapidly = (zvel - (m_ground.IsValid() ? m_ground.GetAbsVelocity().z : Vector())) > 140.0;
		
		if (bMovingUpRapidly || (bMovingUp && m_movetype == MOVETYPE_LADDER))   
		{
			SetGroundEntity(null);
		}
		else
		{
			local pm = {};
			TryTouchGround(origin, point, m_vecPlayerMins, m_vecPlayerMaxs, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, pm);
			
			if (!pm.enthit || pm.plane_normal.z < 0.7)
			{
				TryTouchGroundInQuadrants(origin, point, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, pm);

				if (!pm.enthit || pm.plane_normal.z < 0.7)
				{
					SetGroundEntity(null);
					
					if (m_vecVelocity.z > 0.0 && m_movetype != MOVETYPE_NOCLIP)
						m_surfaceFriction = 0.25;
				}
				else
				{
					SetGroundEntity(pm);
				}
			}
			else
			{
				SetGroundEntity(pm);
			}
		}
	}
	
	function SetGroundEntity(pm)
	{
		local newGround = pm ? pm.enthit : null;
		local oldGround = m_ground;
		
		if (oldGround && newGround)
		{
			if (newGround == WORLD)
			{
				m_vecBaseVelocity.z = 0.0;
			}
			else
			{
				local vel = newGround.IsValid() ? newGround.GetAbsVelocity() : Vector();
				m_vecBaseVelocity -= vel; 
				m_vecBaseVelocity.z = vel.z;
			}
		}
		else if (oldGround && !newGround)
		{
			if (oldGround == WORLD)
			{
				m_vecBaseVelocity.z = 0.0;
			}
			else
			{
				local vel = oldGround.IsValid() ? oldGround.GetAbsVelocity() : Vector();
				m_vecBaseVelocity += vel;
				m_vecBaseVelocity.z = vel.z;
			}
		}		

		m_ground = newGround;
		
		if (newGround)
		{
			m_surfaceFriction = 1.0;
			m_vecVelocity.z = 0.0;
		}
	}
	
	function Accelerate(wishdir, wishspeed)
	{
		local currentspeed = m_vecVelocity.Dot(wishdir);
		local addspeed = wishspeed - currentspeed;
		if (addspeed <= 0.0)
			return;

		local accelspeed = sv_accelerate * wishspeed * frametime * m_surfaceFriction;
		if (accelspeed > addspeed)
			accelspeed = addspeed;
		
		m_vecVelocity += wishdir * accelspeed;
	}
	
	function AirAccelerate(wishdir, wishspeed)
	{
		local wishspd = wishspeed;
		if (wishspd > 30.0)
			wishspd = 30.0;

		local currentspeed = m_vecVelocity.Dot(wishdir);
		local addspeed = wishspd - currentspeed;
		if (addspeed <= 0.0)
			return;

		local accelspeed = sv_airaccelerate * wishspeed * frametime * m_surfaceFriction;
		if (accelspeed > addspeed)
			accelspeed = addspeed;
		
		m_vecVelocity += wishdir * accelspeed;
	}
	
	function StartGravity()
	{
		m_vecVelocity.z -= sv_gravity * 0.5 * frametime;
		m_vecVelocity.z += m_vecBaseVelocity.z * frametime;

		m_vecBaseVelocity.z = 0.0;
		
		CheckVelocity();
	}
	
	function FinishGravity()
	{
		m_vecVelocity.z -= sv_gravity * frametime * 0.5;

		CheckVelocity();
	}
	
	function Friction()
	{
		local speed = m_vecVelocity.Length();
		if (speed < 0.1)
			return;
			
		local drop = 0.0;
		if (m_ground != null)
		{
			local friction = sv_friction * m_surfaceFriction;
			local control = (speed < sv_stopspeed) ? sv_stopspeed : speed;
			drop += control * friction * frametime;
		}
		
		local newspeed = speed - drop;
		if (newspeed < 0.0)
			newspeed = 0.0;
			
		if (newspeed != speed)
		{
			newspeed /= speed;
			m_vecVelocity *= newspeed;
		}
	}
	
	function TracePlayerBBox(start, end, fMask, collisionGroup, pm)
	{
		pm.start <- start;
		pm.end <- end;
		pm.hullmin <- m_vecPlayerMins;
		pm.hullmax <- m_vecPlayerMaxs;
		pm.mask <- fMask;
		pm.ignore <- player;
		
		TraceHull(pm);
		
		if (!("enthit" in pm))
			pm.enthit <- null;
		if (!("allsolid" in pm))
			pm.allsolid <- false;
		if (!("startsolid" in pm))
			pm.startsolid <- false;	
	}
	
	function TryTouchGround(start, end, mins, maxs, fMask, collisionGroup, pm)
	{
		pm.start <- start;
		pm.end <- end;
		pm.hullmin <- mins;
		pm.hullmax <- maxs;
		pm.mask <- fMask;
		pm.ignore <- player;
		
		TraceHull(pm);
		
		if (!("enthit" in pm))
			pm.enthit <- null;
		if (!("allsolid" in pm))
			pm.allsolid <- false;
		if (!("startsolid" in pm))
			pm.startsolid <- false;	
	}
	
	function TryTouchGroundInQuadrants(start, end, fMask, collisionGroup, pm)
	{
		local mins, maxs;
		local minsSrc = m_vecPlayerMins;
		local maxsSrc = m_vecPlayerMaxs;

		local fraction = pm.fraction;
		local endpos = Vector(pm.endpos.x, pm.endpos.y, pm.endpos.z);
		
		mins = minsSrc;
		maxs = Vector(0 < maxsSrc.x ? 0 : maxsSrc.x, 0 < maxsSrc.y ? 0 : maxsSrc.y, maxsSrc.z);
		TryTouchGround(start, end, mins, maxs, fMask, collisionGroup, pm);
		if (pm.enthit && pm.plane_normal.z >= 0.7)
		{
			pm.fraction = fraction;
			pm.endpos = endpos;
			return;
		}

		mins = Vector(0 > minsSrc.x ? 0 : minsSrc.x, 0 > minsSrc.y ? 0 : minsSrc.y, minsSrc.z);
		maxs = maxsSrc;
		TryTouchGround(start, end, mins, maxs, fMask, collisionGroup, pm);
		if (pm.enthit && pm.plane_normal.z >= 0.7)
		{
			pm.fraction = fraction;
			pm.endpos = endpos;
			return;
		}

		mins = Vector(minsSrc.x, 0 > minsSrc.y ? 0 : minsSrc.y, minsSrc.z);
		maxs = Vector(0 < maxsSrc.x ? 0 : maxsSrc.x, maxsSrc.y, maxsSrc.z);
		TryTouchGround(start, end, mins, maxs, fMask, collisionGroup, pm);
		if (pm.enthit && pm.plane_normal.z >= 0.7)
		{
			pm.fraction = fraction;
			pm.endpos = endpos;
			return;
		}
		
		mins = Vector(0 > minsSrc.x ? 0 : minsSrc.x, minsSrc.y, minsSrc.z);
		maxs = Vector(maxsSrc.x, 0 < maxsSrc.y ? 0 : maxsSrc.y, maxsSrc.z);
		TryTouchGround(start, end, mins, maxs, fMask, collisionGroup, pm);
		if (pm.enthit && pm.plane_normal.z >= 0.7)
		{
			pm.fraction = fraction;
			pm.endpos = endpos;
			return;
		}

		pm.fraction = fraction;
		pm.endpos = endpos;
	}
	
	function StayOnGround()
	{
		local trace = {};
		local start = m_vecAbsOrigin + Vector();
		local end = m_vecAbsOrigin + Vector();
		
		start.z += 2;
		end.z -= sv_stepsize;

		TracePlayerBBox(m_vecAbsOrigin, start, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, trace);
		start = trace.endpos;

		TracePlayerBBox(start, end, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, trace);
		
		if (trace.fraction > 0.0 &&
			trace.fraction < 1.0 &&	
			!trace.startsolid &&
			trace.plane_normal.z >= 0.7)	
		{
			local flDelta = fabs(m_vecAbsOrigin.z - trace.endpos.z);
			if (flDelta > 0.015625)
				m_vecAbsOrigin = trace.endpos;
		}
	}
	
	function ClipVelocity(input, normal, overbounce)
	{
		local blocked = input.Dot(normal);
		local backoff = blocked * overbounce;
		local out = input - normal * backoff;
		local adjust = out.Dot(normal);
		if (adjust < 0.0)
			out -= normal * adjust;
		return out;	
	}
	
	function TryPlayerMove(pFirstDest = null, pFirstTrace = null)
	{
		local pm = {};
		local time_left = frametime;
		local allFraction = 0.0;
		local original_velocity = m_vecVelocity + Vector();
		local primal_velocity = m_vecVelocity + Vector();
		local planes = [];
		
		for (local bumpcount = 0; bumpcount < 4; bumpcount++)
		{
			if (m_vecVelocity.Length() == 0.0)
				break;

			local end = m_vecAbsOrigin + m_vecVelocity * time_left;
			
			if (pFirstTrace != null && (end.x == pFirstDest.x && end.y == pFirstDest.y && end.z == pFirstDest.z))
				pm = pFirstTrace;
			else
				TracePlayerBBox(m_vecAbsOrigin, end, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, pm);
			
			allFraction += pm.fraction;
			
			if (pm.allsolid)
			{
				m_vecVelocity = Vector();
				return;
			}
			
			if (pm.fraction > 0.0)
			{
				// The comments state this is a workaround for a "terrain tracing bug", but I haven't seen it in practice and this is expensive
				// If the player can get stuck on terrain, revisit this			
				/*
				if (pm.fraction == 1.0)
				{
					local stuck = {};
					TracePlayerBBox(pm.endpos, pm.endpos, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, stuck);
					if (stuck.startsolid || stuck.fraction != 1.0)
					{
						m_vecVelocity = Vector();
						break;
					}		
				}
				*/
				
				m_vecAbsOrigin = pm.endpos;
				original_velocity = m_vecVelocity + Vector();
				planes.clear();	
			}
			
			if (pm.fraction == 1.0)
				break;
				
			time_left -= time_left * pm.fraction;
			
			local numplanes = planes.len();
			if (numplanes >= 5)
			{
				m_vecVelocity = Vector();
				break;		
			}
			
			planes.append(pm.plane_normal);
			++numplanes;
			
			if (numplanes == 1 && m_movetype == MOVETYPE_WALK && !m_ground)
			{
				local plane = planes[0];
				
				if (plane.z > 0.7)
					m_vecVelocity = ClipVelocity(original_velocity, plane, 1.0);
				else
					m_vecVelocity = ClipVelocity(original_velocity, plane, 1.0 + sv_bounce * (1.0 - m_surfaceFriction));
				
				original_velocity = m_vecVelocity + Vector();
			}
			else
			{
				local i = 0;
				for (; i < numplanes; i++)
				{
					m_vecVelocity = ClipVelocity(original_velocity, planes[i], 1.0);
					local j = 0;
					for (; j < numplanes; j++)
					{
						if (i != j)
							if (m_vecVelocity.Dot(planes[j]) < 0.0)
								break;
					}
					if (j == numplanes)
						break;
				}

				if (i == numplanes)
				{
					if (numplanes != 2)
					{
						m_vecVelocity = Vector();
						break;
					}
					
					local dir = planes[0].Cross(planes[1]);
					dir.Norm();
					m_vecVelocity = dir * dir.Dot(m_vecVelocity);
				}
				
				if (m_vecVelocity.Dot(primal_velocity) <= 0.0)
				{
					m_vecVelocity = Vector();
					break;
				}
			}
		}
		
		if (allFraction == 0.0)
			m_vecVelocity = Vector();
	}
	
	function AirMove()
	{
		local fmove = m_flForwardMove;
		local smove = m_flSideMove;
		
		local forward = m_vecForward + Vector();
		local right = m_vecRight + Vector();
		
		forward.z = 0.0;
		forward.Norm();
		right.z = 0.0;
		right.Norm();
		
		local wishvel = Vector(
			forward.x * fmove + right.x * smove, 
			forward.y * fmove + right.y * smove, 
			0.0);
			
		local wishdir = wishvel + Vector();
		local wishspeed = wishdir.Norm();
		
		if (wishspeed != 0.0 && wishspeed > m_flMaxSpeed)
		{
			wishvel *= m_flMaxSpeed / wishspeed;
			wishspeed = m_flMaxSpeed;
		}
		
		AirAccelerate(wishdir, wishspeed);
		
		m_vecVelocity += m_vecBaseVelocity;
		TryPlayerMove();
		m_vecVelocity -= m_vecBaseVelocity;
	}
	
	function WalkMove()
	{
		local oldground = m_ground;
		
		local fmove = m_flForwardMove;
		local smove = m_flSideMove;
		
		local forward = m_vecForward + Vector();
		local right = m_vecRight + Vector();
		
		forward.z = 0.0;
		forward.Norm();
		right.z = 0.0;
		right.Norm();
		
		local wishvel = Vector(
			forward.x * fmove + right.x * smove, 
			forward.y * fmove + right.y * smove, 
			0.0);
			
		local wishdir = wishvel + Vector();
		local wishspeed = wishdir.Norm();
		
		if (wishspeed != 0.0 && wishspeed > m_flMaxSpeed)
		{
			wishvel *= m_flMaxSpeed / wishspeed;
			wishspeed = m_flMaxSpeed;
		}
		
		m_vecVelocity.z = 0.0;
		Accelerate(wishdir, wishspeed);
		m_vecVelocity.z = 0.0;
		
		m_vecVelocity += m_vecBaseVelocity;
		
		local spd = m_vecVelocity.Length();
		if (spd  < 1.0)
		{
			m_vecVelocity = Vector();
			m_vecVelocity -= m_vecBaseVelocity;
			return;
		}
		
		local dest = Vector(m_vecAbsOrigin.x + m_vecVelocity.x * frametime,
							m_vecAbsOrigin.y + m_vecVelocity.y * frametime,
							m_vecAbsOrigin.z);
							
		local pm = {};
		TracePlayerBBox(m_vecAbsOrigin, dest, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, pm);
		
		if (pm.fraction == 1.0)
		{
			m_vecAbsOrigin = pm.endpos;
			m_vecVelocity -= m_vecBaseVelocity;
			StayOnGround();
			return;
		}
		
		if (oldground == null)
		{
			m_vecVelocity -= m_vecBaseVelocity;
			return;
		}
		
		StepMove(dest, pm);
		
		m_vecVelocity -= m_vecBaseVelocity;
		
		StayOnGround();
	}
	
	// Note this uses the TF implementation of StepMove
	function StepMove(vecDestination, trace)
	{
		local origTrace = clone(trace);

		local vecEndPos;
		local vecPos = m_vecAbsOrigin + Vector();
		local vecVel = m_vecVelocity + Vector();

		vecEndPos = m_vecAbsOrigin + Vector();
		vecEndPos.z += sv_stepsize + DIST_EPSILON;
		TracePlayerBBox(m_vecAbsOrigin, vecEndPos, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, trace);
		if (!trace.startsolid && !trace.allsolid)
			m_vecAbsOrigin = trace.endpos;

		TryPlayerMove();

		vecEndPos = m_vecAbsOrigin + Vector();
		vecEndPos.z -= sv_stepsize + DIST_EPSILON;
		TracePlayerBBox(m_vecAbsOrigin, vecEndPos, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER_MOVEMENT, trace);
		if (!trace.startsolid && !trace.allsolid)
			m_vecAbsOrigin = trace.endpos;

		if ((trace.fraction != 1.0 && trace.plane_normal.z < 0.7) ||
			(m_vecAbsOrigin.x == vecPos.x && m_vecAbsOrigin.y == vecPos.y && m_vecAbsOrigin.z == vecPos.z))
		{
			m_vecAbsOrigin = vecPos;
			m_vecVelocity = vecVel;
			
			TryPlayerMove(vecDestination, origTrace);
		}
	}
	
	function FullWalkMove()
	{
		StartGravity();
		
		if (m_nButtons & IN_JUMP)
 			CheckJumpButton();
		else
			m_nOldButtons = m_nOldButtons & (~IN_JUMP);

		if (m_ground != null)
		{
			m_vecVelocity.z = 0.0;
			Friction();
		}

		CheckVelocity();	

		if (m_ground != null)
			WalkMove();
		else
			AirMove();

		CategorizePosition();
		CheckVelocity();
		
		FinishGravity();
		
		if (m_ground != null)
			m_vecVelocity.z = 0;
	}
	
	function PlayerMove()
	{	
		CheckParameters();

		m_vecForward = m_vecViewAngles.Forward();
		m_vecRight = m_vecViewAngles.Left();
		m_vecUp = m_vecViewAngles.Up();
		
		if (m_movetype != MOVETYPE_WALK || m_bGameCodeMovedPlayer)
			CategorizePosition();
		else if (m_vecVelocity.z > 250.0)
			SetGroundEntity(null);
		
		// TODO: other movetypes
		if (m_movetype == MOVETYPE_WALK)
			FullWalkMove();	
	}
	
	function ProcessMovement(origin, angles, velocity, deltatime)
	{	
		frametime = deltatime;
		
		if (origin.x != m_vecAbsOrigin.x || origin.y != m_vecAbsOrigin.y || origin.z != m_vecAbsOrigin.z)
			m_bGameCodeMovedPlayer = true;
		else
			m_bGameCodeMovedPlayer = false;	
		m_vecAbsOrigin = origin;
		m_vecViewAngles = angles;
		m_vecVelocity = velocity;
		
		PlayerMove();
		
		m_nOldButtons = m_nButtons;
		m_flOldForwardMove = m_flForwardMove;		
	}
	
	player = null;
	frametime = null;
	
	m_movetype = null;
	m_ground = null;
	m_vecBaseVelocity = null;
	m_vecPlayerMins = null;
	m_vecPlayerMaxs = null;
	m_surfaceFriction = null;
	
	m_vecForward = null;
	m_vecRight = null;
	m_vecUp = null;
	
	// movedata
	m_vecAbsOrigin = null;
	m_vecVelocity = null;
	m_vecViewAngles = null;
	
	m_nButtons = null;
	m_nOldButtons = null;
	m_flForwardMove = null;
	m_flOldForwardMove = null;
	m_flSideMove = null;
	
	m_flMaxSpeed = null;
		
	m_bGameCodeMovedPlayer = null;
	
	// convars
	sv_gravity = null;
	sv_maxvelocity = null;
	sv_friction = null;
	sv_stopspeed = null;
	sv_accelerate = null;
	sv_airaccelerate = null;
	sv_bounce = null;
	sv_stepsize = null;
	sv_jump_impulse = null;
};