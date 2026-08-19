	// ===================================================== //
	// Leg state machine for Mike Powell, the hero of MoH PC //
	// ===================================================== //

// The leg state machine takes care of states for the legs only.  The
// torso state machine can override the leg state machine with states
// which require animations of the whole body, such as climbing and
// sprinting.  The animations in this state file control the whole body,
// but most of the time the torso state machine overrides the animation
// for the upper body.

////////////////////////////////////////////////////////////////
//
// Standing
//
////////////////////////////////////////////////////////////////

state STAND
{
	entrycommands
	{
		modheight "stand"
		movementstealth "1.0"
		moveposflags "standing"
	}
	legs
	{
		mp40_stand_idle				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_idle				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_idle			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_idle			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_idle			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_idle	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_idle			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_idle			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_idle			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_idle			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_idle			: default
	}

	states
	{
		FALL				: FALLING
		// HZM coop [216] - manning pose that actually fires for coop players: the vanilla rows
		// below require !HAS_WEAPON (never true with a rifle in inventory - bug-309)
		COOP_TURRET_MAN		: COOP_ON_TURRET
		VEHICLE_TURRET_START	: IS_USING_VEHICLE IS_USING_TURRET !HAS_WEAPON
		VEHICLE_START		: IS_USING_VEHICLE !HAS_WEAPON
		TURRET_START		: IS_USING_TURRET !HAS_WEAPON
		
		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		// HZM coop - TAKE COVER [214]: engine-validated pose requests (Player::TickCoopCover).
		// COOP_COVER = standing back-to-wall, COOP_COVER_LOW = low obstacle ahead (the COVER_LOW
		// state's modheight "duck" tucks the player automatically). The engine clears the request
		// on any movement input, so these can sit above the walk/run edges safely.
		COVER_WALL			: COOP_COVER
		COVER_LOW			: COOP_COVER_LOW

		RUN_FORWARD			: RUN FORWARD HAS_VELOCITY !BLOCKED "2"
		RUN_BACKWARD		: RUN BACKWARD HAS_VELOCITY !BLOCKED "2"
		RUN_LEFT			: RUN STRAFE_LEFT HAS_VELOCITY !BLOCKED "2"
		RUN_BACKWARD		: RUN STRAFE_RIGHT HAS_VELOCITY !BLOCKED "2"

		WALK_FORWARD		: FORWARD HAS_VELOCITY !BLOCKED "2"
		WALK_BACKWARD		: BACKWARD HAS_VELOCITY !BLOCKED "2"
		WALK_LEFT			: STRAFE_LEFT HAS_VELOCITY !BLOCKED "2"
		WALK_BACKWARD		: STRAFE_RIGHT HAS_VELOCITY !BLOCKED "2"

		// restart if our weapon has changed
		STAND				: +HAS_WEAPON
		STAND				: -HAS_WEAPON
		
		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
		
		// pitch a new idle anim if the anim finished
		STAND				: ANIMDONE_LEGS
	}
}


////////////////////////////////////////////////////////////////
//
// Running
//
////////////////////////////////////////////////////////////////

