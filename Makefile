
#MACOSX_VERSION=1050    ## Please uncomment this line on Leopard
MACOSX_VERSION=1060     ## Please uncomment this line on Snow Leopard

SelflessPlayer: selfless_player.mm midi_finder.h create_aug.h
	g++ -DMACOSX_VERSION=$(MACOSX_VERSION) -framework Foundation -framework CoreServices -framework CoreMIDI -framework AudioUnit -framework AudioToolbox -o SelflessPlayer selfless_player.mm

