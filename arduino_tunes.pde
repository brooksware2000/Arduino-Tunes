/* 

Christmas tunes player (will play other tunes too!)

by Tom de Simone 
8th Dec 2009
See it in action at http://meatfinish.co.uk/arduino/xmas_tunes/
Inspired by the piezo circuit in the awesome oomlout beginner's guide for their Arduino Experimentation Kit (oomlout.com)
This code is licensed as Creative Commons share-alike (http://creativecommons.org/licenses/by-nc-sa/3.0/)

******** TODO: ********
 - Make toggle button work better
 - Redo note frequencies


Instructions
============
User selects 1 of 4 tunes to play by twisting a potentiometer and seeing a corresponding LED light up.
They then press the microswitch to play the selected tune.

If you just want to edit the melodies that are played, the only changes you need to make are in playTune(). This function works by calling parseTune()
with the following parameters:

char notes[]: a string that represents the notes of the song
int beatLength: how long a beat should be, which has a direct effect on tempo. Smaller value -> quicker; bigger -> slower
boolean loopSong: if true, the song will loop indefinitely (until you press the microswitch)

So in order to modify an existing tune, you basically have to modify the above 3 parameters in the call to parseTune();

Each tune is stored as a string of note names and their corresponding durations. Each token in the string can be represented
by the following regex:
 
  ([cdefgabCDEFGAB]#{0,1}[0-9]{1,2})|(,[0-9]{1,2})|\.
  
In other words, you can have a letter which represents the pitch (2 octaves possible: 'c' up to 'b', then 'C' up to 'B'),
followed by a '#' if it is a sharp (there are no flats in this grammar), and then a number representing its duration,
where 4 is a single beat (crotchet or 1/4 note), 2 is half a beat (quaver or 1/8 note), 8 is two beats (minim or 1/2 note) etc.
The duration can be any number from 1-99, but you'll rarely need longer than 16. If 1 (semiquaver or 1/16 note) really isn't
short enough for you, you could always increase the tempo ;)

To add a rest, use a comma (',') and then a number for the rest duration as above.

Finally, VERY IMPORTANT: EVERY tune you write should have a full stop/period ('.') as the last character in the string.
This tells the Arduino that the tune has finished.
  
For example, the following are all valid tokens:

  c2 // play a 'C' note for a duration of 2 (equivalent to a quaver or 1/8 note)
  a#4 // play an 'A#' note for a duration of 4 (equivalent to a crotchet or 1/4 note)
  A#4 // play an 'A#' note an octave higher for a duration of 4 (equivalent to a crotchet or 1/4 note)
  ,8 // a minim (or 1/2 note) rest
  
The following are NOT valid tokens:

  cBd // each of the 3 notes must be followed by a number representing its duration
  ,#6 // a rest cannot be "sharpened"
  
The following is a valid string representing a melody:

  "e4d4c4d4e4e4e4,4d4d4d4,4e4g4g4,4."
  
The following is NOT a valid string representing a melody:
  
  "e4d4c4d4e4e4e4,d4d4d4,4e4g4g4,4"
                 ^                ^

  because one of the rests is missing a duration value, and there is no full stop/period ('.') at the end of the string.
  
For more examples, look at the 4 melodies that are already written inside playTune() !

*/

int speakerPin = 9;
int potPin = 2;
int buttonPin = 2;
int led1 = 3;
int led2 = 4;
int led3 = 5;
int led4 = 6;

int switchState = LOW;
boolean buttonClear = true;
int songChoice;
int ledPattern = true;

/* Smaller value -> all tunes play faster; bigger -> slower. Recommend you don't change this, but
instead use playTune() to pass different beatLength values to parseTune() for different songs */
const int beatLength = 50; 

// Generate a tone by passing a square wave of a certain period to the piezo
void playTone(int tone, int duration) {
  for (long i = 0; i < duration * 1000L; i += tone * 2) {
    digitalWrite(speakerPin, HIGH);
    delayMicroseconds(tone);
    digitalWrite(speakerPin, LOW);
    delayMicroseconds(tone);
  }
}