state RUN_FORWARD
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing" "running"
	}
	legs
	{
		mp40_stand_run_fwd				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_run_fwd				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_run_fwd	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_run_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_run_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_run_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_run_fwd			: default
	}

	states
	{
		LIMP_FORWARD	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		SPRINT_FORWARD		: COOP_SPRINTING

		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER
		
		STAND				: !HAS_VELOCITY
		STAND				: BLOCKED "2"
		
		WALK_FORWARD		: !RUN FORWARD
		WALK_BACKWARD		: !RUN BACKWARD
		WALK_LEFT			: !RUN STRAFE_LEFT !FORWARD !BACKWARD
		WALK_BACKWARD		: !RUN STRAFE_RIGHT !FORWARD !BACKWARD

		RUN_BACKWARD		: BACKWARD
		RUN_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		RUN_RIGHT			: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		RUN_FORWARD	: +HAS_WEAPON
		RUN_FORWARD	: -HAS_WEAPON

		JUMP_FORWARD_RUN	: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state RUN_BACKWARD
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing" "running"
	}
	legs
	{
		mp40_stand_run_back				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_run_back				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_run_back			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_run_back			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_run_back			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_run_back	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_run_back			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_run_back			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_run_back			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_run_back			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_run_back			: default
	}

	states
	{
		LIMP_BACKWARD	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: !HAS_VELOCITY
		STAND				: BLOCKED "2"

		WALK_FORWARD		: !RUN FORWARD
		WALK_BACKWARD		: !RUN BACKWARD
		WALK_LEFT			: !RUN STRAFE_LEFT !FORWARD !BACKWARD
		WALK_BACKWARD		: !RUN STRAFE_RIGHT !FORWARD !BACKWARD

		RUN_FORWARD			: FORWARD
		RUN_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		RUN_RIGHT			: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		RUN_BACKWARD		: +HAS_WEAPON
		RUN_BACKWARD		: -HAS_WEAPON

		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state RUN_LEFT
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing" "running"
	}
	legs
	{
		mp40_stand_run_left				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_run_left				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_run_left			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_run_left			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_run_left			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_run_left	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_run_left			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_run_left			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_run_left			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_run_left			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_run_left			: default
	}

	states
	{
		LIMP_LEFT	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: !HAS_VELOCITY
		STAND				: BLOCKED "2"

		WALK_FORWARD		: !RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_BACKWARD		: !RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_LEFT			: !RUN STRAFE_LEFT
		WALK_BACKWARD		: !RUN STRAFE_RIGHT

		RUN_FORWARD			: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_RIGHT			: STRAFE_RIGHT
		
		// restart if our weapon has changed
		RUN_LEFT			: +HAS_WEAPON
		RUN_LEFT			: -HAS_WEAPON

		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state RUN_RIGHT
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing" "running"
	}
	legs
	{
		mp40_stand_run_right			: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_run_right			: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_run_right			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_run_right			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_run_right			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_run_right	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_run_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_run_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_run_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_run_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_run_right			: default
	}

	states
	{
		LIMP_RIGHT	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: !HAS_VELOCITY
		STAND				: BLOCKED "2"
		
		WALK_FORWARD		: !RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_BACKWARD		: !RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_LEFT			: !RUN STRAFE_LEFT
		WALK_BACKWARD		: !RUN STRAFE_RIGHT

		RUN_FORWARD			: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_LEFT			: STRAFE_LEFT

		// restart if our weapon has changed
		RUN_RIGHT			: +HAS_WEAPON
		RUN_RIGHT			: -HAS_WEAPON

		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

////////////////////////////////////////////////////////////////
//
// Walking
//
////////////////////////////////////////////////////////////////

state WALK_FORWARD
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking" // fixed... -1337SMITHY
	}
	legs
	{
		mp40_stand_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_fwd			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_fwd			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_fwd			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_fwd	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_walk_fwd			: default
	}

	states
	{
		LIMP_FORWARD	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: BLOCKED "2"
		STAND				: !HAS_VELOCITY
		
		RUN_FORWARD			: RUN FORWARD
		RUN_BACKWARD		: RUN BACKWARD
		RUN_LEFT			: RUN STRAFE_LEFT !FORWARD !BACKWARD
		RUN_RIGHT			: RUN STRAFE_RIGHT !FORWARD !BACKWARD
		
		WALK_BACKWARD		: BACKWARD
		WALK_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		WALK_RIGHT			: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		WALK_FORWARD		: +HAS_WEAPON
		WALK_FORWARD		: -HAS_WEAPON

		JUMP_FORWARD_RUN	: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state WALK_BACKWARD
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}
	legs
	{
		mp40_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_back	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_walk_back				: default
	}

	states
	{
		LIMP_BACKWARD	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: BLOCKED "2"
		STAND				: !HAS_VELOCITY
		
		RUN_FORWARD			: RUN FORWARD
		RUN_BACKWARD		: RUN BACKWARD
		RUN_LEFT			: RUN STRAFE_LEFT !FORWARD !BACKWARD
		RUN_RIGHT			: RUN STRAFE_RIGHT !FORWARD !BACKWARD
		
		WALK_FORWARD		: FORWARD
		WALK_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		WALK_RIGHT			: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		WALK_BACKWARD		: +HAS_WEAPON
		WALK_BACKWARD		: -HAS_WEAPON

		JUMP_STANDING	: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state WALK_LEFT
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}
	legs
	{
		mp40_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_left	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_walk_left				: default
	}

	states
	{
		LIMP_LEFT	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: BLOCKED "2"
		STAND				: !HAS_VELOCITY
		
		RUN_FORWARD			: RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_BACKWARD		: RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_LEFT			: RUN STRAFE_LEFT
		RUN_RIGHT			: RUN STRAFE_RIGHT
		
		WALK_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_RIGHT			: STRAFE_RIGHT
		
		// restart if our weapon has changed
		WALK_LEFT			: +HAS_WEAPON
		WALK_LEFT			: -HAS_WEAPON

		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state WALK_RIGHT
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}
	legs
	{
		mp40_stand_walk_right				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_right				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_right	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_right					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_stand_walk_right			: default
	}

	states
	{
		LIMP_RIGHT	: COOP_LIMPING		// HZM coop bug-1291 - low-health limp
		FALL				: FALLING

		CROUCH_IDLE			: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED		: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND				: BLOCKED "2"
		STAND				: !HAS_VELOCITY
		
		RUN_FORWARD			: RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_BACKWARD		: RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		RUN_LEFT			: RUN STRAFE_LEFT
		RUN_RIGHT			: RUN STRAFE_RIGHT
		
		WALK_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		WALK_LEFT			: STRAFE_LEFT
		
		// restart if our weapon has changed
		WALK_RIGHT			: +HAS_WEAPON
		WALK_RIGHT			: -HAS_WEAPON

		JUMP_STANDING		: +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}


////////////////////////////////////////////////////////////////
//
// Crouching
//
////////////////////////////////////////////////////////////////

// this state is called to notify the player that he can't duck
state CROUCH_DENIED
{
	entrycommands
	{
		iprint "Can't duck under water"
	}
	
	states
	{
		STAND	: default
	}
}

state CROUCH_IDLE
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.25"
		moveposflags "crouching"
	}
	legs
	{
		mp40_crouch_idle				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_idle				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_idle				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_idle				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_idle				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_idle	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_idle					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_idle					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_idle				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_idle				: default
	}

	states
	{
		FALL_DUCKED				: FALLING
		
		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"

		// HZM coop - TAKE COVER [214]: already crouched at a low obstacle when the pose engages
		COVER_LOW				: COOP_COVER_LOW

		CROUCH_RUN_FORWARD		: RUN FORWARD HAS_VELOCITY !BLOCKED "2"
		CROUCH_RUN_BACKWARD		: RUN BACKWARD HAS_VELOCITY !BLOCKED "2"
		CROUCH_RUN_LEFT			: RUN STRAFE_LEFT HAS_VELOCITY !BLOCKED "2"
		CROUCH_RUN_BACKWARD		: RUN STRAFE_RIGHT HAS_VELOCITY !BLOCKED "2"

		CROUCH_WALK_FORWARD		: FORWARD HAS_VELOCITY !BLOCKED "2"
		CROUCH_WALK_BACKWARD	: BACKWARD HAS_VELOCITY !BLOCKED "2"
		CROUCH_WALK_LEFT		: STRAFE_LEFT HAS_VELOCITY !BLOCKED "2"
		CROUCH_WALK_BACKWARD	: STRAFE_RIGHT HAS_VELOCITY !BLOCKED "2"

		// restart if our weapon has changed
		CROUCH_IDLE				: +HAS_WEAPON
		CROUCH_IDLE				: -HAS_WEAPON
	}
}

////////////////////////////////////////////////////////////////
//
// Crouch Walking
//
////////////////////////////////////////////////////////////////

