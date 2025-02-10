Engine_ReverbNoise : CroneEngine {
    var <synth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Check if JPverb is available
        if(not('JPverb'.asClass.notNil), {
            "WARNING: JPverb not found, using FreeVerb instead".postln;
            SynthDef(\reverbNoise, {
                arg in, out, amp=1.0, noise_level=0.0,
                verb_mix=0.0, verb_time=2.0,
                verb_damp=0.0, verb_size=1.0,
                verb_diff=0.707, verb_mod_depth=0.1,
                verb_mod_freq=2.0;

                var input = SoundIn.ar([0, 1]);
                var inputAmp = Amplitude.kr(Mix(input), 0.01, 0.1); // Track input amplitude
                var noise = WhiteNoise.ar(noise_level * inputAmp); // Modulate noise by input amplitude
                var mixed = input + noise;
                
                var reverb = FreeVerb.ar(
                    mixed,
                    mix: 1.0,
                    room: verb_size,
                    damp: verb_damp
                );

                var sig = XFade2.ar(mixed, reverb, verb_mix * 2 - 1);
                Out.ar(out, sig * amp);
            }).add;
        }, {
            SynthDef(\reverbNoise, {
                arg in, out, amp=1.0, noise_level=0.0,
                verb_mix=0.0, verb_time=2.0,
                verb_damp=0.0, verb_size=1.0,
                verb_diff=0.707, verb_mod_depth=0.1,
                verb_mod_freq=2.0;

                var input = SoundIn.ar([0, 1]);
                var inputAmp = Amplitude.kr(Mix(input), 0.01, 0.1); // Track input amplitude
                var noise = WhiteNoise.ar(noise_level * inputAmp); // Modulate noise by input amplitude
                var mixed = input + noise;
                
                var reverb = JPverb.ar(
                    mixed,
                    t60: verb_time,
                    damp: verb_damp,
                    size: verb_size,
                    earlyDiff: verb_diff,
                    modDepth: verb_mod_depth,
                    modFreq: verb_mod_freq
                );

                var sig = XFade2.ar(mixed, reverb, verb_mix * 2 - 1);
                Out.ar(out, sig * amp);
            }).add;
        });

        context.server.sync;

        synth = Synth.new(\reverbNoise, [
            \out, context.out_b.index,
            \amp, 1.0
        ], context.xg);

        this.addCommand("amp", "f", { arg msg;
            synth.set(\amp, msg[1]);
        });

        this.addCommand("noise", "f", { arg msg;
            synth.set(\noise_level, msg[1]);
        });

        this.addCommand("verb_mix", "f", { arg msg;
            synth.set(\verb_mix, msg[1]);
        });

        this.addCommand("verb_time", "f", { arg msg;
            synth.set(\verb_time, msg[1]);
        });

        this.addCommand("verb_damp", "f", { arg msg;
            synth.set(\verb_damp, msg[1]);
        });

        this.addCommand("verb_size", "f", { arg msg;
            synth.set(\verb_size, msg[1]);
        });

        this.addCommand("verb_mod_depth", "f", { arg msg;
            synth.set(\verb_mod_depth, msg[1]);
        });

        this.addCommand("verb_mod_freq", "f", { arg msg;
            synth.set(\verb_mod_freq, msg[1]);
        });
    }

    free {
        if(synth.notNil, {
            synth.free;
        });
    }
} 