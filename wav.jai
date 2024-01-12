#import "Wav_File";

#scope_module

wav_decode_string :: (str: string) -> Sound_Data {
    data: Sound_Data;
    
    format, samples, success := get_wav_header(str);
    assert(success, "Failed to read .wav file");
    assert(format.nChannels <= 2, "Only mono and stereo are supported");
            
    data.samples = cast(*s16)samples.data;
    data.sample_count = xx (samples.count / 2); // @Note: I don't know why this is right
    data.sample_rate = xx format.nSamplesPerSec;
    data.channel_count = xx format.nChannels;
    
    return data;
}