// Version: 0.2.0

#module_parameters(SUPPORTED_FORMATS := Supported_Formats.WAV, SAMPLE_RATE: u32 = 44100) {
    Supported_Formats :: enum_flags {
        WAV;
    }
}

#import "Basic";
#import "Math";
#import "File";
#import "String";
#import "Thread";

#if SUPPORTED_FORMATS & .WAV {
    #import "Wav_File";
}

Audio_Format :: enum {
    WAV;
}

Sound_Data :: struct {
    is_stereo: bool;
    sample_count: u32;
    samples_per_frame: float64;
    time_length: float64;
    
    owned_source: string;
    samples: *s16;
}

Sound :: struct {
    volume: float32 = 1;
    speed: float32 = 1;
    time_position: float64;
    
    flags: enum_flags u8 {
        IS_PLAYING;
        
        SHOULD_REPEAT;
        DONT_DESTROY_AFTER_FINISH;
    };
    
    data: Sound_Data;
}

sound_data_load_from_file :: (path: string) -> Sound_Data {
    contents, success := read_entire_file(path);
    assert(success, "Failed to read file");
    
    splits := split(path, ".");
    extension := splits[splits.count-1];
    
    data: Sound_Data;
    if extension == "wav" {
        data = sound_data_load_from_string(contents, .WAV);
    } else assert(false, "Unsupported extension");
    
    data.owned_source = contents;
    
    return data;
}

sound_data_load_from_string :: (str: string, format: Audio_Format) -> Sound_Data {
    data: Sound_Data;
    
    if format == .WAV {
        #assert SUPPORTED_FORMATS & .WAV;
        
        format, samples, success := get_wav_header(str);
        assert(success, "Failed to read .wav file");
        assert(format.nChannels <= 2, "Only mono and stereo are supported");
        
        data.samples = cast(*s16)samples.data;
        data.is_stereo = format.nChannels == 2;
        
        // Because the amount of output channels is 2
        data.sample_count = xx (samples.count / 2);
        data.time_length = cast(float64)data.sample_count / SAMPLE_RATE / format.nChannels;
        data.samples_per_frame = data.time_length / data.sample_count;
    } else assert(false, "Unsupported format");

    return data;
}

sound_data_free :: (data: Sound_Data) {
    if data.owned_source.data == null return;
    
    free(data.owned_source);
}

create :: (data: Sound_Data) -> *Sound {
    sound := New(Sound);
    sound.data = data;
    
    return sound;
}

destroy :: (sound: *Sound) {
    stop(sound);
    free(sound);
    print("deetroo");
}

play :: (using sound: *Sound) {
    if flags & .IS_PLAYING return;
    flags |= .IS_PLAYING;
    
    lock(*main_mutex);
    array_add(*sounds_that_are_playing, sound);
    unlock(*main_mutex);
}

stop :: (using sound: *Sound) {
    if ~flags & .IS_PLAYING return;
    flags &= ~.IS_PLAYING;
    
    lock(*main_mutex);
    removed_amount := array_unordered_remove_by_value(*sounds_that_are_playing, sound, true);
    unlock(*main_mutex);
    
    assert(removed_amount == 1);
    
    time_position = 0;
}

audio_init :: () {
    init(*main_mutex);

    // @Note: If anything randomly breaks, I will blame multithreading
    saudio_setup(.{
        sample_rate = xx SAMPLE_RATE,
        num_channels = 2,
        stream_cb = saudio_stream_callback,
        saudio_allocator = .{
            alloc_fn = saudio_alloc,
            free_fn = saudio_free
        }
    });
    assert(saudio_isvalid(), "Backed initialization failed");
}

audio_update :: () {
    for sounds_that_are_playing {
        using it;
        
        if time_position >= data.time_length {
            // The sound thread will repeat this for us
            if flags & .SHOULD_REPEAT continue;
            
            stop(it);
            if ~flags & .DONT_DESTROY_AFTER_FINISH destroy(it);
        }
    }
}

#scope_file

sounds_that_are_playing: [..]*Sound;
main_mutex: Mutex;

#if OS == .WINDOWS {
	sokol_audio :: #library,no_dll "sokol";
	ole :: #system_library "ole32";
}

SAudio_Allocator :: struct {
    alloc_fn: (u64, *void) -> *void #c_call;
    free_fn: (*void, *void) #c_call;
    user_data: *void;
}

SAudio_Desc :: struct {
    sample_rate: s32;
    num_channels: s32;
    buffer_frames: s32;
    packet_frames: s32;
    num_packets: s32;
    stream_cb: (*float32, s32, s32) #c_call;
    stream_userdata_cb: (*float32, s32, s32, *void) #c_call;
    user_data: *void;
    saudio_allocator: SAudio_Allocator;
}

saudio_setup :: (desc: SAudio_Desc) -> void #foreign sokol_audio;
saudio_isvalid :: () -> bool #foreign sokol_audio;
saudio_sample_rate :: () -> s32 #foreign sokol_audio;

saudio_alloc :: (size: u64, user_data: *void) -> *void #c_call {
    new_context: Context;
    push_context new_context {
        return alloc(xx size);
    }
}

saudio_free :: (ptr: *void, user_data: *void) #c_call {
    new_context: Context;
    push_context new_context {
        free(ptr);
    }
}

saudio_stream_callback :: (buffer: *float32, frame_count: s32, channel_count: s32) #c_call {
    new_context: Context;
    push_context new_context {
        stream_callback(buffer, frame_count, channel_count);
    }
}

stream_callback :: (buffer: *float32, frame_count: s32, channel_count: s32) #expand {
    assert(channel_count == 2);
    
    lock(*main_mutex);
    defer unlock(*main_mutex);
    
    for i: 0..frame_count-1 {
        left: float;
        right: float;
        
        for sounds_that_are_playing {
            using it;
            
            if time_position >= data.time_length {
                if flags & .SHOULD_REPEAT {
                    time_position = fmod_cycling(time_position, data.time_length);
                } else continue;
            }
            
            sample_counter := time_position / data.samples_per_frame;
            
            if data.is_stereo {
                begin_index := cast(u32)(sample_counter / 2) * 2;
                
                left_sample := data.samples[begin_index];
                right_sample := data.samples[begin_index + 1];
                
                left += (cast(float)left_sample / S16_MAX) * volume;
                right += (cast(float)right_sample / S16_MAX) * volume;
                
                time_position += data.samples_per_frame * speed * 2;
            } else {
                sample := data.samples[cast(u32)sample_counter];
                value := (cast(float)sample / S16_MAX) * volume / 2;
                
                left += value;
                right += value;
                
                time_position += data.samples_per_frame * speed;
            }
        }
        
        buffer[i*2 + 0] = left;
        buffer[i*2 + 1] = right;
    }
}