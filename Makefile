
#MACOSX_VERSION=1050
MACOSX_VERSION=1060

SelflessPlayer: selfless_player.mm midi_finder.h create_aug.h
	g++ -DMACOSX_VERSION=$(MACOSX_VERSION) -framework Foundation -framework CoreServices -framework CoreMIDI -framework AudioUnit -framework AudioToolbox -o SelflessPlayer selfless_player.mm