/* This works out what period, in microseconds, to use for the square wave for a given note. To calculate these,
p = ((1 / freq) * 1,000,000) / 2. We divide by 2 because the signal will be HIGH for p microseconds and then LOW
for p microseconds. Frequencies for the notes obtained from http://www.phy.mtu.edu/~suits/notefreqs.html
The range defined below covers 2 octaves from C4 (middle C, or 261.63Hz) to B5 (987.77Hz). Feel free to modify. */
void playNote(char note, int duration, boolean sharp) {
  char names[] = { 'c', 'd', 'e', 'f', 'g', 'a', 'b', 'C', 'D', 'E', 'F', 'G', 'A', 'B' };
  int tones[] = { 1915, 1700, 1519, 1432, 1275, 1136, 1014, 956, 851, 758, 716, 636, 568, 506 };
  
  // these are the "sharp" versions of each note e.g. the first value is for "c#"
  char names_sharp[] = { 'c', 'd', 'f', 'g', 'a', 'C', 'D', 'F', 'G', 'A' };
  int tones_sharp[] = { 1804, 1607, 1351, 1204, 1073, 902, 804, 676, 602, 536 };
  
  // play the tone corresponding to the note name
  if (sharp == false) {
    for (int i = 0; i < 14; i++) {
      if (names[i] == note) {
        playTone(tones[i], duration);
      }
    }
  } else {
    for (int i = 0; i < 10; i++) {
      if (names_sharp[i] == note) {
        playTone(tones_sharp[i], duration);
      }
    }
  }
}

/* Code for using a microswitch as a start/stop toggle
Note: to stop a song half way through, you may have to hold the button down for a moment */
void updateSwitchState() {
  int val = digitalRead(buttonPin);
  if (val == HIGH) {
    buttonClear = true;
  } else {
    if (buttonClear == true) {
      if (switchState == LOW) {
        switchState = HIGH;
      } else {
        switchState = LOW;
      }
      buttonClear = false;
    }
  }
}

// Make the LEDs dance while playing the tune
void alternateLeds() {
  if (ledPattern == true) {
    digitalWrite(led1, LOW);
    digitalWrite(led2, HIGH);
    digitalWrite(led3, LOW);
    digitalWrite(led4, HIGH);
    ledPattern = false;
  } else {
    digitalWrite(led1, HIGH);
    digitalWrite(led2, LOW);
    digitalWrite(led3, HIGH);
    digitalWrite(led4, LOW);
    ledPattern = true;
  }
}

/* Take a string representing a tune and parse it to play the notes through the piezo.

Parameters:
  char notes[]: a string that represents the notes of the song. The grammar for parsing the string is described at the top of this file.
  int beatLength: changes the tempo. Smaller value -> quicker; bigger -> slower
  boolean loopSong: if true, the song will loop indefinitely (until you press the microswitch)
*/
void parseTune(char notes[], int beatLength, boolean loopSong) {
  boolean play = true;
  
  // 1 iteration of this loop == 1 note played
  for (int i = 0; notes[i] != '.' && play == true; i++) { // stop iteration if '.' is the next char
    updateSwitchState();
    if (switchState == LOW) { // For every note, check to see if the button has been pressed to stop the tune
      play = false;
    } else {
      if (notes[i] == ',') { // ',' signifies a rest
      
        // Look at the number (max. 2 digits) following from the ',' to work out the duration of the rest
        char len[3];
        int count = 0;
        while (notes[i+1] >= '0' && notes[i+1] <= '9' && count < 2) {
          len[count] = notes[i+1];
          count++;
          i++;
        }
        len[count] = '\0';
        int duration = atoi(len);
        
        delay(duration * beatLength); // rest duration
      } else { // play the next note, represented by a series of characters e.g. 'c4', 'a#12'
        alternateLeds(); // alternate the red and green LEDs every note to make them "dance"
        char note = notes[i];
        boolean sharp;
        
        // if the next character is a '#' then we must make the note a sharp
        if (notes[i+1] == '#') {
          i++;
          sharp = true;
        } else {
          sharp = false;
        }
        
        // Look at the number (max. 2 digits) following from the note name to work out the note duration
        char len[3];
        int count = 0;
        while (notes[i+1] >= '0' && notes[i+1] <= '9' && count < 2) {
          len[count] = notes[i+1];
          count++;
          i++;
        }
        len[count] = '\0';
        int duration = atoi(len);
        
        playNote(note, duration * beatLength, sharp);
      }
      
      delay(beatLength / 2); // pause between notes
    }
  }
  
  if (loopSong == false) {
    switchState = LOW;
  }
}

