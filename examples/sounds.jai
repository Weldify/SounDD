#import,file "../module.jai";

#import "Basic";
#import "File";

main :: () {
    audio_init();
    
    // You can load stereo and mono files
    data_1 := sound_data_load_from_file("examples/footstep_1.wav");
    data_2 := sound_data_load_from_file("examples/rune_collect.flac");
    
    data_3 := sound_data_load_from_file("examples/rune_collect.flac");
    defer sound_data_free(data_3);
    
    footstep := create(data_1);
    footstep.volume = 0.5;
    footstep.flags |= .SHOULD_REPEAT;
    play(footstep);
    
    // Multiple sounds can use the same sound data, obviously
    long_footstep := create(data_1);
    long_footstep.volume = 1;
    long_footstep.speed = 0.1;
    play(long_footstep);
    
    rune_collect := create(data_2);
    rune_collect.volume = 0.4;
    
    // By default, sounds will get freed once they finish playing
    rune_collect.flags |= .DONT_DESTROY_AFTER_FINISH;
    defer destroy(rune_collect);
    
    play(rune_collect);

    while true {
        audio_update();
        sleep_milliseconds(10);
    }
}

#run {
    WR :: #import "Windows_Resources";
    
    WR.disable_runtime_console();
}