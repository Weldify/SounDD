#import "Wav_File";

#scope_module

wav_parse_data :: (str: string) -> Sound_Data {
    data: Sound_Data;
    
    format, samples, success := get_wav_header(str);
    assert(success, "Failed to read .wav file");
    assert(format.nChannels <= 2, "Only mono and stereo are supported");
            
    data.samples = cast(*s16)samples.data;
    data.is_stereo = format.nChannels == 2;
    
    data.sample_count = xx (samples.count / 2); // @Note: I don't know why this is right
    data.time_length = cast(float64)data.sample_count / format.nSamplesPerSec / format.nChannels;
    data.rate_scale = cast(float64)format.nSamplesPerSec / OUTPUT_SAMPLE_RATE;
    
    return data;
}