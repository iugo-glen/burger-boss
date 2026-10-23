extends Node
## Short original synthesized notes. Audio only starts after a player gesture.
var output: AudioStreamPlayer
var tone := PackedByteArray()

func _ready() -> void:
    output = AudioStreamPlayer.new()
    output.volume_db = -20
    add_child(output)

func play_note(frequency: float) -> void:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    var frames := 3307
    tone.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / 22050.0
        var envelope := pow(1.0 - float(i) / frames, 3.0)
        var sample := int(sin(TAU * frequency * t) * envelope * 16000)
        tone.encode_s16(i * 2, sample)
    stream.data = tone
    output.stream = stream
    output.play()
