// mic-in-use.swift — exit 0 if ANY audio input device is actively running
// (the same signal that drives the macOS orange mic dot), else exit 1.
// Arch-independent: uses the CoreAudio HAL, not ioreg (which is unreliable on
// Apple Silicon). Compiled once to `mic-in-use` and called by in-call.sh.
import CoreAudio
import Foundation

func prop(_ selector: AudioObjectPropertySelector,
          _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                               mElement: kAudioObjectPropertyElementMain)
}

// Enumerate all audio devices.
var addr = prop(kAudioHardwarePropertyDevices)
var dataSize: UInt32 = 0
guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize) == noErr else {
    exit(1)
}
let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
var devices = [AudioObjectID](repeating: 0, count: count)
guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &devices) == noErr else {
    exit(1)
}

for dev in devices {
    // Only consider devices that have input channels (a microphone source).
    var inAddr = prop(kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput)
    var cfgSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(dev, &inAddr, 0, nil, &cfgSize) == noErr, cfgSize > 0 else { continue }
    let bufList = UnsafeMutableRawPointer.allocate(byteCount: Int(cfgSize),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { bufList.deallocate() }
    guard AudioObjectGetPropertyData(dev, &inAddr, 0, nil, &cfgSize, bufList) == noErr else { continue }
    let abl = UnsafeMutableAudioBufferListPointer(bufList.assumingMemoryBound(to: AudioBufferList.self))
    let inputChannels = abl.reduce(0) { $0 + Int($1.mNumberChannels) }
    if inputChannels == 0 { continue }

    // Is this input device currently running (capturing) for anyone?
    var runAddr = prop(kAudioDevicePropertyDeviceIsRunningSomewhere)
    var running: UInt32 = 0
    var runSize = UInt32(MemoryLayout<UInt32>.size)
    if AudioObjectGetPropertyData(dev, &runAddr, 0, nil, &runSize, &running) == noErr, running != 0 {
        exit(0) // mic is live
    }
}
exit(1) // no input device active
