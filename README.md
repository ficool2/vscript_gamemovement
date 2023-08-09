# VScript Gamemovement
Simple standalone library that allows VScript to utilize Source engine (or Quake) movement. Particularly useful for making custom bots that move in a responsive manner.

# Usage
Include the `gamemovement.nut` script in the root scope, i.e. `IncludeScript("gamemovement", getroottable())`. 
Note this only needs to be done once, multiple attempts to load the library will be ignored.

To use the movement, first initialize the class with the entity handle, minimum + maximum size of the collision hull, and maximum speed.
```js
movement = CGameMovement(entity, mins, maxs, maxspeed);
```

Then all you need to get an entity moving is setup movement parameters, call ProcessMovement and use the results.
The example below shows how to make an entity move forward where its currently facing from within a per-tick think function.
```js
movement.m_nButtons = 0; // The buttons the entity is pressing. Currently only IN_JUMP is implemented here
movement.m_flForwardMove = 450.0; // Desired speed to move forward (positive) or backward (backward). TF2 players use the value of cl_forwardspeed (450)
movement.m_flSideMove = 0.0; // Desired speed to move right (positive) or left (backward). TF2 players use the value of cl_sidespeed (450)

movement.ProcessMovement(entity.GetOrigin(), entity.GetAbsAngles(), entity.GetAbsVelocity(), DEFAULT_TICKRATE);

entity.SetAbsOrigin(movement.m_vecAbsOrigin);
entity.SetAbsAngles(movement.m_vecViewAngles);
entity.SetAbsVelocity(movement.m_vecVelocity);
```

The library includes 2 examples:
* `gamemovement_bot.nut`: Example of a simple bot that follows the local player around.
* `gamemovement_player.nut`: Overrides player gamemovement with the library's. Note this is not suitable for multiplayer due to input latency, and `cl_smoothtime 0.05` is required to prevent too much prediction smoothing.

Each instance of the `CGameMovement` class fetches various convar values such as `sv_accelerate`, `sv_gravity`, etc. You can override these afterwards per-class if you desire different values, for example `movement.sv_gravity = 500.0`. See the variables section of the `CGameMovement` class at the bottom in `gamemovement.nut` for reference.

Note that the library also setups the following when included:
* Constant folding (if not already done so)
* Defines global constants `MASK_PLAYERSOLID` and `DEFAULT_TICKRATE`
* Gets global entity handle to `worldspawn` named `WORLD`

**NOTE:** `SetAbsVelocity` and `GetAbsVelocity` might be cleared by certain entities such as `base_boss`, so you must store the velocity off yourself instead. See `gamemovement_bot.nut` for an example.
**NOTE:** If you are processing gamemovement at different intervals than per-tick, change the last parameter of `ProcessMovement` to your interval in seconds rather than using `DEFAULT_TICKRATE` (0.015).

# Limitations
Currently, only the `MOVETYPE_WALK` mode from gamemovement is implemented. Crouching, swimming, ladders and grappling hook movement are not supported. Some code was stripped such as detecting fall velocity on impact to simplify the library, however you can easily implement it yourself using SDK code as a reference. The movement is not 1:1 to TF2 gamemovement as there is minor differences from SDK 2013, however for the most part it should behave and feel the same.

# License
Do whatever the hell you want

# Credits
- Gamemovement code by Valve from Source SDK 2013: https://github.com/ValveSoftware/source-sdk-2013