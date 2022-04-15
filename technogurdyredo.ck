// TECHNO GURDY v2.0
// an emulation of a Hurdy Gurdy using the keyboard as the keychest and mouse as the pitch wheel
// also features tuneable drone strings that can be "plucked" with the keyboard
// [WIP] and drones that vibrate sympathetically with the chanters
// [WIP] and a buzzing bridge that responds to the wheel turn strength!
// inspired by Guilhem Desq's album "Visions"
// i literally dreamed this up. i had a dream that i did this, and upon waking up i realized that i definitely could do it
// info about the hurdy gurdy: https://en.wikipedia.org/wiki/Hurdy-gurdy https://www.altarwind.com/hgtuning.html
// i also used the S.M.E.L.T keyboard and trackpad programs as a reference
// first main section here: set up UGens and stuff of that sort
Bowed chanter[3] => LPF lowpass => LiSa looper => Gain loopGain => Gain master => PRCRev rev => dac; // instantiate 3 strings ("chanters") for the gurdy
lowpass => master; // looper passthrough
master => Echo gecko => Gain echogain => rev; // gorgeous verb-y echo
gecko => Gain echofeedback => gecko; // echo feedback, oh yes
SndBuf lidClick => Gain lidGain => looper;
lidGain => master;
me.dir() + "audio/ps2lid.wav" => lidClick.read;
lidClick.samples() => lidClick.pos;
0.05 => lidGain.gain;
SndBuf bodyHit => Gain bodyGain => looper;
bodyGain => master;
me.dir() + "audio/pvmhit2.wav" => bodyHit.read;
bodyHit.samples() => bodyHit.pos;
0.05 => bodyHit.gain;
0.5 => bodyHit.rate;
1 => looper.play;
1.0 => loopGain.gain;
Mandolin pluckDrone[2];
ADSR pdEnv[2];
pluckDrone[0] => pdEnv[0] => lowpass; // two mandolins for the pluckable drone strings
pluckDrone[1] => pdEnv[1] => lowpass;
0.25 => rev.mix;
0.7 => master.gain;
17000 => lowpass.freq;
0.5::second => gecko.delay; // gurdy echo > gecho > gecko
1.0 => gecko.mix; // i'm super creative and hilarious, right?
0.3 => echogain.gain;
0.2 => echofeedback.gain;
for (0 => int i; i < 3; i++) {
    //0.5 + ((i-1)/10.0) => chanter[i].bowPressure; // vary it up for best tone
    0.3 + ((i)/5.0)=> chanter[i].bowPosition; // vary it up for best tone
    0 => chanter[i].vibratoFreq;
    0 => chanter[i].vibratoGain;
    48 => Std.mtof => chanter[i].freq;
    //0.1 => chanter[i].rate; // chucK claims this does not exist?
}
[0.03, 0.04, 0.05] @=> float cVol[]; // base chanter volumes
[0.5, 0.3, 0.4] @=> float cPrs[]; // base chanter pressures
0.05 => pluckDrone[0].gain;
0.04 => pluckDrone[1].gain;
0.0 => pluckDrone[0].stringDetune => pluckDrone[1].stringDetune; // no string detune makes it sound like one string
38 => Std.mtof => pluckDrone[0].freq; // C
45 => Std.mtof => pluckDrone[1].freq; // G
0.7 => pluckDrone[0].stringDamping => pluckDrone[1].stringDamping;
0.6 => pluckDrone[0].pluckPos => pluckDrone[1].pluckPos;
pdEnv[0].set(35::ms, 10::ms, 0.8, 10::ms);
pdEnv[1].set(35::ms, 10::ms, 0.8, 10::ms);

0 => int kbNum; // set kb id
0 => int mseNum; // set mouse/trackpad id

// initiate the HID keyboard:
Hid kb; // create HID object for keyboard
HidMsg kbMsg; // create hID message for keyboard
if(!kb.openKeyboard(kbNum)) me.exit(); // if keyboard fails to open, exit
<<< "key chest '", kb.name(), "' ready" >>>; // if keyboard opens, print

// repeat the process for the mouse:
Hid mse;
HidMsg mseMsg;
if(!mse.openMouse(mseNum)) me.exit();
<<< "gurdy wheel '", mse.name(), "' ready" >>>;

