
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

typedef struct {
    unsigned channel;
    unsigned msb_bank;
    unsigned lsb_bank;
    unsigned instrument;
} MIDIchanstrument;

MIDIchanstrument target[2] = {{ 1, 0, 0, 1 }, {1, 0, 0, 1}};
int different_chanstruments = 0;

AudioUnit synthUnit;    // have to make it global and reachable by the callback routine
unsigned char mapping[99];
int sensitivity_correction              = 40;
int transpose_semitones                 = 0;
int interbank_offset_octaves            = 0;


    // creates any regular hexagonal mapping for AXIS-49 selfless mode
void create_selfless_mapping(unsigned char *map, int south_offset, int southeast_offset, unsigned start_note) {

    map[1] = (unsigned char)start_note;
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
            int cmd         = cmdchannel & 0xf0;
            int origchannel = cmdchannel & 0x0f;
            if( (cmd == kMidiMessage_NoteOff) || (cmd == kMidiMessage_NoteOn)) {
                int orignote =  packet->data[i+1];
                int origvelo =  packet->data[i+2];

                int mapped_note = mapping[orignote]
                                + ((orignote>49) ? 12*interbank_offset_octaves : 0)
                                + transpose_semitones;

                int target_channel = target[(orignote>49) ? different_chanstruments : 0].channel;

                int velocity = origvelo ? ((origvelo+sensitivity_correction<127) ? (origvelo+sensitivity_correction) : 127) : 0;

                MusicDeviceMIDIEvent(synthUnit, cmd | (target_channel-1), mapped_note, velocity, 0);

                NSLog(@"midiInput\t\t[channel=%2d]\tcmd=%3s\tnote=%3d\tvelocity=%3d", target_channel, (cmdchannel&16)?"On":"Off", mapped_note, velocity);
            } else {
                NSLog(@"midiInput\t\t[channel=%2d]\tcmdcode=0x%1x", origchannel, cmd>>4);
            }
        }

        packet = MIDIPacketNext(packet);
    }
}


void usage(const char *progname) {
    NSLog(@"Usage:\n\t%s [options]\n\nthe following options are recognized:\n\n\t{-b | -c | -j | -w}\t\t\t\t\t\tmutually exclusive layout option\n\t-a south_offset:southeast_offset:start_note\t\t\tset an arbitrary isomorphic layout based on two offsets and start_note\n\t-d midi_input_device_name\t\t\t\t\t'AXIS-49 2A' by default\n\t-i midi_instrument[:midi_channel[:msb_bank[:lsb_bank]]]\t\tdefault instrument\n\t-y midi_instrument[:midi_channel[:msb_bank[:lsb_bank]]]\t\tright bank's instrument if you want a different one\n\t-o interbank_offset_octaves\t\t\t\t\t0 by default, lets you split the banks' ranges apart\n\t-s sensitivity_correction\t\t\t\t\t40 by default, the whole point of writing this program :)\n\t-t transpose_semitones\t\t\t\t\t\t0 by default", progname);
    exit(0);
}


int main(int argc, char *argv[]) {

    OSStatus result;
    MIDIClientRef midiClient;
    MIDIPortRef inputPort;
    MIDIObjectRef endPoint;
    AUGraph graph = 0;
    char *device_name = (char *)"AXIS-49 2A";

        // mapping parameters default to Sonome ("harmonic table") layout
    int south_offset    = -7;
    int southeast_offset= -3;
    unsigned start_note = 81;

    int ch;
    while ((ch = getopt(argc, argv, "a:bcjwd:i:y:o:s:t:")) != -1) {
        switch (ch) {
            case 'a':
                    // arbitrary isomorphic hexagonal layout:
                sscanf(optarg, "%d:%d:%u", &south_offset, &southeast_offset, &start_note);
                break;
            case 'b':
                    // B-griff accordion mapping (from NW):
                south_offset    = +1;
                southeast_offset= +3;
                start_note      = 36;
                break;
            case 'c':
                    // C-griff accordion mapping (from NW):
                south_offset    = +2;
                southeast_offset= +3;
                start_note      = 32;
                break;
            case 'j':
                    // Janko piano mapping (from SW):
                south_offset    = -1;
                southeast_offset= +1;
                start_note      = 41;
                break;
            case 'w':
                    // Wicki-Hayden concertina mapping (from NW):
                south_offset    = +2;
                southeast_offset= +7;
                start_note      = 32;
                break;
            case 'd':
                device_name = optarg;
                break;
            case 'i':
                    // instrument and channel are base-1, msb_bank and lsb_bank are base-0
                    // set channel to 10 for percussion
                sscanf(optarg, "%u:%u:%u:%u", (unsigned *)&target[0].instrument, (unsigned *)&target[0].channel, (unsigned *)&target[0].msb_bank, (unsigned *)&target[0].lsb_bank);
                break;
            case 'y':
                    // instrument and channel are base-1, msb_bank and lsb_bank are base-0
                    // set channel to 10 for percussion
                sscanf(optarg, "%u:%u:%u:%u", (unsigned *)&target[1].instrument, (unsigned *)&target[1].channel, (unsigned *)&target[1].msb_bank, (unsigned *)&target[1].lsb_bank);
                different_chanstruments=1;
                break;
            case 'o':
                interbank_offset_octaves = atoi(optarg);
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

    create_selfless_mapping(mapping, south_offset, southeast_offset, start_note);

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

    for(int i=0;i<=different_chanstruments;i++) {
        NSLog(@"Setting bank[%d]", i);
                //set the bank
        require_noerr (result = MusicDeviceMIDIEvent(synthUnit, 
                                                    kMidiMessage_ControlChange | (target[i].channel-1), 
                                                    kMidiMessage_BankMSBControl | target[i].msb_bank, 0,
                                                    0/*sample offset*/), home);
        require_noerr (result = MusicDeviceMIDIEvent(synthUnit, 
                                                    kMidiMessage_ControlChange | (target[i].channel-1), 
                                                    kMidiMessage_BankLSBControl | target[i].lsb_bank, 0,
                                                    0/*sample offset*/), home);
                // set the instrument
        require_noerr (result = MusicDeviceMIDIEvent(synthUnit,
                                                    kMidiMessage_ProgramChange | (target[i].channel-1), 
                                                    (target[i].instrument-1), 0,
                                                    0/*sample offset*/), home);
    }

    NSLog(@"Ready to play");

    CFRunLoopRun();

home:
    if (graph) {
        AUGraphStop (graph); // stop playback - AUGraphDispose will do that for us but just showing you what to do
        DisposeAUGraph (graph);
    }
    return result;
}

