
SelflessPlayer: selfless_player.mm midi_finder.h create_aug.h
	g++ -framework Foundation -framework CoreServices -framework CoreMIDI -framework AudioUnit -framework AudioToolbox -o SelflessPlayer selfless_player.mm