state CROUCH_WALK_FORWARD
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.0"
		moveposflags "crouching" "walking"
	}
	legs
	{
		mp40_crouch_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_walk_fwd				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_walk_fwd	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_walk_fwd					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_walk_fwd					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_walk_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_walk_fwd				: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		
	
		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"
		
		CROUCH_RUN_FORWARD		: RUN FORWARD
		CROUCH_RUN_BACKWARD		: RUN BACKWARD
		CROUCH_RUN_LEFT			: RUN STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_RUN_RIGHT		: RUN STRAFE_RIGHT !FORWARD !BACKWARD
		
		CROUCH_WALK_BACKWARD	: BACKWARD
		CROUCH_WALK_LEFT		: STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_WALK_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		CROUCH_WALK_FORWARD		: +HAS_WEAPON
		CROUCH_WALK_FORWARD		: -HAS_WEAPON
	}
}

state CROUCH_WALK_BACKWARD
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.0"
		moveposflags "crouching" "walking"
	}
	legs
	{
		mp40_crouch_walk_back				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_walk_back				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_walk_back			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_walk_back			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_walk_back			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_walk_back	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_walk_back			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_walk_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_walk_back			: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND				: JUMP CHECK_HEIGHT "stand"
		STAND				: +CROUCH CHECK_HEIGHT "stand"
		STAND				: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE			: !HAS_VELOCITY
		CROUCH_IDLE			: BLOCKED "2"

		
		CROUCH_RUN_FORWARD		: RUN FORWARD
		CROUCH_RUN_BACKWARD		: RUN BACKWARD
		CROUCH_RUN_LEFT			: RUN STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_RUN_RIGHT		: RUN STRAFE_RIGHT !FORWARD !BACKWARD
		
		CROUCH_WALK_FORWARD		: FORWARD
		CROUCH_WALK_LEFT		: STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_WALK_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		CROUCH_WALK_BACKWARD	: +HAS_WEAPON
		CROUCH_WALK_BACKWARD	: -HAS_WEAPON
	}
}

state CROUCH_WALK_LEFT
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.0"
		moveposflags "crouching" "walking"
	}
	legs
	{
		mp40_crouch_walk_left				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_walk_left				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_walk_left			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_walk_left			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_walk_left			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_walk_left	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_walk_left			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_walk_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_walk_left			: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"

		
		CROUCH_RUN_FORWARD		: RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_BACKWARD		: RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_LEFT			: RUN STRAFE_LEFT
		CROUCH_RUN_RIGHT		: RUN STRAFE_RIGHT
		
		CROUCH_WALK_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_BACKWARD	: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_RIGHT		: STRAFE_RIGHT
		
		// restart if our weapon has changed
		CROUCH_WALK_LEFT		: +HAS_WEAPON
		CROUCH_WALK_LEFT		: -HAS_WEAPON
	}
}

state CROUCH_WALK_RIGHT
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.0"
		moveposflags "crouching" "walking"
	}
	legs
	{
		mp40_crouch_walk_right				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_walk_right				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_walk_right	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_walk_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_walk_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_walk_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_walk_right			: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"

		
		CROUCH_RUN_FORWARD		: RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_BACKWARD		: RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_LEFT			: RUN STRAFE_LEFT
		CROUCH_RUN_RIGHT		: RUN STRAFE_RIGHT
		
		CROUCH_WALK_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_BACKWARD	: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_LEFT		: STRAFE_LEFT
		
		// restart if our weapon has changed
		CROUCH_WALK_RIGHT		: +HAS_WEAPON
		CROUCH_WALK_RIGHT		: -HAS_WEAPON
	}
}

////////////////////////////////////////////////////////////////
//
// Crouch Running
//
////////////////////////////////////////////////////////////////

state CROUCH_RUN_FORWARD
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "crouching" "running"
	}
	legs
	{
		mp40_crouch_run_fwd				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_run_fwd				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_run_fwd			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_run_fwd	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_run_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_run_fwd				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_run_fwd			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_run_fwd			: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"
		
		CROUCH_WALK_FORWARD		: !RUN FORWARD
		CROUCH_WALK_BACKWARD	: !RUN BACKWARD
		CROUCH_WALK_LEFT		: !RUN STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_WALK_BACKWARD	: !RUN STRAFE_RIGHT !FORWARD !BACKWARD

		CROUCH_RUN_BACKWARD		: BACKWARD
		CROUCH_RUN_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_RUN_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		CROUCH_RUN_FORWARD	: +HAS_WEAPON
		CROUCH_RUN_FORWARD	: -HAS_WEAPON
	}
}

state CROUCH_RUN_BACKWARD
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "crouching" "running"
	}
	legs
	{
		mp40_crouch_run_back				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_run_back				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_run_back				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_run_back				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_run_back				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_run_back	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_run_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_run_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_run_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_run_back				: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"
		
		CROUCH_WALK_FORWARD		: !RUN FORWARD
		CROUCH_WALK_BACKWARD	: !RUN BACKWARD
		CROUCH_WALK_LEFT		: !RUN STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_WALK_BACKWARD	: !RUN STRAFE_RIGHT !FORWARD !BACKWARD

		CROUCH_RUN_FORWARD		: FORWARD
		CROUCH_RUN_LEFT			: STRAFE_LEFT !FORWARD !BACKWARD
		CROUCH_RUN_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD
		
		// restart if our weapon has changed
		CROUCH_RUN_BACKWARD		: +HAS_WEAPON
		CROUCH_RUN_BACKWARD		: -HAS_WEAPON
	}
}

state CROUCH_RUN_LEFT
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "crouching" "running"
	}
	legs
	{
		mp40_crouch_run_left				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_run_left				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_run_left				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_run_left				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_run_left				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_run_left	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_run_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_run_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_run_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_run_left				: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"
		
		CROUCH_WALK_FORWARD		: !RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_BACKWARD	: !RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_LEFT		: !RUN STRAFE_LEFT
		CROUCH_WALK_BACKWARD	: !RUN STRAFE_RIGHT

		CROUCH_RUN_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_RIGHT		: STRAFE_RIGHT
		
		// restart if our weapon has changed
		CROUCH_RUN_LEFT			: +HAS_WEAPON
		CROUCH_RUN_LEFT			: -HAS_WEAPON
	}
}

