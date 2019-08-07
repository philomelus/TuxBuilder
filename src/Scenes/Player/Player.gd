extends KinematicBody2D

# Instant speed when starting walk
const WALK_ADD = 120.0
# Speed Tux accelerates per second when walking
const WALK_ACCEL = 350.0
# Speed Tux accelerates per second when running
const RUN_ACCEL = 400.0

# Speed you need to start running
const WALK_MAX = 230.0
# Maximum horizontal speed
const RUN_MAX = 320.0
# Backflip horizontal speed
const BACKFLIP_SPEED = -128

# Acceleration when holding the opposite direction
const TURN_ACCEL = 900.0
# Speed which Tux slows down
const SKID_ACCEL = 950.0
# Speed which Tux skids
const FRICTION = 0.93
# Speed Tux slows down skidding
const SKID_TIME = 12

# Jump velocity
const JUMP_POWER = 580
# Running Jump / Backflip velocity
const RUNJUMP_POWER = 640
# Gravity
const GRAVITY = 20.0
# Amount of frames Tux can still jump after falling off a ledge
const LEDGE_JUMP = 3
# What angle is considered floor
const FLOOR = Vector2(0, -1)
# Fireball speed
const FIREBALL_SPEED = 500

var velocity = Vector2()
var on_ground = 0 # Frames Tux has been in air (0 if grounded)
var jumpheld = 0 # Time the jump key has been held
var running = 0 # If horizontal speed is higher than walk max
var skid = 0 # Time skidding
var ducking = false # Ducking
var backflip = false # Backflipping
var backflip_rotation = 0 # Backflip rotation

var state = "fire" # Tux's power-up state

#=============================================================================
# PHYSICS

func _physics_process(delta):

	# Horizontal movement
	if Input.is_action_pressed("move_right") and (ducking == false or on_ground != 0) and backflip == false:
		$AnimatedSprite.scale.x = 1
		if skid <= 0 and velocity.x >= 0:
			if velocity.x == 0:
				velocity.x += WALK_ADD
			if running == 1:
					velocity.x += RUN_ACCEL / 60
			else: velocity.x += WALK_ACCEL / 60

			# Skidding and air turning
		if velocity.x < 0:
			if on_ground == 0:
				velocity.x += SKID_ACCEL / 60
				if skid == 0 and velocity.x <= -WALK_MAX:
					skid = SKID_TIME
			else: velocity.x += TURN_ACCEL / 60

	else: if Input.is_action_pressed("move_left") and (ducking == false or on_ground != 0) and backflip == false:
		$AnimatedSprite.scale.x = -1
		if skid <= 0 and velocity.x <= 0:
			if velocity.x == 0:
				velocity.x -= WALK_ADD
			if running == 1:
					velocity.x -= RUN_ACCEL / 60
			else: velocity.x -= WALK_ACCEL / 60

		# Skidding and air turning
		if velocity.x > 0:
			if on_ground == 0:
				velocity.x -= SKID_ACCEL / 60
				if skid == 0 and velocity.x >= WALK_MAX:
					skid = SKID_TIME
			else: velocity.x -= TURN_ACCEL / 60

	else: if backflip == false: velocity.x *= FRICTION

	# Speedcap
	if velocity.x >= RUN_MAX:
		velocity.x = RUN_MAX
	if velocity.x <= -RUN_MAX:
		velocity.x = -RUN_MAX

	# Don't slide on the ground
	if abs(velocity.x) < 50:
		velocity.x = 0

	# Skid
	if skid > 0:
		if skid == SKID_TIME:
			$SFX/Skid.play()
		skid -= 1
	else:
		skid = 0

	# Gravity
	velocity.y += GRAVITY

	velocity = move_and_slide(velocity, FLOOR)

	# Floor check
	if is_on_floor():
		on_ground = 0
		if backflip == true:
			backflip = false
			velocity.x = 0
	else:
		on_ground += 1

	# Running
	if abs(velocity.x) > WALK_MAX:
		running = 1
	else: running = 0

	# Ducking
	if on_ground == 0:
		if not Input.is_action_pressed("duck"):
			ducking = false
		if Input.is_action_pressed("duck") or ($StandWindow.is_colliding() == true and state != "small") and backflip == false:
				ducking = true

	# Jump buffering
	if Input.is_action_pressed("jump"):
			jumpheld += 1
	else:
			jumpheld = 0

	# Jumping
	if Input.is_action_pressed("jump"):
		if jumpheld <= 15:
			if on_ground <= LEDGE_JUMP:
				if state != "small" and Input.is_action_pressed("duck") == true and (Input.is_action_pressed("move_left") == false and Input.is_action_pressed("move_right") == false) and $StandWindow.is_colliding() == false:
						backflip = true
						ducking = false
						backflip_rotation = 0
						velocity.y = -RUNJUMP_POWER
						$SFX/Flip.play()
				elif running == 1:
					velocity.y = -RUNJUMP_POWER
					
				else:
					velocity.y = -JUMP_POWER
				if state == "small":
					$SFX/Jump.play()
				else: $SFX/BigJump.play()
				on_ground = LEDGE_JUMP + 1
			jumpheld = 16
	# Jump cancelling
	if on_ground != 0 and not Input.is_action_pressed("jump") and backflip == false:
		if velocity.y < 0:
			velocity.y *= 0.5

	# Backflip speed and rotation
	$AnimatedSprite.rotation_degrees = 0
	if backflip == true:
		if $AnimatedSprite.scale.x == 1:
			velocity.x = BACKFLIP_SPEED
			backflip_rotation -= 15
		else:
			velocity.x = -BACKFLIP_SPEED
			backflip_rotation += 15
		$AnimatedSprite.rotation_degrees = backflip_rotation

	# Animations
	if backflip == true:
		$AnimatedSprite.play("backflip")
	elif ducking == true:
		$AnimatedSprite.play("duck")
	else:
		if on_ground == 0:
			if skid > 0:
				$AnimatedSprite.play("skid")
			else: if abs(velocity.x) >= 20:
				$AnimatedSprite.play("walk")
			else: $AnimatedSprite.play("idle")
		else: $AnimatedSprite.play("jump")

	if ducking == true or state == "small":
		$BigHitbox.disabled = true
		$SmallHitbox.disabled = false
	else:
		$BigHitbox.disabled = false
		$SmallHitbox.disabled = true

	# Shooting
	if Input.is_action_just_pressed("action") and state == "fire" and get_tree().get_nodes_in_group("bullets").size() < 2:
		$SFX/Shoot.play()
		var fireball = preload("res://Scenes/Objects/Fireball.tscn").instance()
		if ducking == true and backflip == false:
			fireball.position = $AnimatedSprite/ShootLocationDuck.global_position
		else: fireball.position = $AnimatedSprite/ShootLocation.global_position
		fireball.velocity = Vector2((FIREBALL_SPEED * $AnimatedSprite.scale.x) + velocity.x,0)
		fireball.add_collision_exception_with(self) # Prevent fireball colliding with player
		get_parent().add_child(fireball) # Shoot fireball as child of player