
// A stand-alone command-line driven program that produces sounds when you play on AXIS-49 hexagonal keyboard.
// You can choose a regular layout (sonome/wikihayden/bgriff/cgriff/janko), the midi instrument,
// transpose two banks separately by octaves, transpose the whole thing.

#import "midi_finder.h"
#import "create_aug.h"
#import <stdlib.h>              /* atoi() */
#import <unistd.h>              /* getopt() */


// some MIDI constants:
enum {
        kMidiMessage_NoteOff                    = 0x80,
        kMidiMessage_NoteOn                     = 0x90,
        kMidiMessage_ControlChange              = 0xB0,
        kMidiMessage_ProgramChange              = 0xC0,
        kMidiMessage_BankMSBControl             = 0,
        kMidiMessage_BankLSBControl             = 32
};


AudioUnit synthUnit;    // have to make it global and reachable by the callback routine
unsigned char mapping[99];
int sensitivity_correction              = 0;
int transpose_semitones                 = 0;
int left_bank_offset_octaves            = 0;
int right_bank_offset_octaves           = 0;


    // creates any regular hexagonal mapping for AXIS-49 selfless mode
void create_selfless_mapping(unsigned char *map, char start_note, int south_offset, int southeast_offset) {

    map[1] = start_note;
    for(unsigned selfless_idx=2;selfless_idx<=98;selfless_idx++) {
        if( (selfless_idx-1) % 7 == 0) {    // top of a row
            unsigned column = (selfless_idx-1) / 7;
            unsigned north_flag = (column-((column<=7)?1:0)) % 2;

            map[selfless_idx] = map[selfless_idx-7] + southeast_offset - north_flag*south_offset;

        } else {    // next in a row
            map[selfless_idx] = map[selfless_idx-1] + south_offset;
        }
    }
}


static void midiInputCallback (const MIDIPacketList *pktlist, void *procRef, void *srcRef) {
    
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
    for (int j=0; j < pktlist->numPackets; j++) {
        for (int i=0; i < packet->length; i+=3) {
            int cmdchannel = packet->data[i];
            if( (cmdchannel == kMidiMessage_NoteOff) || (cmdchannel == kMidiMessage_NoteOn)) {
                int orignote =  packet->data[i+1];
                int origvelo =  packet->data[i+2];

                int mapped_note = mapping[orignote]
                                + 12*((orignote>49) ? right_bank_offset_octaves : left_bank_offset_octaves)
                                + transpose_semitones;

                int velocity = origvelo ? ((origvelo+sensitivity_correction<127) ? (origvelo+sensitivity_correction) : 127) : 0;

                MusicDeviceMIDIEvent(synthUnit, cmdchannel, mapped_note, velocity, 0);

                NSLog(@"midiInput\t\t[channel=%2d]\tcmd=%3s\tnote=%3d\tvelocity=%3d", cmdchannel&15, (cmdchannel&16)?"On":"Off", mapped_note, velocity);
            } else {
                NSLog(@"midiInput\t\t[channel=%2d]\tcmdcode=0x%02x", cmdchannel&15, cmdchannel>>4);
            }
        }

        packet = MIDIPacketNext(packet);
    }
}


void usage(const char *progname) {
    NSLog(@"Usage:\n\t%s [-d midi_input_device_name] [-i midi_instrument_number] [-l left_bank_offset_octaves] [-r right_bank_offset_octaves] [-s sensitivity_correction] [-t transpose_semitones] [{-b | -c | -j | -w}]", progname);
    exit(0);
}


int main(int argc, char *argv[]) {

    OSStatus result;
    MIDIClientRef midiClient;
    MIDIPortRef inputPort;
    MIDIObjectRef endPoint;
    AUGraph graph = 0;
    int midiChannelInUse = 0;
    int midiInstrumentToPlay = 1;
    char *device_name = (char *)"AXIS-49 2A";

    create_selfless_mapping(mapping, 81, -7, -3);   // sonome ("harmonic table") mapping (default)
        
    int ch;
    while ((ch = getopt(argc, argv, "bcjwd:i:l:r:s:t:")) != -1) {
        switch (ch) {
            case 'b':
                create_selfless_mapping(mapping, 36, +1, +3);   // B-griff accordion mapping (from NW)
                break;
            case 'c':
                create_selfless_mapping(mapping, 32, +2, +3);   // C-griff accordion mapping (from NW)
                break;
            case 'j':
                create_selfless_mapping(mapping, 41, -1, +1);   // Janko piano mapping (from SW)
                break;
            case 'w':
                create_selfless_mapping(mapping, 32, +2, +7);   // Wicki-Hayden concertina mapping (from NW)
                break;
            case 'd':
                device_name = optarg;
                break;
            case 'i':
                midiInstrumentToPlay = atoi(optarg)-1;
                break;
            case 'l':
                left_bank_offset_octaves = atoi(optarg);
                break;
            case 'r':
                right_bank_offset_octaves = atoi(optarg);
                break;
            case 's':
                sensitivity_correction = atoi(optarg);
                break;
            case 't':
                transpose_semitones = atoi(optarg);
                break;
            default:
                usage(argv[0]);
            }
     }

        // Setting up MIDI part (with the callback)
    require_noerr( result = MIDIClientCreate(CFSTR("MIDI client"), NULL, NULL, &midiClient), home);
    require_noerr( result = MIDIInputPortCreate(midiClient, CFSTR("Input"), midiInputCallback, NULL, &inputPort), home);
    endPoint = find_midi_source_by_device_name_entity_idx_src_idx( device_name, 0, 0 );
#if (MACOSX_VERSION >= 1060)
    require_noerr( result = MIDIPortConnectSource(inputPort, endPoint, NULL), home);
#else
    require_noerr( result = MIDIPortConnectSource((OpaqueMIDIPort*)inputPort, (OpaqueMIDIEndpoint*)endPoint, NULL), home);
#endif

        // Setting up sound generation
    require_noerr (result = CreateAUGraph (graph, synthUnit), home);
            //set our bank
    require_noerr (result = MusicDeviceMIDIEvent(synthUnit, 
                                                kMidiMessage_ControlChange | midiChannelInUse, 
                                                kMidiMessage_BankMSBControl, 0,
                                                0/*sample offset*/), home);
            // set the instrument
    require_noerr (result = MusicDeviceMIDIEvent(synthUnit,
                                                kMidiMessage_ProgramChange | midiChannelInUse, 
                                                midiInstrumentToPlay /* instrument */, 0,
                                                0/*sample offset*/), home);

    NSLog(@"Ready to play");

    CFRunLoopRun();

home:
    if (graph) {
        AUGraphStop (graph); // stop playback - AUGraphDispose will do that for us but just showing you what to do
        DisposeAUGraph (graph);
    }
    return result;
}