state CROUCH_RUN_RIGHT
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "crouching" "running"
	}
	legs
	{
		mp40_crouch_run_right				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_crouch_run_right				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_crouch_run_right			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_crouch_run_right			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_crouch_run_right			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_crouch_run_right	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_crouch_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_crouch_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_crouch_run_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_crouch_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_crouch_run_right					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_crouch_run_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_crouch_run_right			: default
	}

	states
	{
		FALL_DUCKED				: FALLING

		STAND					: JUMP CHECK_HEIGHT "stand"
		STAND					: +CROUCH CHECK_HEIGHT "stand"
		STAND					: VIEW_IN_WATER CHECK_HEIGHT "stand"		

		CROUCH_IDLE				: !HAS_VELOCITY
		CROUCH_IDLE				: BLOCKED "2"
		
		CROUCH_WALK_FORWARD		: !RUN FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_BACKWARD	: !RUN BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_WALK_LEFT		: !RUN STRAFE_LEFT
		CROUCH_WALK_BACKWARD	: !RUN STRAFE_RIGHT

		CROUCH_RUN_FORWARD		: FORWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_BACKWARD		: BACKWARD !STRAFE_LEFT !STRAFE_RIGHT
		CROUCH_RUN_LEFT			: STRAFE_LEFT
		
		// restart if our weapon has changed
		CROUCH_RUN_RIGHT		: +HAS_WEAPON
		CROUCH_RUN_RIGHT		: -HAS_WEAPON
	}
}

////////////////////////////////////////////////////////////////
//
// Falling
//
////////////////////////////////////////////////////////////////

// falling in standing position
state FALL
{
	entrycommands
	{
		modheight "stand"
		movementstealth "0.5"
		moveposflags "offground" "falling"
	}
	legs
	{
		mp40_fall				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_fall				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_fall			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_fall	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_fall			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_fall					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_fall			: default
	}

	states
	{
//		LAND			: ONGROUND CHECK_HEIGHT "stand"
//		LAND_DUCKED		: ONGROUND
		LAND			: ONGROUND
		
		FALL_DUCKED		: +CROUCH
	}
}

// land from falling in  a standing position
state LAND
{
	entrycommands
	{
		modheight "stand"
		movementstealth "0.5"
		moveposflags "standing"
	}
	states
	{
		LAND_IMPACT_HARD	: HARD_IMPACT
		LAND_IMPACT			: MEDIUM_IMPACT
		STAND				: default
	}
}

// land from falling in  a standing position
state LAND_IMPACT
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing"
	}
	legs
	{
		mp40_land				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_land				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_land			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_land			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_land			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_land	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_land				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol"
		rifle_land				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_land			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade"
		smg_land				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_land					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_land				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_land			: default
	}

	states
	{
		STAND 			: ANIMDONE_LEGS CHECK_HEIGHT "stand"
		CROUCH_IDLE		: ANIMDONE_LEGS
	}
}

// land from falling in  a standing position
state LAND_IMPACT_HARD
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing"
	}
	legs
	{
		mp40_land_hard				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_land_hard				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_land_hard			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_land_hard			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_land_hard			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_land_hard	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_land_hard			: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_land_hard				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_land_hard			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_land_hard				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_land_hard				: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_land_hard			: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_land_hard			: default
	}

	states
	{
		STAND 			: ANIMDONE_LEGS CHECK_HEIGHT "stand"
		CROUCH_IDLE		: ANIMDONE_LEGS
	}
}

state FALL_DUCKED
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "offground" "falling"
	}
	legs
	{
		mp40_fall				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_fall				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_fall			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_fall	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_fall			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_fall					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_fall			: default
	}
	
	states
	{
		LAND_DUCKED			: ONGROUND
//		FALL				: !CROUCH DOWN_VELOCITY "100" CHECK_HEIGHT "stand"

//		FALL				: +CROUCH CHECK_HEIGHT "stand"
//		FALL				: +JUMP CHECK_HEIGHT "stand"
	}
}

state FALL_DUCKED_WANT_STAND
{
	entrycommands
	{
		modheight "duck"
		movementstealth "0.75"
		moveposflags "offground" "falling"
	}
	legs
	{
		mp40_fall				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_fall				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_fall			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_fall			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_fall	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_fall			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_fall					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_fall				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_fall			: default
	}
	
	states
	{
//		FALL				: CHECK_HEIGHT "stand"
//		FALL				: +JUMP CHECK_HEIGHT "stand"
		FALL_DUCKED			: +CROUCH
	
		LAND				: ONGROUND CHECK_HEIGHT "stand"
		LAND_DUCKED			: ONGROUND
	}
}

state LAND_DUCKED
{
	entrycommands
	{
		movementstealth "0.5"
		moveposflags "crouching"
	}
	states
	{
		STAND				: HARD_IMPACT !CROUCH CHECK_HEIGHT "stand"
		CROUCH_IDLE			: default
	}
}


////////////////////////////////////////////////////////////////
//
// JUMPING
//
////////////////////////////////////////////////////////////////

state JUMP_STANDING
{
	entrycommands
	{
		movementstealth "0.3"
		moveposflags "crouching"
//		modheight "duck"
		modheight "jumpstart"
		commanddelay 0.05 jump 56
	}
	legs
	{
		mp40_jump_takeoff				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_jump_takeoff				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_jump_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_jump_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_jump_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_jump_takeoff	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_jump_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_jump_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_jump_takeoff			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_jump_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_jump_takeoff					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_jump_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_jump_takeoff			: default
	}
	
	states
	{
//		FALL_DUCKED				: ANIMDONE_LEGS CROUCH
//		FALL					: ANIMDONE_LEGS CHECK_HEIGHT "stand"
		FALL_DUCKED_WANT_STAND	: ANIMDONE_LEGS !DUCKED_VIEW_IN_WATER
		FALL					: ANIMDONE_LEGS
	}
}

