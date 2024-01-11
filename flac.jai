#scope_module

flac_parse_data :: (str: string) -> Sound_Data {
    data: Sound_Data;
    channel_count: u32;
    sample_rate: u32;
    frame_count: u64;
    
    c_str := to_c_string(str);
    
    samples := drflac_open_memory_and_read_pcm_frames_s16(str.data, xx str.count, *channel_count, *sample_rate, *frame_count, null);
    assert(samples != null);
    assert(channel_count <= 2, "Only mono and stereo are supported");
    
    data.samples = samples;
    data.is_stereo = channel_count == 2;
    
    data.sample_count = xx (frame_count * channel_count);
    data.time_length = cast(float64)data.sample_count / sample_rate / channel_count;
    data.rate_scale = cast(float64)sample_rate / OUTPUT_SAMPLE_RATE;
    
    return data;
}

#scope_file

#if OS == .WINDOWS {
    dr_flac :: #library,no_dll "win/dr_flac";
}

DRFlac_Allocation_Callbacks :: struct {
    user_data: *void;
    on_malloc: (u64, *void) -> *void #c_call;
    on_realloc: (*void, u64, *void) -> *void #c_call;
    on_free: (*void, *void) #c_call;
}

drflac_open_memory_and_read_pcm_frames_s16 :: (data: *void, data_size: u64, channels: *u32, sample_rate: *u32, frame_count: *u64, allocation_callbacks: *DRFlac_Allocation_Callbacks) -> *s16 #foreign dr_flac;