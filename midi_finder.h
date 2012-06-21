
// Find the MIDI device by its name and return the source by a given index

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

NSString *getName(MIDIObjectRef object) {
  // Returns the name of a given MIDIObjectRef as an NSString
  CFStringRef name = nil;
  if (noErr != MIDIObjectGetStringProperty(object, kMIDIPropertyName, &name))
    return nil;
  return (NSString *)name;
}

SInt32 getUniqueId(MIDIObjectRef object) {
  // Returns the unique Id of a given MIDIObjectRef
  SInt32 value = 0;
  if (noErr != MIDIObjectGetIntegerProperty(object, kMIDIPropertyUniqueID, &value))
    return 0;
  return value;
}

MIDIDeviceRef find_midi_device_by_name(char *query_device_name) {

    NSString *NS_query_device_name = 
        [[NSString alloc] initWithCString:query_device_name encoding:NSASCIIStringEncoding];

        // How many MIDI devices do we have?
    ItemCount deviceCount = MIDIGetNumberOfDevices();

        // Iterate through all MIDI devices
    for (ItemCount i = 0 ; i < deviceCount ; ++i) {

        // Grab a reference to current device
        MIDIDeviceRef midiDevice = MIDIGetDevice(i);

        if([getName(midiDevice) isEqualToString: NS_query_device_name]) {
            return midiDevice;
        }
    }
    return nil;
}

MIDIEndpointRef find_midi_source_by_device_name_entity_idx_src_idx(char *query_device_name, ItemCount entity_idx, ItemCount src_idx) {

    NSString *NS_query_device_name = 
        [[NSString alloc] initWithCString:query_device_name encoding:NSASCIIStringEncoding];

        // How many MIDI devices do we have?
    ItemCount deviceCount = MIDIGetNumberOfDevices();

    
        // Iterate through all MIDI devices
    for (ItemCount i = 0 ; i < deviceCount ; ++i) {

        // Grab a reference to current device
        MIDIDeviceRef midiDevice = MIDIGetDevice(i);

        if([getName(midiDevice) isEqualToString: NS_query_device_name]) {

            MIDIEntityRef midiEntity = MIDIDeviceGetEntity(midiDevice, entity_idx);

            MIDIEndpointRef midiSource = MIDIEntityGetSource(midiEntity, src_idx);

            return midiSource;
        }
    }
    return nil;
}


