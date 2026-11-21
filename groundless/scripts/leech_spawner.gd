class_name LeechSpawner
extends Node3D
## Sends a pod-leech toward the raft now and then (one at a time). It appears about 35 m
## away, near the raft's height, and swims in. In the "recentre" group, so leeches (its
## children) move with every recentre.

@export var raft: Raft

var timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recentre")
	_rng.randomize()
	timer = Tuning.leech_first_delay


func active() -> PodLeech:
	for child in get_children():
		if child is PodLeech and child.state != PodLeech.State.DEAD:
			return child
	return null


func _physics_process(delta: float) -> void:
	if raft == null or active() != null:
		return
	timer -= delta
	if timer <= 0.0:
		spawn()
		timer = _rng.randf_range(Tuning.leech_interval_min, Tuning.leech_interval_max)


func spawn() -> PodLeech:
	var leech := PodLeech.new()
	leech.raft = raft
	add_child(leech)
	var a := _rng.randf() * TAU
	leech.global_position = raft.global_position + Vector3(cos(a), 0, sin(a)) * 35.0 + Vector3.UP * _rng.randf_range(0.0, 5.0)
	return leech