state JUMP_FORWARD_RUN
{
	entrycommands
	{
		movementstealth "0.2"
		moveposflags "crouching" "running"
//		modheight "duck"
		modheight "jumpstart"
		commanddelay 0.05 jump 56
	}
	legs
	{
		mp40_jump_run_takeoff				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_jump_run_takeoff				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_jump_run_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_jump_run_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_jump_run_takeoff			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_jump_run_takeoff	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_jump_run_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_jump_run_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_jump_run_takeoff			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_jump_run_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_jump_run_takeoff					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_jump_run_takeoff				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		unarmed_jump_run_takeoff			: default
	}
	
	states
	{
//		FALL_DUCKED				: ANIMDONE_LEGS CROUCH
//		FALL					: ANIMDONE_LEGS CHECK_HEIGHT "stand"
		FALL_DUCKED_WANT_STAND	: ANIMDONE_LEGS !DUCKED_VIEW_IN_WATER
		FALL					: ANIMDONE_LEGS
	}
}

////////////////////////////////////////////////////////////////
//
// VEHICLES
//
////////////////////////////////////////////////////////////////

state VEHICLE_START
{
	legs
	{
		unarmed_idle : default
	}
	
	states
	{
		VEHICLE_USING			: ANIMDONE_LEGS
	}
}

state VEHICLE_USING
{
	legs
	{
		unarmed_idle : default
	}
	
	states
	{
		STAND : !IS_USING_VEHICLE
	}
}

// for when using a turret on a vehicle

state VEHICLE_TURRET_START
{
	legs
	{
		unarmed_idle : default
	}
	
	states
	{
		VEHICLE_TURRET_USING	: ANIMDONE_LEGS
	}
}

state VEHICLE_TURRET_USING
{
	legs
	{
		// HZM coop [215] - real manning pose (was unarmed_idle: guy just standing there).
		// MG42_high_* = standing hands-on-grips; fire row keys off the actual trigger.
		coop_turret_stand_fire	: ATTACK_PRIMARY_BUTTON
		coop_turret_stand_idle	: default
	}
	
	states
	{
		STAND		: !IS_USING_VEHICLE
		STAND		: !IS_USING_TURRET
	}
}

////////////////////////////////////////////////////////////////
//
// TURRETS
//
////////////////////////////////////////////////////////////////

state TURRET_START
{
	legs
	{
		unarmed_idle : TURRET_TYPE "MG42"
		unarmed_idle : default
	}

	states
	{
		TURRET_USING			: ANIMDONE_LEGS
	}
}

state TURRET_USING
{
	legs
	{
		// HZM coop [215] - manning pose for ground turrets (MG42 nests) too
		coop_turret_stand_fire	: ATTACK_PRIMARY_BUTTON
		coop_turret_stand_idle	: default
	}

	states
	{
		STAND : !IS_USING_TURRET
	}
}

// HZM coop [216] - the coop manning pose (jeep .30cal / MG42 nests). Entered on the raw
// m_pTurret condition so it works regardless of carried weapons (bug-309).
state COOP_TURRET_MAN
{
	legs
	{
		coop_turret_stand_fire	: ATTACK_PRIMARY_BUTTON
		coop_turret_stand_idle	: default
	}

	states
	{
		STAND : !COOP_ON_TURRET
	}
}

// HZM coop [221] - FORCED variant for script-seated vehicle gunners (m1l3a/m1l3b jeep .30cal):
// the seat attach leaves ALL player-side turret signals bare (bug-309 paradox), so the map
// script forcelegsstate's in and out itself (DBNO/emote recipe). NO condition exits on purpose
// - the empty states block is the DBNO_BLEEDOUT precedent. The ATTACK row still animates fire.
state COOP_TURRET_MAN_F
{
	legs
	{
		coop_turret_stand_fire	: ATTACK_PRIMARY_BUTTON
		coop_turret_stand_idle	: default
	}

	states
	{
	}
}


////////////////////////////////////////////////////////////////
//
// HZM coop - EMOTES [211]
//
// Reachable ONLY via forcelegsstate (coop_mod/player.scr::playerEmote, name-append
// bus indices 23-25) - no entry edges anywhere, so STAND stays untouched. The anims
// are the model-selection-screen idles every player TIK already aliases
// (models/player/base/anims_shared.txt). Full-body legs anim owns every bone while
// torso STAND action is none. Movement / jump / crouch / fire / ADS / weapon switch
// cancel via the exits below; death force-jumps to KILLED regardless of state.
// (research: _research/player_actor_anims.md - a bad .st ERR_DROPs the server,
// boot-test after ANY edit here.)
//
////////////////////////////////////////////////////////////////

state EMOTE_SALUTE
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_emote_salute : default
	}

	states
	{
		STAND : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

// HZM coop [user 07-09] - TEAM REVIVE: the reviver kneels over a downed teammate while holding
// [USE]. Forced by dbno.scr::dbno_teamrevive_monitor; loops the pre-staged coop_dbno_medic kneel
// (self : ANIMDONE_LEGS = loop, same recipe as COOP_ANIMTEST2). Script forces STAND when the
// channel ends / cancels; moving or firing also cancels via the exits below.
state REVIVE_MEDIC
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_dbno_medic : default
	}

	states
	{
		REVIVE_MEDIC : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

// HZM coop [230] - ANIM TEST bay: plays the retargeted CoD2 sprint loop (coop_test_sprint alias)
// on the spot for eyeball QA. Trigger: console `append name ,t1x` (bus 27). Loops until any
// movement/action input, same cancel recipe as the looping emotes. PRIVATE EXPERIMENT.
// HZM coop [231] - sprint-candidate test bay 2 (coop_sprint_rifle_a)
state COOP_ANIMTEST2
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_sprint_rifle_a : default
	}

	states
	{
		COOP_ANIMTEST2 : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

// HZM coop [231] - sprint-candidate test bay 3 (coop_sprint_rifle_b)
state COOP_ANIMTEST3
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_sprint_rifle_b : default
	}

	states
	{
		COOP_ANIMTEST3 : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

// HZM coop [231] - sprint-candidate test bay 4 (coop_sprint_rifle_c)
state COOP_ANIMTEST4
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_sprint_rifle_c : default
	}

	states
	{
		COOP_ANIMTEST4 : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

state COOP_ANIMTEST
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_test_sprint : default
	}

	states
	{
		COOP_ANIMTEST : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

state EMOTE_ATEASE
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_emote_atease : default
	}

	states
	{
		EMOTE_ATEASE : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

state EMOTE_STRETCH
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_emote_stretch : default
	}

	states
	{
		EMOTE_STRETCH : ANIMDONE_LEGS
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON
	}
}

