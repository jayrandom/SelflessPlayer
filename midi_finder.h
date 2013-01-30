
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


MIDIEndpointRef find_midi_endpoint_by_locator_type_idx(const char *locator, int source_or_dest, ItemCount sdIndex) {
    // the usual Mac memory BS
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSString *NS_locator = [[NSString alloc] initWithCString:locator encoding:NSASCIIStringEncoding];

    NSArray  *split = [NS_locator componentsSeparatedByString:@"::"];
    NSString *NS_device_name = [split objectAtIndex: 0];
    NSString *NS_entity_name = [split objectAtIndex: 1];

        // How many MIDI devices do we have?
    ItemCount deviceCount = MIDIGetNumberOfDevices();
    
        // Iterate through all MIDI devices
    for (ItemCount deviceIndex = 0 ; deviceIndex < deviceCount ; ++deviceIndex) {

        // Grab a reference to current device
        MIDIDeviceRef midiDevice = MIDIGetDevice(deviceIndex);

        if([getName(midiDevice) isEqualToString: NS_device_name]) {

            // How many entities do we have?
            ItemCount entityCount = MIDIDeviceGetNumberOfEntities(midiDevice);

            // Iterate through this device's entities
            for (ItemCount entityIndex = 0 ; entityIndex < entityCount ; ++entityIndex) {

                // Grab a reference to current entity
                MIDIEntityRef midiEntity = MIDIDeviceGetEntity(midiDevice, entityIndex);

                if([getName(midiEntity) isEqualToString: NS_entity_name]) {

                    MIDIEndpointRef midiEndpoint = source_or_dest
                        ? MIDIEntityGetDestination(midiEntity, sdIndex)
                        : MIDIEntityGetSource(midiEntity, sdIndex);

                    return midiEndpoint;
                }
            }
        }
    }
    return nil;
}


const char *midi_device_list() {
    // the usual Mac memory BS
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // How many MIDI devices do we have?
    ItemCount deviceCount = MIDIGetNumberOfDevices();

    NSMutableArray *device_list_array = [[NSMutableArray alloc] initWithCapacity:deviceCount];

    // Iterate through all MIDI devices
    for (ItemCount deviceIndex = 0 ; deviceIndex < deviceCount ; ++deviceIndex) {

        // Grab a reference to current device
        MIDIDeviceRef midiDevice = MIDIGetDevice(deviceIndex);

        // How many entities do we have?
        ItemCount entityCount = MIDIDeviceGetNumberOfEntities(midiDevice);

        // An accumulating array to hold entities' names
        NSMutableArray *entity_list_array = [[NSMutableArray alloc] initWithCapacity:entityCount];

        // Iterate through this device's entities
        for (ItemCount entityIndex = 0 ; entityIndex < entityCount ; ++entityIndex) {

            // get the entity's name
            NSString *entity_name = [NSString stringWithFormat:@"\"%@::%@\"", getName(midiDevice), getName(MIDIDeviceGetEntity(midiDevice, entityIndex))];
            // and push it into the accumulator
            [entity_list_array addObject: entity_name ];
        }

        // Is this device online? (Currently connected?)
        SInt32 isOffline = 0;
        MIDIObjectGetIntegerProperty(midiDevice, kMIDIPropertyOffline, &isOffline);

        NSString *device_string = [NSString stringWithFormat:@"\t%@[%s]:\t%@",
            getName(midiDevice),
            (isOffline ? "offline" : "online"),
            [entity_list_array componentsJoinedByString: @", "]
        ];
        [device_list_array addObject: device_string];
    }

    return [[device_list_array componentsJoinedByString: @"\n"] UTF8String];
}

