#import "Basic";
#import "Bit_Operations";

#scope_module

// @Note: This decoder assumes we are little endian. The format is big endian.

// @Todo: Rename all format parse_data procedures to decode_data
qoa_parse_data :: (str: string) -> Sound_Data {
    samples_per_channel, channel_count, sample_rate, cursor := decode_header(str.data);

    total_samples := samples_per_channel * channel_count;
    samples: *s16 = alloc(total_samples * size_of(s16));
    
    data: Sound_Data;
    data.sample_count = total_samples;
    data.samples = samples;
    data.sample_rate = sample_rate;
    data.channel_count = channel_count;
    
    sample_index: u32 = 0;
    frame_length: u32;
    frame_size: u32;
    
    lms: LMS_Array;
    
    while true {
        sample: *s16 = samples + sample_index * channel_count;
        frame_size, frame_length = decode_frame(str.data + cursor, sample, *lms);
        
        cursor += frame_size;
        sample_index += frame_length;
        
        if (sample_index >= samples_per_channel) break;
    }
    
    return data;
}

qoa_free_data :: (data: Sound_Data) {
    free(data.samples);
}

#scope_file

QOAF :: 0x716f6166;
LMS_LENGTH :: 4;
SLICE_LENGTH :: 20;
MAX_CHANNELS :: 8;

DEQUANT_TAB :: ([8]s32).[
	s32.[   1,    -1,    3,    -3,    5,    -5,     7,     -7],
	s32.[   5,    -5,   18,   -18,   32,   -32,    49,    -49],
	s32.[  16,   -16,   53,   -53,   95,   -95,   147,   -147],
	s32.[  34,   -34,  113,  -113,  203,  -203,   315,   -315],
	s32.[  63,   -63,  210,  -210,  378,  -378,   588,   -588],
	s32.[ 104,  -104,  345,  -345,  621,  -621,   966,   -966],
	s32.[ 158,  -158,  528,  -528,  950,  -950,  1477,  -1477],
	s32.[ 228,  -228,  760,  -760, 1368, -1368,  2128,  -2128],
	s32.[ 316,  -316, 1053, -1053, 1895, -1895,  2947,  -2947],
	s32.[ 422,  -422, 1405, -1405, 2529, -2529,  3934,  -3934],
	s32.[ 548,  -548, 1828, -1828, 3290, -3290,  5117,  -5117],
	s32.[ 696,  -696, 2320, -2320, 4176, -4176,  6496,  -6496],
	s32.[ 868,  -868, 2893, -2893, 5207, -5207,  8099,  -8099],
	s32.[1064, -1064, 3548, -3548, 6386, -6386,  9933,  -9933],
	s32.[1286, -1286, 4288, -4288, 7718, -7718, 12005, -12005],
	s32.[1536, -1536, 5120, -5120, 9216, -9216, 14336, -14336],
];

LMS :: struct {
    history: [LMS_LENGTH]s32;
    weights: [LMS_LENGTH]s32;
}

LMS_Array :: #type [MAX_CHANNELS]LMS;

decode_header :: (bytes: *u8) -> samples_per_channel: u32, channel_count: u8, sample_rate: u32, cursor: u32 {
    file_header := byte_swap((cast(*u64)(bytes)).*);
    assert(file_header >> 32 == QOAF);
    
    samples_per_channel := file_header & 0xffffffff;
    
    frame_header := byte_swap((cast(*u64)(bytes + 8)).*);
    channel_count := (frame_header >> 56) & 0x0000ff;
    sample_rate := (frame_header >> 32) & 0xffffff;
    
    return xx samples_per_channel, xx channel_count, xx sample_rate, 8;
}

decode_frame :: (bytes: *u8, sample: *s16, lms: *LMS_Array) -> frame_size: u32, frame_length: u32 {
    frame_header := byte_swap((cast(*u64)(bytes)).*);
    cursor: u32 = 8;
    
    channel_count: s32 = xx (frame_header >> 56) & 0x0000ff;
    sample_rate: s32 = xx (frame_header >> 32) & 0xffffff;
    samples_per_frame: s32 = xx (frame_header >> 16) & 0x00ffff;
    frame_size: s32 = xx frame_header & 0x00ffff;
    
    for c: 0..channel_count-1 {
        history := byte_swap((cast(*u64)(bytes + cursor)).*);
        weights := byte_swap((cast(*u64)(bytes + cursor + 8)).*);
        cursor += 16;
        
        for i: 0..LMS_LENGTH-1 {
            lms.*[c].history[i] = cast,no_check(s16)(history >> 48);
            lms.*[c].weights[i] = cast,no_check(s16)(weights >> 48);
            
            history <<= 16;
            weights <<= 16;
        }
    }
    
    sample_index: s32 = 0;
    while (sample_index < samples_per_frame) {
        sample_index += SLICE_LENGTH;
        
        for c: 0..channel_count-1 {
            slice := byte_swap((cast(*u64)(bytes + cursor)).*);
            cursor += 8;
        
            scale_factor := (slice >> 60) & 0xf;
            slice_start := sample_index * channel_count + c;
            slice_end := clamp(sample_index + SLICE_LENGTH, 0, samples_per_frame) * channel_count + c;
            
            si: s32 = slice_start;
            while (si < slice_end) {
                si += channel_count;
                
                predicted := lms_predict(*(lms.*[c]));
                quantized := (slice >> 57) & 0x7;
                dequantized := DEQUANT_TAB[scale_factor][quantized];
                reconstructed := clamp_s16(predicted + dequantized);
                
                sample[si] = reconstructed;
                slice <<= 3;
                
                lms_update(*(lms.*[c]), reconstructed, dequantized);
            }
        }
    }
    
    return cursor, xx samples_per_frame;
}

lms_predict :: (lms: *LMS) -> s32 {
    prediction: s32 = 0;
    for i: 0..LMS_LENGTH-1 {
        prediction += lms.weights[i] * lms.history[i];
    }
    
    return prediction >> 13;
}

lms_update :: (lms: *LMS, sample: s32, residual: s32) {
    delta := residual >> 4;
    for i: 0..LMS_LENGTH-1 {
        lms.weights[i] += ifx lms.history[i] < 0 then -delta else delta;
    }
    
    for i: 0..LMS_LENGTH-2 {
        lms.history[i] = lms.history[i+1];
    }
    lms.history[LMS_LENGTH-1] = sample;
}

clamp_s16 :: (v: s32) -> s16 {
	if (cast(u32)(v + 32768) > 65535) {
		if (v < -32768) { return -32768; }
		if (v >  32767) { return  32767; }
	}
	return xx v;
}