////////////////////////////////////////////////////////////////
//
// HZM coop LOBBY idle - MP skin-select mimic
//
// One self-cycling state that plays the weight-pooled coop_lobbyselect idle set (allied + axis
// selection anims), the same mechanism the multiplayer skin-select screen uses. Engine forces
// torso=STAND (action none) so each full-body legs clip owns the skeleton.
//
////////////////////////////////////////////////////////////////

// The single lobby idle state. Its legs anim is the weight-POOLED name 'coop_lobbyselect' - each time
// this state is (re)entered the anim system resolves it to a fresh weighted-random variation, and the
// only exit is ANIMDONE_LEGS which re-enters THIS state, so it endlessly cycles the pool, blending at
// each anim boundary. That is a 1:1 copy of how americanselectionidle/germanselectionidle drive the MP
// skin-select models. No movement/weapon exits: the lobby player is freezecontrol-locked (no input) and
// the rifle is slung stable, so nothing should fire them - dropping them guarantees the cycle never
// breaks (this is what makes it robust WITHOUT the FL_IMMOBILE freeze, which would stop the cycling).
state EMOTE_LOBBY_SELECT
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_pose_g100 : default
	}

	states
	{
		EMOTE_LOBBY_SELECT : ANIMDONE_LEGS
	}
}


////////////////////////////////////////////////////////////////
//
// HZM coop - SPRINT [212]
//
// Entered from RUN_FORWARD while the engine sprint state is active (COOP_SPRINTING =
// m_bCoopSprinting from TickSprint). One-handed classes play the AI sprint cycle (alert_sprint.skc,
// aliased coop_sprint_forward in models/player/base/anims_shared.txt). Falls back to
// RUN_FORWARD the moment sprint ends; jump/crouch/fall/stop exit like the run state.
//
////////////////////////////////////////////////////////////////

state SPRINT_FORWARD
{
	entrycommands
	{
		movementstealth "0.25"
		moveposflags "standing" "running"
	}

	legs
	{
		// [user 2026-08-18] "the thompson sprint should be used for all two handed weapons":
		// one-handed classes keep the alert dash, everything else (rifle/smg/mg/heavy/items)
		// runs the Omaha Thompson beach charge (coop_sprint_2h). Condition syntax copied
		// verbatim from the STAND idle block - .st errors ERR_DROP the server at first spawn.
		coop_sprint_forward : IS_WEAPONCLASS_ACTIVE "mainhand" "pistol"
		coop_sprint_forward : IS_WEAPONCLASS_ACTIVE "mainhand" "grenade"
		coop_sprint_2h : default
	}

	states
	{
		// exit the INSTANT sprint ends - checked before everything else. No ANIMDONE
		// self-transition: alert_sprint.skc is a looping anim (re-entry is a stick hazard).
		RUN_FORWARD : !COOP_SPRINTING

		FALL : FALLING

		CROUCH_IDLE : ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED : ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND : !HAS_VELOCITY
		STAND : BLOCKED "2"

		JUMP_FORWARD_RUN : +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}


////////////////////////////////////////////////////////////////
//
// HZM coop - DBNO CINEMATICS [213]
//
// Reachable ONLY via forcelegsstate from coop_mod/dbno.scr (no entry edges - the DBNO
// system owns entry/exit; KILLED force-overrides everything). Uses the engine's own
// major-pain collapse/crawl/death sequence + a ground writhe idle. Full-body anims:
// torso stays in STAND (action none) so the legs channel owns every bone.
//
////////////////////////////////////////////////////////////////

state DBNO_COLLAPSE
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_collapse : default
	}

	states
	{
		DBNO_IDLE : ANIMDONE_LEGS
	}
}

state DBNO_IDLE
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_idle : default
	}

	states
	{
		DBNO_CRAWL : FORWARD HAS_VELOCITY
		DBNO_CRAWL : BACKWARD HAS_VELOCITY
		DBNO_CRAWL : STRAFE_LEFT HAS_VELOCITY
		DBNO_CRAWL : STRAFE_RIGHT HAS_VELOCITY

		DBNO_IDLE : ANIMDONE_LEGS
	}
}

state DBNO_CRAWL
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_crawl : default
	}

	states
	{
		DBNO_IDLE : !HAS_VELOCITY

		DBNO_CRAWL : ANIMDONE_LEGS
	}
}

state DBNO_BLEEDOUT
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_bleedout : default
	}

	states
	{
	}
}

state DBNO_MEDIC
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_dbno_medic : default
	}

	states
	{
		STAND : FORWARD
		STAND : BACKWARD
		STAND : STRAFE_LEFT
		STAND : STRAFE_RIGHT
		STAND : +JUMP
		STAND : +CROUCH
		FALL : FALLING
		STAND : +ATTACK_PRIMARY_BUTTON
		STAND : +ATTACK_SECONDARY_BUTTON
		STAND : +HAS_WEAPON
		STAND : -HAS_WEAPON

		DBNO_MEDIC : ANIMDONE_LEGS
	}
}