// Write your tunes in here using the grammar described at the top of this file. Can have up to 4 tunes.
void playTune (int tune) {
  if (tune == 1) { // Jingle Bells
    char notes[] = "b4b4b8b4b4b8b4D4g6a2b12,4C4C4C6C2C4b4b4b2b2b4a4a4b4a8D8b4b4b8b4b4b8b4D4g6a2b12,4,C4C4C6C2C4b4b4b2b2D4D4C4a4g12,8.";
    parseTune(notes, beatLength, false);
  } else if (tune == 2) { // The Holly and the Ivy
    char notes[] = "g4g2g2g4E4D4b6g2g2g2g4E4D8D2C2b2a2g4b2b2e2e2d4g2a2b2C2b4a4g8,8.";
    parseTune(notes, beatLength * 1.50, false);
  } else if (tune == 3) { // We Wish You a Merry Christmas
    char notes[] = "d4g4g2a2g2f#2e4c4e4a4a2b2a2g2f#4d4f#4b4b2C2b2a2g4e4d2d2e4a4f#4g8,8.";
    parseTune(notes, beatLength * 1.25, false);
  } else if (tune == 4) { // Deck the Halls
    char notes[] = "D6C2b4a4g4a4b4g4a2b2C2a2b6a2g4f#4g6,2D6C2b4a4g4a4b4g4a2b2C2a2b6a2g4f#4g6,2a6b2C4a4b6C2D4a4b2C#2D4E2F#2G4F#4E4D6,2D6C2b4a4g4a4b4g4E2E2E2E2D6C2b4a4g8,8.";
    parseTune(notes, beatLength, false);
  }
}

void setup() {
  pinMode(speakerPin, OUTPUT);
  pinMode(buttonPin, INPUT);
  pinMode(led1, OUTPUT);
  pinMode(led2, OUTPUT);
  pinMode(led3, OUTPUT);
  pinMode(led4, OUTPUT);
}

void loop() {
  /* Start off silent, with the user able to select 1 of 4 tunes by turning the potentiometer.
  Feedback is given by one of the 4 LEDs lighting up, representing 1 of the 4 tunes.
  Press the microswitch to start playing the selected tune.
  Press the microswitch again to stop the tune, or wait for it to get to the end, at which point
  it will return to the "menu" interface. */
  int val = analogRead(potPin);
  if (val < 388) {
    songChoice = 1;
    digitalWrite(led1, HIGH);
    digitalWrite(led2, LOW);
    digitalWrite(led3, LOW);
    digitalWrite(led4, LOW);
  } else if (val < 512) {
    songChoice = 2;
    digitalWrite(led1, LOW);
    digitalWrite(led2, HIGH);
    digitalWrite(led3, LOW);
    digitalWrite(led4, LOW);
  } else if (val < 645) {
    songChoice = 3;
    digitalWrite(led1, LOW);
    digitalWrite(led2, LOW);
    digitalWrite(led3, HIGH);
    digitalWrite(led4, LOW);
  } else {
    songChoice = 4;
    digitalWrite(led1, LOW);
    digitalWrite(led2, LOW);
    digitalWrite(led3, LOW);
    digitalWrite(led4, HIGH);
  }
  
  updateSwitchState();
  if (switchState == HIGH) {
    playTune(songChoice);
  }
}
