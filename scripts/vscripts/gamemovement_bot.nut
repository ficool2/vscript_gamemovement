// Example script to create a bot that follows the player
// Can only be invoked from script_execute, the bot will spawn at the crosshair

IncludeScript("gamemovement", getroottable());

RAD2DEG <- 57.295779513;

class BotPathPoint
{
	constructor(_area, _pos, _how)
	{
		area = _area;
		pos = _pos;
		how = _how;
	}

	area = null;
	pos = null;
	how = null;
}

class ExampleBot
{
	function constructor(entity, follow_ent)
	{
		me = entity;
		
		my_vel = Vector();		
		movement = CGameMovement(entity, Vector(-25, -25, 0), Vector(25, 25, 82), 300.0);
		
		path = [];
		path_index = 0;
		path_follow_ent = follow_ent;
		path_follow_ent_dist = 50.0;
		path_target_pos = follow_ent.GetOrigin();
		path_update_time_next = Time();
		path_update_time_delay = 0.2;
		path_update_force = true;
		path_areas = {};
	}

	function UpdatePath()
	{
		ResetPath();

		if (path_follow_ent && path_follow_ent.IsValid())
			path_target_pos = path_follow_ent.GetOrigin();

		local pos_start = my_pos;
		local pos_end = path_target_pos;
		
		pos_start.z += 1.0;
		pos_end.z += 1.0;
		
		local area_start = NavMesh.GetNavArea(pos_start, 128.0);
		local area_end = NavMesh.GetNavArea(pos_end, 128.0);
		if (area_start == null)
			area_start = NavMesh.GetNearestNavArea(pos_start, 512.0, false, false);
		if (area_end == null)
			area_end = NavMesh.GetNearestNavArea(pos_end, 512.0, false, false);

		if (area_start == null || area_end == null)
			return false;

		if (area_start == area_end)
		{
			path.append(BotPathPoint(area_end, pos_end, NUM_TRAVERSE_TYPES));
			return true;
		}
			
		if (!NavMesh.GetNavAreasFromBuildPath(area_start, area_end, pos_end, 0.0, TEAM_ANY, false, path_areas))
			return false;

		if (path_areas.len() == 0)
			return false;

		local area_target = path_areas["area0"];
		local area = area_target;
		local area_count = path_areas.len();

		for (local i = 0; i < area_count && area != null; i++)
		{
			path.append(BotPathPoint(area, area.GetCenter(), area.GetParentHow()));
			area = area.GetParent();
		}
		
		path.append(BotPathPoint(area_start, my_pos, NUM_TRAVERSE_TYPES))
		path.reverse();
		
		local path_count = path.len();
		for (local i = 1; i < path_count; i++)
		{
			local path_from = path[i - 1];
			local path_to = path[i];
			
			path_to.pos = path_from.area.ComputeClosestPointInPortal(path_to.area, path_to.how, path_from.pos);
		}

		path.append(BotPathPoint(area_end, pos_end, NUM_TRAVERSE_TYPES));
	}

	function AdvancePath()
	{
		local path_len = path.len();
		if (path_len == 0)
			return false;

		if ((path[path_index].pos - my_pos).Length2D() < 32.0)
		{
			path_index++;
			if (path_index >= path_len)
			{
				ResetPath();
				return false;
			}
		}

		return true;
	}

	function ResetPath()
	{
		path_areas.clear();
		path.clear();
		path_index = 0;
	}

	function Move()
	{
		if (path_update_force)
		{
			UpdatePath();
			path_update_force = false;
		}
		else if (path_follow_ent && path_follow_ent.IsValid())
		{
			local time = Time();
			if (path_update_time_next < time)
			{
				if ((path_target_pos - path_follow_ent.GetOrigin()).Length() > 16.0)
				{
					UpdatePath();
					path_update_time_next = time + path_update_time_delay;
				}
			}
		}

		if (AdvancePath())
		{
			local path_pos = path[path_index].pos;
			
			local move_dir = path_pos - my_pos;
			move_dir.Norm();
			local move_vel = move_dir * 450.0;
			
			local my_forward = my_ang.Forward();
			my_forward.x = my_forward.x + 0.1 * (move_dir.x - my_forward.x);
			my_forward.y = my_forward.y + 0.1 * (move_dir.y - my_forward.y);
			
			local angle = atan2(my_forward.y, my_forward.x);
			local look_ang = QAngle(0, angle * RAD2DEG, 0);
			
			my_forward = look_ang.Forward();
			
			movement.m_nButtons = IN_FORWARD;
			
			movement.m_flForwardMove = look_ang.Forward().Dot(move_vel);
			movement.m_flSideMove = look_ang.Left().Dot(move_vel);
			
			movement.ProcessMovement(my_pos, look_ang, my_vel, DEFAULT_TICKRATE);
			
			me.SetAbsOrigin(movement.m_vecAbsOrigin);
			me.SetAbsAngles(movement.m_vecViewAngles);
			// SetAbsVelocity does nothing on base_boss...
			//me.SetAbsVelocity(movement.m_vecVelocity);
			my_vel = movement.m_vecVelocity;			
			
			return true;
		}

		return false;
	}

