#import "Basic";
#import "Bit_Operations";

#scope_module

// @Note: This decoder assumes we are little endian. The format is big endian.

qoa_parse_data :: (str: string) -> Sound_Data {
    samples_per_channel, channel_count, sample_rate := decode_header(str.data);
    print("Samples per channel: %, channel count: %, sample_rate: %\n", samples_per_channel, channel_count, sample_rate);
    
    total_samples := samples_per_channel * channel_count;
    samples: *s16 = alloc(total_samples * size_of(u16));
    
    sample_index := 0;
    frame_length: u32;
    frame_size: u32;
    
    // while true {
    //     sample_ptr: *s16 = samples + sample_index * channel_count;
    //     frame_size = decode_frame();
    // }
}

qoa_free_data :: (data: Sound_Data) {
    
}

#scope_file

QOA_MAGIC :: 0x716f6166;
MAX_CHANNELS :: 8;

Frame_Header :: struct {
    channel_count: u8;
    sample_rate: u32;
    samples_per_channel: u16;
    size: u16;
}

LMS_State :: struct {
    history: [4]s16;
    weights: [4]s16;
}

QOA_Description :: struct {
    channel_count: u8;
    sample_rate: u32;
    samples_per_channel: u16;
    lms_buffer: []LMS_State;
}

decode_header :: (data: *u8) -> samples_per_channel: u32, channel_count: u8, sample_rate: u32 {
    cursor := 0;
    assert(data[0] == #char "q" && data[1] == #char "o" && data[2] == #char "a" && data[3] == #char "f");
    cursor += 4;
    
    samples_per_channel := byte_swap((cast(*u32)(data + cursor)).*);
    cursor += 4;
    
    channel_count := data[cursor];
    cursor += 1;
    
    // 24 bit value
    sample_rate := byte_swap((cast(*u32)(data + cursor)).*) >> 8;
    cursor += 3;
    
    return samples_per_channel, channel_count, sample_rate;
}