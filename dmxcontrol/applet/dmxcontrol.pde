/*
  Johan Bichel Lindegaard
  http://johan.cc
  2011

  Lightmaxx par 64
  Channels:
  1: Red [ 0 - 255]
  2: Green [ 0 - 255 ]
  3: Blue [ 0 - 255 ]
  4: Dimmer [ 000 - 189 dimmer ] [ 190 - 250 Flash]

*/

import ddf.minim.analysis.*;
import ddf.minim.*;

Minim minim;
AudioInput in;
FFT fft;

import processing.serial.*;  // Import Serial library to talk to Arduino 
import processing.opengl.*; //  Import OpenGL to draw a gradient window

Serial myPort; 

int[] lampGroups = {1, 130};

// Send new DMX channel value to Arduino
void setDmxChannel(int channel, int value) {
  // Convert the parameters into a message of the form: 123c45w where 123 is the channel and 45 is the value
  myPort.write( str(channel) + "c" + str(value) + "w" );
}

void setColor(int r, int g, int b, int lampGroup) {
  int rgb[] = {r, g, b};
  for (int i = 0; i < 3; i++) {
    setDmxChannel(lampGroups[lampGroup] + i, rgb[i]);
  }
}

// Draw gradient window
void drawGradient() {
  // Draw a colour gradient
  beginShape(QUADS);
  fill(0,0,255); vertex(0,0); // Top left BLUE
  fill(255,0,0); vertex(width,0); // Top right RED
  fill(255,255,0); vertex(width,height); // Bottom right RED + GREEN
  fill(0,255,255); vertex(0,height); // Bottom left BLUE + GREEN
  endShape(); 
}  

void setup() {
  println(Serial.list()); // shows available serial ports on the system

  size(800,600,OPENGL);  // Create a window
  
  // Select the appropriate port as required.
  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 9600);
  
  minim = new Minim(this);
  minim.debugOn();
  
  // get a line in from Minim, default bit depth is 16
  in = minim.getLineIn(Minim.STEREO, 2048);
  fft = new FFT(in.bufferSize(), in.sampleRate());  
  fft.linAverages(8);
  rectMode(CORNERS);
  
  // set dim channel to full on all lamp groups
  for (int g = 0; g < lampGroups.length; g++) {
    setDmxChannel(lampGroups[g] + 3, 189);
  }
  
  drawGradient();
  
}

void draw() {
  
  //for (int g = 0; g < lampGroups.length; g++) {
  //  setColor(in.left.get(i), 0, 0, g);
  //}
  
  background(0);
  stroke(255);
  
  // draw the waveforms
  for(int i = 0; i < in.bufferSize() - 1; i++)
  {
    //setColor(int(in.left.get(i)), 0, 0, 0);
    //setColor(int(in.right.get(i)), 0, 0, 1);
    line(i, 50 + in.left.get(i)*50, i+1, 50 + in.left.get(i+1)*50);
    //println(in.left.get(i));
    line(i, 150 + in.right.get(i)*50, i+1, 150 + in.right.get(i+1)*50);
  }
  
  fill(255);
  // perform a forward FFT on the samples in jingle's mix buffer
  // note that if jingle were a MONO file, this would be the same as using jingle.left or jingle.right
  fft.forward(in.mix);
  
  for(int i = 0; i < fft.specSize(); i++)
  {
    // draw the line for frequency band i, scaling it by 4 so we can see it a bit better
    line(i, height, i, height - fft.getBand(i)*5);
  }
  
  int w = int(fft.specSize()/8);
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // draw a rectangle for each average, multiply the value by 5 so we can see it better
    
    rect(i*w, height, i*w + w, height - fft.getAvg(i)*4);
    
  }
  
  setColor(int(fft.getAvg(0)*4), 0, 0, 0);
  setColor(0, int(fft.getAvg(7)*5), 0, 1);
  
}

void stop()
{
  // always close Minim audio classes when you are done with them
  in.close();
  minim.stop();  
  super.stop();
}
