#scope_module

flac_parse_data :: (str: string) -> Sound_Data {
    data: Sound_Data;
    channel_count: u32;
    sample_rate: u32;
    frame_count: u64;
    
    samples := drflac_open_memory_and_read_pcm_frames_s16(str.data, xx str.count, *channel_count, *sample_rate, *frame_count, null);
    assert(samples != null);
    assert(channel_count <= 2, "Only mono and stereo are supported");
    
    data.samples = samples;
    data.sample_count = xx (frame_count * channel_count);
    data.sample_rate = sample_rate;
    data.channel_count = xx channel_count;
    
    return data;
}

flac_free_data :: (data: Sound_Data) {
    drflac_free(data.samples, null);
}

#scope_file

#if OS == .WINDOWS {
    dr_flac :: #library,no_dll "win/dr_flac";
}

// @Todo: Hook up to jai allocator
DRFlac_Allocation_Callbacks :: struct {
    user_data: *void;
    on_malloc: (u64, *void) -> *void #c_call;
    on_realloc: (*void, u64, *void) -> *void #c_call;
    on_free: (*void, *void) #c_call;
}

drflac_open_memory_and_read_pcm_frames_s16 :: (data: *void, data_size: u64, channels: *u32, sample_rate: *u32, frame_count: *u64, allocation_callbacks: *DRFlac_Allocation_Callbacks) -> *s16 #foreign dr_flac;
drflac_free :: (p: *void, allocation_callbacks: *DRFlac_Allocation_Callbacks) #foreign dr_flac;