// data returns: which key down, which key up, mouse speeds
256 => int downAscii; // most recent key down goes here. ascii table is 0-255, so 256 is not a relevant number.
256 => int upAscii; // most recent key up goes here
Event keyChange; // event that will broadcast when a key is pressed or released
fun void keyReader() { // a function to read keyboard inputs on a loop and spit them out into variables
    while(true) { // infinite loop
        kb => now; // wait for a keyboard event
        while(kb.recv(kbMsg)) { // "while i'm still receving a message...", i think, maybe it iterates multiple times if the message contains, say, a key up AND a key down?
            kb.recv(kbMsg); // recieve a message
            if (kbMsg.isButtonDown()) { // if the message is that a key is down
                kbMsg.ascii => downAscii; // put that key in the most recent down
                <<< "Key down:", downAscii >>>; // safety print
                256 => upAscii; // every time a key goes down, the previous up becomes irrelevant. this is not a two-way street.
            }
            else if (kbMsg.isButtonUp()) { // if the message is that a key is up
                kbMsg.ascii => upAscii; // put that key in most recent up
                <<< "Key up:", upAscii >>>; // safety print
            }
            keyChange.broadcast(); // let the WORLD KNOW that a key has changed!! :o
        }
        0.5::samp => now;
    }
}

0 => int dX; // mouse X-speed
0 => int dY; // mouse Y-speed
0 => float motionTime; // variable that contains the time at which dX and dY were last reported. IMPORTANT!
0 => float prevMotionTime;
Event muteRelease; // mute button release event
0 => int muteFlag;
fun void mouseReader() { // a function to read mouse inputs on a loop and spit them out into variables
    while(true) { // infinite loop
        mse => now; // wait on event
        while(mse.recv(mseMsg)) { // same stuff as in keyReader()
            mse.recv(mseMsg);
            if (mseMsg.isMouseMotion()) { // if message is mouse motion
                mseMsg.deltaX => dX; // plop it in these here variables
                mseMsg.deltaY => dY;
                motionTime => prevMotionTime; // previousReport gets the PREVIOUS lastMotionTime
                (now)/(1.0::samp) => motionTime; // dur/dur = float, puts NOW in samples in motionTime
                //<<< "speed", dX, ",", dY, "at time", motionTime >>>;
                //<<< "speed", (Math.sqrt(Math.pow(dX,2) + Math.pow(dY*2.0,2))), "at time", motionTime >>>;
                //<<< "last report was", (motionTime - prevMotionTime), "samples ago." >>>;
            }
            else {
                if (mseMsg.isButtonUp() && mseMsg.which == 2) { // if message is scroll wheel button up, trigger release event
                    muteRelease.signal();
                    0 => muteFlag;
                }
                else if (mseMsg.isButtonDown() && mseMsg.which == 2) { // if message is scroll wheel button down, set muteflag
                    1 => muteFlag;
                }
            }
        }
    }
}

0 => float speed; // wheel speed, calculated from dX and dY. Trigonometry!
0 => float spinStrength; // the "strength" of the spin, calculated based on the mouse speed
fun void chanterUpdate() { // function that calculates the mouse speed and updates the chanter values
    Math.sqrt(Math.pow(dX,2) + Math.pow(dY*2.0,2)) => speed; // calc sum speed
    // highest speed i'm able to get is like 380 or so, reasonable "fast" is like 150
    (-.12 * Math.pow(1.1, (22.25-(0.1*speed))) + 1.0) => spinStrength; // played with a graphing tool for 10 minutes to come up with this
    if (0 > spinStrength) 0 => spinStrength; // the scaling of HID mouse speed is garbage
    else if (1 < spinStrength) 1 => spinStrength; // safety checks
    for (0 => int i; i < 3; i++) { // spin strength increases bowing pressure
        cPrs[i] + spinStrength/2.0 => chanter[i].bowPressure; // 0.5 to work with here
    } // 0 < SPINSTRENGTH < 1
    for (0 => int i; i < 3; i++) { // spin strength increases volume
        cVol[i] + spinStrength/4.0 => chanter[i].volume; // 0.25 to work with here
    }
}