////////////////////////////////////////////////////////////////
//
// HZM coop - TAKE COVER [214]
//
// Entered from STAND / CROUCH_IDLE on the engine cover conditions (COOP_COVER =
// standing back-to-wall valid, COOP_COVER_LOW = crouch-height obstacle ahead;
// both computed per frame in Player::TickCoopCover, which also CLEARS the
// request on movement/jump/death/mount - so the "!" exits below restore the
// default states the same frame anything invalidates the pose). Full-body AI
// cornering anims own every bone while the torso sits in COVER_TORSO (action
// none, coop_mod/player_Torso.st).
//
// BLIND FIRE: COOP_BLINDFIRE (covered + fire held + gun-class weapon) routes to
// the COVER_*_FIRE states. Their aliases carry the vanilla AI "N fire" server
// frame commands (models/player/base/anims_shared.txt) - the anim itself pulls
// the trigger, exactly like the stock 3rd-person *_fire action anims. The fire
// states MUST ping-pong back to the hold state on ANIMDONE_LEGS: a
// self-transition would early-return in SetPartAnim (same anim) and stick on
// the last frame with no restart and no further fire commands.
//
////////////////////////////////////////////////////////////////

state COVER_WALL
{
	entrycommands
	{
		modheight "stand"
		movementstealth "1.0"
		moveposflags "standing"
	}

	legs
	{
		coop_cover_wall : default
	}

	states
	{
		COVER_WALL_FIRE : COOP_BLINDFIRE

		STAND : !COOP_COVER

		FALL : FALLING
	}
}

state COVER_WALL_FIRE
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		// HZM coop [215] - spray around the DETECTED corner (side probe in TickCoopCover)
		// [216] overhead spray for RIGHT corners: the mp44 right-corner anim shoots with the
		// LEFT hand while the gun stays on tag_weapon_right = rifle at the ceiling (bug-310)
		coop_blindfire_low	: COOP_COVER_OPENRIGHT
		coop_blindfire_wall	: default
	}

	states
	{
		// pose dropped mid-burst (moved / killed the request) - bail immediately
		STAND : !COOP_COVER

		// burst finished - back to the hold; it re-dispatches here while fire stays held
		COVER_WALL : ANIMDONE_LEGS

		FALL : FALLING
	}
}

state COVER_LOW
{
	entrycommands
	{
		modheight "duck"
		movementstealth "1.25"
		moveposflags "crouching"
	}

	legs
	{
		coop_cover_low : default
	}

	states
	{
		// HZM coop [223] - RMB peek from LOW cover RISES to a standing hold so you can actually
		// shoot over the obstacle (user: "increase their height when you aim over shoulder").
		// Must sit above the blindfire row: while peeked, fire is AIMED (torso dispatch).
		COVER_LOW_PEEK : COOP_COVER_PEEK

		COVER_LOW_FIRE : COOP_BLINDFIRE

		// drop out still crouched - CROUCH_IDLE owns stand-up from there
		CROUCH_IDLE : !COOP_COVER_LOW

		FALL_DUCKED : FALLING
	}
}

// HZM coop [223] - standing peek-over hold for LOW cover: modheight "stand" raises the bbox and
// eye height for the duration of the peek (real line-of-sight over the obstacle), the standing
// wall-cover hold anim keeps the body at-cover, and the exit restores the crouch before COVER_LOW
// re-enters (its own entrycommands re-assert duck as well - belt and braces).
state COVER_LOW_PEEK
{
	entrycommands
	{
		modheight "stand"
		moveposflags "standing"
	}

	exitcommands
	{
		modheight "duck"
		moveposflags "crouching"
	}

	legs
	{
		coop_cover_wall : default
	}

	states
	{
		// peek released but the pose holds - tuck back down
		COVER_LOW : !COOP_COVER_PEEK

		// pose dropped entirely (moved / geometry lost)
		CROUCH_IDLE : !COOP_COVER_LOW

		FALL_DUCKED : FALLING
	}
}

state COVER_LOW_FIRE
{
	entrycommands
	{
		modheight "duck"
		moveposflags "crouching"
	}

	legs
	{
		coop_blindfire_low : default
	}

	states
	{
		CROUCH_IDLE : !COOP_COVER_LOW

		COVER_LOW : ANIMDONE_LEGS

		FALL_DUCKED : FALLING
	}
}


////////////////////////////////////////////////////////////////
// HZM coop [user 2026-08-02] bug-1291 - LOW-HEALTH LIMP.
//
// Entered from the WALK_*/RUN_* states while the engine conditional COOP_LIMPING is true
// (Player::TickLimp - health/max_health below coop_limpStart, on the ground, not downed, not on a
// vehicle/turret). Movement speed is clamped server-side in ClientMove, so the clip's own travel
// rate and the player's actual travel rate agree and the feet do not slide.
//
// LEGS ROW ORDER IS THE WHOLE DESIGN. walk_injured*.skc are UNARMED clips, and a STAND torso takes
// its animation FROM the legs (player_Torso.st:14-22) - so driving an armed player with one strips
// his weapon posture and swings an empty arm while he is visibly still holding the rifle. Retail
// ships exactly one ARMED injured cycle (rifle_run_injured.skc), so:
//   rifle class  -> rifle_walk_injured_forward, a real limp WITH the weapon up
//   other armed  -> their normal walk clip, unchanged posture; the limp reads through the
//                   first-person camera and the speed clamp instead
//   unarmed      -> the full walk_injured_* directional cycle
// Every state exits on !COOP_LIMPING as its FIRST row, and none of them self-transition on
// ANIMDONE - these are looping clips and re-entering a looping clip is a stick hazard
// (see the SPRINT_FORWARD comment).
////////////////////////////////////////////////////////////////

