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
                var inputAmp = Amplitude.kr(Mix(input), 0.05, 0.3); // Slower tracking for smoother response
                
                // Create multiple layers of filtered noise
                var noise1 = LPF.ar(WhiteNoise.ar(), 2000 + (inputAmp * 2000));
                var noise2 = BPF.ar(PinkNoise.ar(), 800 + (inputAmp * 1200), 1.5);
                var noise3 = HPF.ar(BrownNoise.ar(), 200 + (inputAmp * 400));
                
                // Gentle modulation sources
                var lfo1 = SinOsc.kr(0.1 + (inputAmp * 0.3));
                var lfo2 = LFTri.kr(0.05 + (inputAmp * 0.2));
                
                // Combine noise layers with modulation
                var noiseSum = (
                    (noise1 * 0.4 * (1 + (lfo1 * 0.2))) + 
                    (noise2 * 0.35 * (1 + (lfo2 * 0.15))) + 
                    (noise3 * 0.25)
                ) * noise_level * inputAmp;
                
                // Soft saturation for warmth
                var saturated = (input * (1.0 + (noise_level * 0.3))).tanh;
                
                // Blur the input with comb filtering
                var comb1 = CombL.ar(input, 0.1, 0.06 + (lfo1 * 0.01), 0.2);
                var comb2 = CombL.ar(input, 0.1, 0.08 + (lfo2 * 0.01), 0.3);
                
                var mixed = (
                    (input * 0.7) + 
                    (comb1 * 0.15) + 
                    (comb2 * 0.15) + 
                    noiseSum + 
                    (saturated * 0.3)
                );
                
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
                var inputAmp = Amplitude.kr(Mix(input), 0.05, 0.3); // Slower tracking for smoother response
                
                // Create multiple layers of filtered noise
                var noise1 = LPF.ar(WhiteNoise.ar(), 2000 + (inputAmp * 2000));
                var noise2 = BPF.ar(PinkNoise.ar(), 800 + (inputAmp * 1200), 1.5);
                var noise3 = HPF.ar(BrownNoise.ar(), 200 + (inputAmp * 400));
                
                // Gentle modulation sources
                var lfo1 = SinOsc.kr(0.1 + (inputAmp * 0.3));
                var lfo2 = LFTri.kr(0.05 + (inputAmp * 0.2));
                
                // Combine noise layers with modulation
                var noiseSum = (
                    (noise1 * 0.4 * (1 + (lfo1 * 0.2))) + 
                    (noise2 * 0.35 * (1 + (lfo2 * 0.15))) + 
                    (noise3 * 0.25)
                ) * noise_level * inputAmp;
                
                // Soft saturation for warmth
                var saturated = (input * (1.0 + (noise_level * 0.3))).tanh;
                
                // Blur the input with comb filtering
                var comb1 = CombL.ar(input, 0.1, 0.06 + (lfo1 * 0.01), 0.2);
                var comb2 = CombL.ar(input, 0.1, 0.08 + (lfo2 * 0.01), 0.3);
                
                var mixed = (
                    (input * 0.7) + 
                    (comb1 * 0.15) + 
                    (comb2 * 0.15) + 
                    noiseSum + 
                    (saturated * 0.3)
                );
                
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