48 => int pitch; // gurdy pitch. defaults to root note.
256 => int lastDown; // key press memory
256 => int lastUp; // key release memory
fun void keyChest() { // a function that takes keyReader() data to simulate a gurdy key chest
    1::samp => now; // startup time
    while(true) { // infinite loop
        keyChange => now; // wait for a key status to change
        if (lastDown != downAscii) { // if the new key event was a downpress
            downAscii => lastDown; // update press memory
            if      (downAscii == 90) 48 => pitch; // z, C3
            else if (downAscii == 88) 50 => pitch; // x
            else if (downAscii == 67) 51 => pitch; // c
            else if (downAscii == 86) 53 => pitch; // v
            else if (downAscii == 66) 55 => pitch; // b
            else if (downAscii == 78) 56 => pitch; // n
            else if (downAscii == 77) 58 => pitch; // m
            else if (downAscii == 44) 60 => pitch; // ,
            // second row of keyboard (s-l): 4th octave
            else if (downAscii == 83) 60 => pitch; // s, C4
            else if (downAscii == 68) 62 => pitch; // d
            else if (downAscii == 70) 63 => pitch; // f
            else if (downAscii == 71) 65 => pitch; // g
            else if (downAscii == 72) 67 => pitch; // h
            else if (downAscii == 74) 68 => pitch; // j
            else if (downAscii == 75) 70 => pitch; // k
            else if (downAscii == 76) 72 => pitch; // l
            // third row of keyboard (w-o): 5th octave
            else if (downAscii == 87) 72 => pitch; // w, C5
            else if (downAscii == 69) 74 => pitch; // e
            else if (downAscii == 82) 75 => pitch; // r
            else if (downAscii == 84) 77 => pitch; // t
            else if (downAscii == 89) 79 => pitch; // y
            else if (downAscii == 85) 80 => pitch; // u
            else if (downAscii == 73) 82 => pitch; // i
            else if (downAscii == 79) 84 => pitch; // o
            // number row (3-9): 6th octave
            /*else if (downAscii == 51) 84 => pitch; // 3, C6
            else if (downAscii == 52) 86 => pitch; // 4
            else if (downAscii == 53) 87 => pitch; // 5
            else if (downAscii == 54) 89 => pitch; // 6
            else if (downAscii == 55) 91 => pitch; // 7
            else if (downAscii == 56) 92 => pitch; // 8
            else if (downAscii == 57) 94 => pitch; // 9
            else if (downAscii == 48) 96 => pitch; // 0*/
            // else break; // if it's not a relevant key, do nothing
            <<< "key", downAscii, "pressed. Pitch:", pitch >>>;
        }
        else { // if the update was a key release
            upAscii => lastUp;
            if (lastUp == lastDown) {
                48 => pitch;
                <<< "Key released, pitch reset." >>>;
                256 => upAscii => downAscii => lastUp => lastDown;
            }
            else { // an irrelevant key was released
                <<< "Irrelevant key released." >>>;
            }
        }
        for (0 => int i; i < 3; i++) { // pitch update loop
            pitch => Std.mtof => chanter[i].freq; // still laughing about how i forgot mtof in v1
        }
        2::samp => now; // chill out for a sec
    }
}
    
            

// NEW SPIN STARTS AFTER 8000 SAMPLES
0 => float lastReportTime; // stores the last motionTime report
0 => int isPlaying; // variable that tracks whether or not the gurdy is playing
fun void gurdyWheel() { // a function that takes mouseReader() input to imitate a hurdy gurdy's bow wheel
    1::samp => now; // startup time
    while(true) { // infinite loop
        if(motionTime != lastReportTime) { // there has been a new mouse report!!!!!
            motionTime => lastReportTime; // remember when the last report was read
            if ((prevMotionTime + 8000) < motionTime) { // previous motion time is far enough from now that a new spin has been started
                chanterUpdate(); // see function above. calculates speed, sets chanter volumes and pressures accordingly
                for(0 => int i; i < 3; i++) { // start bowing chanters
                    1 => chanter[i].startBowing;
                }
                1 => isPlaying; // set "is playing" flag
                //<<< "NEW SPIN!" >>>;
            }
            else { // a continued spin
                chanterUpdate(); // update vols and pressure during a continued spin for E X P R E S S I V E N E S S
                //<<< "The spin continues..." >>>;
            }
        }
        else { // there has not been a new report - mouse is still
            if (isPlaying) { // if the gurdy is still playing, stop that nonsense
                for(0 => int i; i < 3; i++) { // stop bowing chanters
                    1 => chanter[i].stopBowing;
                }
                0 => isPlaying;
                //<<< "STOP THAT!!" >>>;
            }
            else {
                for(0 => int i; i < 3; i++) { // stop bowing chanters
                    1 => chanter[i].stopBowing;
                }
                0 => isPlaying;
                // <<< "Spin me, senpai uwu" >>>;
            } 
        }
        // 10::samp => now; // new mouse reports typically come in on 512 sample intervals. This function doesn't need to run often (it can probably go faster than this when i get it working)
        for (0 => int i; i < 250; i++) { // the function will wait 100 samples before repeating UNLESS there's been a mouse update
            1::samp => now;
            if (motionTime != lastReportTime) break;
        }
        if (muteFlag) muteRelease => now; // if muteFlag is triggered, wait for it to stop
    }
}