state LIMP_FORWARD
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}

	legs
	{
		// [user 2026-08-02] "I'd like for it to work regardless of what weapon you have."
		// EVERY armed class now gets the armed injured cycle, not just rifles. rifle_run_injured is
		// the only ARMED injured clip retail ships, so an SMG/pistol/MG player limps in a long-gun
		// carry rather than a perfectly matched pose - deliberately preferred over the alternative,
		// because the unarmed clip would swing an empty arm while the weapon is still visibly in
		// hand (a STAND torso takes its animation FROM the legs, player_Torso.st:19-21).
		rifle_walk_injured_forward	: HAS_WEAPON
		walk_injured_forward		: default
	}

	states
	{
		// leave the instant the limp clears - checked before anything else
		WALK_FORWARD	: !COOP_LIMPING

		FALL			: FALLING

		CROUCH_IDLE		: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED	: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND			: BLOCKED "2"
		STAND			: !HAS_VELOCITY

		LIMP_BACKWARD	: BACKWARD
		LIMP_LEFT		: STRAFE_LEFT !FORWARD !BACKWARD
		LIMP_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD

		// restart if our weapon has changed (edge-triggered, not ANIMDONE)
		LIMP_FORWARD	: +HAS_WEAPON
		LIMP_FORWARD	: -HAS_WEAPON

		JUMP_FORWARD_RUN : +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state LIMP_BACKWARD
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}

	legs
	{
		mp40_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_back				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_back	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_back					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_back				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		walk_injured_back				: default
	}

	states
	{
		// leave the instant the limp clears - checked before anything else
		WALK_BACKWARD	: !COOP_LIMPING

		FALL			: FALLING

		CROUCH_IDLE		: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED	: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND			: BLOCKED "2"
		STAND			: !HAS_VELOCITY

		LIMP_FORWARD	: FORWARD
		LIMP_LEFT		: STRAFE_LEFT !FORWARD !BACKWARD
		LIMP_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD

		// restart if our weapon has changed (edge-triggered, not ANIMDONE)
		LIMP_BACKWARD	: +HAS_WEAPON
		LIMP_BACKWARD	: -HAS_WEAPON

		JUMP_FORWARD_RUN : +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state LIMP_LEFT
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}

	legs
	{
		mp40_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_left				: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_left	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_left					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_left				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		walk_injured_left				: default
	}

	states
	{
		// leave the instant the limp clears - checked before anything else
		WALK_LEFT	: !COOP_LIMPING

		FALL			: FALLING

		CROUCH_IDLE		: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED	: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND			: BLOCKED "2"
		STAND			: !HAS_VELOCITY

		LIMP_FORWARD	: FORWARD
		LIMP_BACKWARD	: BACKWARD
		LIMP_RIGHT		: STRAFE_RIGHT !FORWARD !BACKWARD

		// restart if our weapon has changed (edge-triggered, not ANIMDONE)
		LIMP_LEFT	: +HAS_WEAPON
		LIMP_LEFT	: -HAS_WEAPON

		JUMP_FORWARD_RUN : +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

state LIMP_RIGHT
{
	entrycommands
	{
		movementstealth "0.75"
		moveposflags "standing" "walking"
	}

	legs
	{
		mp40_stand_walk_right				: IS_WEAPON_ACTIVE "mainhand" "MP40"
		mp44_stand_walk_right				: IS_WEAPON_ACTIVE "mainhand" "StG 44"
		bazooka_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Bazooka"
		bazooka_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Panzerschreck"
		shotgun_stand_walk_right			: IS_WEAPON_ACTIVE "mainhand" "Shotgun"
		steilhandgranate_stand_walk_right	: IS_WEAPON_ACTIVE "mainhand" "Stielhandgranate"
		pistol_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "pistol" 
		rifle_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "rifle" 
		grenade_stand_walk_right			: IS_WEAPONCLASS_ACTIVE "mainhand" "grenade" 
		smg_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "smg" 
		mg_stand_walk_right					: IS_WEAPONCLASS_ACTIVE "mainhand" "mg" 
//		pistol_stand_walk_right				: IS_WEAPONCLASS_ACTIVE "mainhand" "item" // hold all items like a pistol for now
		walk_injured_right			: default
	}

	states
	{
		// leave the instant the limp clears - checked before anything else
		WALK_RIGHT	: !COOP_LIMPING

		FALL			: FALLING

		CROUCH_IDLE		: ONGROUND +CROUCH !DUCKED_VIEW_IN_WATER
		CROUCH_DENIED	: ONGROUND +CROUCH DUCKED_VIEW_IN_WATER

		STAND			: BLOCKED "2"
		STAND			: !HAS_VELOCITY

		LIMP_FORWARD	: FORWARD
		LIMP_BACKWARD	: BACKWARD
		LIMP_LEFT		: STRAFE_LEFT !FORWARD !BACKWARD

		// restart if our weapon has changed (edge-triggered, not ANIMDONE)
		LIMP_RIGHT	: +HAS_WEAPON
		LIMP_RIGHT	: -HAS_WEAPON

		JUMP_FORWARD_RUN : +JUMP ONGROUND !DUCKED_VIEW_IN_WATER
	}
}

// [user 2026-08-10] SELF-REVIVE GET-UP. Two states so the rise is staged the way the retail
// animations were authored: struggle up onto the knees and HOLD there while the medkit is being
// applied, then rise to the feet only when it actually completes.
state DBNO_GETUP_KNEES
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_floortoknees : default
	}

	states
	{
		DBNO_GETUP_HOLD : ANIMDONE_LEGS
	}
}

// Kneeling hold - loops for as long as the channel runs. The script forces the next state on
// completion and forces DBNO_IDLE back if the player cancels or is knocked down again.
state DBNO_GETUP_HOLD
{
	entrycommands
	{
		moveposflags "crouching"
	}

	legs
	{
		coop_dbno_kneesidle : default
	}

	states
	{
		DBNO_GETUP_HOLD : ANIMDONE_LEGS
	}
}

// The actual rise. Exits to STAND on its own when the animation finishes, so the script does not
// have to time it.
state DBNO_GETUP_STAND
{
	entrycommands
	{
		moveposflags "standing"
	}

	legs
	{
		coop_dbno_kneestostand : default
	}

	states
	{
		STAND : ANIMDONE_LEGS
	}
}
