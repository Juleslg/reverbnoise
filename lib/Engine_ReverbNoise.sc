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
                var inputAmp = Amplitude.kr(Mix(input), 0.05, 0.3);
                
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

                // Extended reverb processing for >100% and >200%
                var extended_size = Select.kr(verb_mix > 2, [
                    Select.kr(verb_mix > 1, [
                        verb_size,
                        verb_size * (1 + ((verb_mix - 1) * 2))
                    ]),
                    verb_size * (3 + ((verb_mix - 2) * 4)) // Triple size and continue growing
                ]);

                var extended_time = Select.kr(verb_mix > 2, [
                    Select.kr(verb_mix > 1, [
                        verb_time,
                        verb_time * (1 + ((verb_mix - 1) * 3))
                    ]),
                    verb_time * (4 + ((verb_mix - 2) * 5)) // Quadruple time and continue growing
                ]);

                // Crystalline effect with increased intensity above 200%
                var shimmer_amount = Select.kr(verb_mix > 2, [
                    verb_mix > 1 * (verb_mix - 1) * 0.5,
                    (verb_mix - 1) * 1.5  // More intense shimmer
                ]);
                
                var shimmer = PitchShift.ar(mixed, 0.2, 
                    1 + shimmer_amount,
                    0.01, 0.1
                );
                
                var bright_filter = BHiShelf.ar(mixed, 2000, 1, 
                    Select.kr(verb_mix > 2, [
                        Select.kr(verb_mix > 1, [0, (verb_mix - 1) * 12]),
                        (verb_mix - 1) * 24  // Double brightness boost
                    ])
                );

                var reverb_input = Select.ar(verb_mix > 1, [
                    mixed,
                    (mixed * 0.7) + (shimmer * 0.2) + (bright_filter * 0.1)
                ]);
                
                var reverb = FreeVerb.ar(
                    reverb_input,
                    mix: 1.0,
                    room: extended_size,
                    damp: Select.kr(verb_mix > 2, [
                        Select.kr(verb_mix > 1, [verb_damp, verb_damp * 0.5]),
                        verb_damp * 0.25  // Even less damping for extreme reverb
                    ])
                );

                var sig = XFade2.ar(mixed, reverb, verb_mix * 2 - 1);
                
                // Add more intense pitch shifting for extreme reverb
                sig = Select.ar(verb_mix > 2, [
                    Select.ar(verb_mix > 1, [
                        sig,
                        sig + (PitchShift.ar(sig, 0.2, 1.5, 0.01, 0.1) * (verb_mix - 1))
                    ]),
                    sig + (PitchShift.ar(sig, 0.2, 2.0, 0.01, 0.1) * (verb_mix - 1)) +
                    (PitchShift.ar(sig, 0.2, 3.0, 0.01, 0.1) * (verb_mix - 2))
                ]);

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