	function DrawDebugInfo()
	{		
		local duration = 0.03;
		
		local path_len = path.len();
		if (path_len > 0)
		{
			local path_start_index = 0;
			if (path_start_index == 0)
				path_start_index++;

			for (local i = path_start_index; i < path_len; i++)
			{
				local p1 = path[i-1];
				local p2 = path[i];
				
				local clr;
				if (p1.how <= GO_WEST || p1.how >= NUM_TRAVERSE_TYPES)
					clr = [0, 255, 0];
				else if (p1.how ==  GO_JUMP)
					clr = [128, 128, 255];
				else
					clr = [255, 128, 192];
					
				DebugDrawLine(p1.pos, p2.pos, clr[0], clr[1], clr[2], true, duration);
				DebugDrawText(p1.pos, i.tostring(), false, duration);
			}
		}

		foreach (name, area in path_areas)
			area.DebugDrawFilled(255, 0, 0, 30, duration, true, 0.0);
			
		local text_pos = Vector(my_pos.x, my_pos.y, my_pos.z + 90.0) + my_ang.Left() * -32.0;
		local z_offset = -8.0;
		local m = movement;
		
		DebugDrawText(
			text_pos,
			format("origin: %f %f %f", m.m_vecAbsOrigin.x, m.m_vecAbsOrigin.y, m.m_vecAbsOrigin.z), 
			false, duration
		); text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("angles: %f %f %f", m.m_vecViewAngles.x, m.m_vecViewAngles.y, m.m_vecViewAngles.z), 
			false, duration
		); text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("velocity: %f %f %f", m.m_vecVelocity.x, m.m_vecVelocity.y, m.m_vecVelocity.z), 
			false, duration
		); text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("basevelocity: %f %f %f", m.m_vecBaseVelocity.x, m.m_vecBaseVelocity.y, m.m_vecBaseVelocity.z), 
			false, duration
		);		 text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("forward: %g", m.m_flForwardMove),
			false, duration
		); text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("side: %g", m.m_flSideMove),
			false, duration
		); text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("ground: %s", m.m_ground ? m.m_ground.tostring() : "null"),
			false, duration
		);	 text_pos.z += z_offset;
		DebugDrawText(
			text_pos,
			format("speed: %g", m.m_vecVelocity.Length2D()),
			false, duration
		);	 text_pos.z += z_offset;
	}
	
	function Update()
	{
		my_pos = me.GetOrigin();
		my_ang = me.GetAbsAngles();
		
		Move();
		DrawDebugInfo();
	}

	me = null;	
	
	my_pos = null;
	my_ang = null;
	my_vel = null;
	movement = null;
	
	path = null;				
	path_index = null;			
	path_follow_ent = null;		
	path_follow_ent_dist = null;
	
	path_target_pos = null;		
	path_update_time_next = null;
	path_update_time_delay = null; 
	path_update_force = null;	
	path_areas = null;			
}

function ExampleBotThink()
{
	bot.Update();
	return -1;
}

function ExampleBotCreate()
{
	local player = GetListenServerHost();
	local trace =
	{
		start = player.EyePosition(),
		end = player.EyePosition() + player.EyeAngles().Forward() * 8192.0,
		ignore = player
	};
	
	TraceLineEx(trace);

	if (!trace.hit)
	{
		printl("Invalid bot spawn location");
		return null;
	}

	local entity = SpawnEntityFromTable("base_boss",
	{
		targetname = "bot",
		teamnum = TF_TEAM_BLUE,
		skin = 1,
		origin = trace.pos,
		model = "models/player/sniper.mdl",
		playbackrate = 1.0,
		health = 125
	});

	entity.ValidateScriptScope();
	entity.GetScriptScope().bot <- ExampleBot(entity, player);
	AddThinkToEnt(entity, "ExampleBotThink");
	EntFireByHandle(entity, "Disable", "", -1, null, null);
	return entity;
}

ExampleBotCreate();