
// Create and initialize the AUGraph needed to produce sound

#include <CoreServices/CoreServices.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h> //for AUGraph

// This call creates the Graph and the Synth unit...
OSStatus	CreateAUGraph (AUGraph &outGraph, AudioUnit &outSynth) {
	OSStatus result;
	//create the nodes of the graph
	AUNode synthNode, outNode;
	
#if (MACOSX_VERSION >= 1060)
	AudioComponentDescription cd;
#else
	ComponentDescription cd;
#endif
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;

	require_noerr (result = NewAUGraph (&outGraph), home);

	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_DLSSynth;

	require_noerr (result = AUGraphAddNode (outGraph, &cd, &synthNode), home);

	cd.componentType = kAudioUnitType_Output;
	cd.componentSubType = kAudioUnitSubType_DefaultOutput;  
	require_noerr (result = AUGraphAddNode (outGraph, &cd, &outNode), home);
	
	require_noerr (result = AUGraphOpen (outGraph), home);
	
	require_noerr (result = AUGraphConnectNodeInput (outGraph, synthNode, 0, outNode, 0), home);
	
	// ok we're good to go - get the Synth Unit...
	require_noerr (result = AUGraphNodeInfo(outGraph, synthNode, 0, &outSynth), home);

	// ok we're set up to go - initialize and start the graph
	require_noerr (result = AUGraphInitialize (outGraph), home);
	require_noerr (result = AUGraphStart (outGraph), home);

home:
	return result;
}

