#import,file "../module.jai";

#import "Basic";
#import "File";

main :: () {
    audio_init();
    
    // You can load stereo and mono files
    noise_data := sound_data_load_from_file("examples/noise.wav");
    sound_data := sound_data_load_from_file("examples/rune_collect.wav");
    sound_mono_data := sound_data_load_from_file("examples/rune_collect_mono.wav");
    
    noise := create(noise_data);
    noise.volume = 0.2;
    noise.flags |= .SHOULD_REPEAT;
    play(noise);
    
    // Multiple sounds can use the same sound data, obviously
    loud_noise := create(noise_data);
    loud_noise.volume = 1;
    loud_noise.speed = 10;
    play(loud_noise);
    
    sound := create(sound_data);
    sound.volume = 2;
    play(sound);
    
    sound_mono := create(sound_mono_data);;
    sound.volume = 2;
    sound.speed = 0.5;
    // By default, sounds will get freed once they finish playing
    noise.flags |= .DONT_DESTROY_AFTER_FINISH;
    play(sound_mono);
    
    while true {
        audio_update();
        sleep_milliseconds(10);
    }
    
    destroy(sound_mono);
}

#run {
    WR :: #import "Windows_Resources";
    
    WR.disable_runtime_console();
}