class_name LanDiscovery
extends Node

# Owns ONLY LAN discovery: UDP broadcast beacons (host) and listening
# (client) on port 8888. It never opens the game connection - it reports
# a found host and the LanManager connects. (Single Responsibility.)

signal host_found(ip: String, port: int)

const PORT := 8888
const MAGIC := "LOSTFRONTIER"

var _udp: PacketPeerUDP = null
var _broadcasting: bool = false
var _listening: bool = false
var _timer: float = 0.0

func start_broadcast(game_port: int) -> void:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_broadcasting = true
	_timer = 0.0

func start_listening() -> void:
	stop()
	_udp = PacketPeerUDP.new()
	if _udp.bind(PORT) != OK:
		return
	_listening = true

func stop() -> void:
	_broadcasting = false
	_listening = false
	if _udp != null:
		_udp.close()
		_udp = null

func _process(delta: float) -> void:
	if _udp == null:
		return
	if _broadcasting:
		_timer -= delta
		if _timer <= 0.0:
			_timer = 1.0
			_udp.set_dest_address("255.255.255.255", PORT)
			_udp.put_packet((MAGIC + ":7777").to_utf8_buffer())
	if _listening:
		while _udp.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _udp.get_packet()
			var text: String = pkt.get_string_from_utf8()
			if text.begins_with(MAGIC):
				var ip: String = _udp.get_packet_ip()
				host_found.emit(ip, 7777)