// the "buzzing bridge" turns on when the gurdy is being played hard enough
fun void buzzer(int rootNote, Impulse imp) { // single buzzer function
    rootNote => Std.mtof => float frequency;
    while(true) {
        1 => imp.next;
        (1/frequency)::second => now;
    }
}
// set ALL THE STUFF
60 => int root;
Gain buzzerGain => ADSR buzzerEnv => lowpass;
Impulse buzzImp[3];
Gain buzzHarmonicGain[3];
buzzerEnv.set(10::ms, 0::ms, 1.0, 100::ms);
0.3 => buzzerGain.gain;
for (0 => int i; i < 3; i++) {
    buzzImp[i] => buzzHarmonicGain[i] => buzzerGain;
    (0.3/Math.pow((i + 1), 2)) => buzzHarmonicGain[i].gain;
}

fun void buzzingBridge() { // function that triggers and updates the buzzer values
    float buzzingBridgeGain;
    1 => buzzerEnv.keyOn;
    while(true) { // infinite loop
        (spinStrength / 2.0) - 0.30 => buzzingBridgeGain; // -0.30 < bBG < 0.20
        if (buzzingBridgeGain < 0) 0 => buzzingBridgeGain; // if it's less than zero it's zero
        else buzzingBridgeGain + 0.05 => buzzingBridgeGain;
            buzzingBridgeGain => buzzerGain.gain;
        100::samp => now; // will update every 100 samples
    }
}

fun void dronePluck(int id, int keyAscii) { // a function to trigger one of the pluckable drone strings with a specific key
    256 => int lastPluckDown;
    256 => int lastPluckUp;
    while(true) {
        keyChange => now;
        if (lastPluckDown != downAscii && downAscii == keyAscii) { // down keypress
            downAscii => lastPluckDown;
            1 => pluckDrone[id].noteOn;
            1 => pdEnv[id].keyOn;
            256 => lastPluckUp;
        }
        else if (lastPluckUp != upAscii && upAscii == keyAscii) { // key released
            1 => pluckDrone[id].noteOff;
            1 => pdEnv[id].keyOff;
            256 => lastPluckDown;
        }
        1::samp => now;
    }
}

fun string intToVoice(int number) { // converts an int to a "voice" number for LiSa, returns voice number string
    "voice" + number => string voiceNum;
    return voiceNum;
}

fun void loopPedal() { // using LiSa to emulate a basic guitar loop pedal - press a button to record and stop, undo last record, stop playing entirely
    256 => int lastLoopDown;
    0 => int currentVoice;
    0 => int lengthSet;
    60::second => looper.duration;
    1 => looper.feedback;
    while(true) { // infinite loop
        keyChange => now; // wait for a keyPress 9 = 57, 0 = 48, backspace = 8
        if (lastLoopDown != downAscii && (downAscii == 57 || downAscii == 48 || downAscii == 8)) { // if a relevant key has been pressed
            downAscii => lastLoopDown; // memory so key releases don't trigger phantom presses
            if (lastLoopDown == 48) { // start a new recording
                1 => looper.record; // start recording into the next open voice
                looper.playPos() => looper.loopStart;
                looper.playPos() => looper.recPos;
                <<< "recording..." >>>;
            }
            else if (lastLoopDown == 57) { // end recording, start looping
                looper.recPos() => looper.loopEnd;
                looper.recPos() => looper.playPos;
                0 => looper.record;
                1 => looper.play;
                <<< "recorded! Playing back!" >>>;
            }
            else if (lastLoopDown == 8) { // pause playback
                0 => looper.record;
                0 => looper.play;
                <<< "Take a break..." >>>;
            }
        }
    }
}

fun void percussion() { // play percussive samples on trigger
    256 => int lastPercDown;
    while(true) {
        keyChange => now;
        if (lastPercDown != downAscii) {
             downAscii => lastPercDown;
            if (downAscii == 52) { // lid click key
                0 => bodyHit.pos;
                <<< "body stricken!" >>>;
            }
            else if (downAscii == 56) { // body hit key
                0 => lidClick.pos;
                <<< "lid clacked!" >>>;
            }
        }
        else 256 => lastPercDown; // a key was released, not pressed
            
        1::samp => now;
    }
}

spork ~ buzzingBridge();
spork ~ buzzer((root * 1), buzzImp[0]);
spork ~ buzzer((root * 2), buzzImp[1]);
spork ~ buzzer((root * 3), buzzImp[2]);
spork ~ keyReader();
spork ~ mouseReader();
spork ~ keyChest();
spork ~ gurdyWheel();
spork ~ dronePluck(0, 91);
spork ~ dronePluck(1, 93);
spork ~ percussion();
spork ~ loopPedal();

while(true) {
    1::second => now;
}
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    