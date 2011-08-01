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

int[] peakColor = new int[3];
int[] normalColor = new int[3];

import processing.serial.*;  // Import Serial library to talk to Arduino 
import processing.opengl.*; //  Import OpenGL to draw a gradient window

Serial myPort; 

int group_num = 3; // number of lamp groups
int[] lampGroups = {1, 130, 20}; // DMX addresses for lamp groups
int[] groupsMin = {20,800,5000}; // minimum threshold for lamp groups in Hz
int[] groupsMax = {50,2500,8000}; // maximum threshold for lamp groups in Hz

float[] avgs = new float[group_num];
float[] avgsMax = new float[group_num];
float[] avgsMin = new float[group_num];
float[] lightValues = new float[group_num];

float slew = 94.999;
boolean slewSwitch = true;

boolean autoCalibrate = true;

public void resetCalibration() {
  for(int i = 0; i < group_num; i++)
  {
    avgsMax[i] = 0.5;
    avgsMin[i] = 0.1;
    
    try {
      updateThresholdInputs(i);
    } catch (Exception e) {
    }
  }
}

void setup() {
  println(Serial.list()); // shows available serial ports on the system

  size(1275,750,OPENGL);  // Create a window
  frameRate(30);
  
  resetCalibration();
  setupControlInterface();
  
  // Select the appropriate port as required.
  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 9600);
  
  minim = new Minim(this);
  minim.debugOn();
  
  // get a line in from Minim, default bit depth is 16
  in = minim.getLineIn(Minim.STEREO, 2048);
  fft = new FFT(in.bufferSize(), in.sampleRate());  
  fft.logAverages(20, 8);
  rectMode(CORNERS);
  
  // set dim channel to full on all lamp groups
  
  setDmxChannel(4, 255);
  
  for (int g = 0; g < lampGroups.length; g++) {
    setDmxChannel(lampGroups[g] + 3, 155);
  }
  
}

void draw() {
  
  int w;
  
  background(0);
  stroke(255);

  // perform a forward FFT on the samples in jingle's mix buffer
  // note that if jingle were a MONO file, this would be the same as using jingle.left or jingle.right
  fft.forward(in.mix);
  
  
  // draw the waveforms
  for(int i = 0; i < in.bufferSize() - 1; i++)
  {
    stroke(30, 30, 250);
    line(i, height/2 - 50 + in.left.get(i)*50, i+1, height/2 - 50 + in.left.get(i+1)*50);
    stroke(30, 30, 250);
    line(i, height/2 + 50 + in.right.get(i)*50, i+1, height/2 + 50 + in.right.get(i+1)*50);
  }
  
  for(int i = 0; i < group_num; i++)
  {
    avgs[i] = fft.calcAvg(groupsMin[i], groupsMax[i]);
  }
 
   
  w = int(width/60);
  for(int i = 0; i < 60; i++)
  {
    fill(40);
    stroke(80);
    rect(i*w+2, height, i*w + w -2, height - 30 - fft.getAvg(i));
    
  }
  
  w = int((width/2)/group_num);
  
  fill(0);
  noStroke();
  rect(0, height, width, height-30); 
  
  for(int i = 0; i < group_num; i++)
  {
    
    float m = sqrt(groupsMax[i] - groupsMin[i])/4;
    
    if (autoCalibrate) {
      updateThresholdInputs(i);
    }
    
    fill(100, 100, 220, 200);
    noStroke();
    rect(i*w + 2, height-30, i*w + w - 2, height - 30 - avgs[i]*m);
    
    
    stroke(0, 255, 255);
    float mx = height - 30 - avgsMax[i]*m;
    float mn = height - 30 - avgsMin[i]*m;
    line(i*w + 2, mx, i*w + w - 2, mx);  
    
    stroke(255, 255, 0);
    line(i*w + 2, mn, i*w + w - 2, mn);
    
    fill(255);
    text(groupsMin[i] + "Hz - " + groupsMax[i] + "Hz", (i*w) + 10, height-10);
  }
  
  for (int i = 0; i < avgs.length; i++) {
          
     if (avgs[i] > avgsMax[i]) {
        if (autoCalibrate) { 
          avgsMax[i] = avgs[i];
        } else {
          avgs[i] = avgsMax[i];
        }
     } else if (avgs[i] < avgsMin[i]) {
        if (autoCalibrate) { 
          avgsMin[i] = avgs[i];
        } else {
          avgs[i] = avgsMin[i];
        }
     }
     
     
     float mapped = map(avgs[i], avgsMin[i], avgsMax[i], 0, 255);
     
     if (mapped > lightValues[i]) {
       lightValues[i] = mapped;
     }
  }
  
  w = int((width/2)/group_num);
  

  fill(150, 20, 20, 70);
  
  noStroke();
  rect(width/2, height-(255*2) + ((255*2)/100*10) - 30, width, height-(255*2)-30);
  
  for(int i = 0; i < group_num; i++)
  {
    noStroke();
    fill(255, 255, 255, lightValues[i]);
    rect(i*w + width/2 + 2, height - 30, i*w + w + width/2 - 2, height - 30 - (lightValues[i]*2));
    
  }
  
  for(int i = 0; i < group_num; i++)
  {
    int cc = 1;
    float intensity = 1;
    
     if (lightValues[i]/255*100 > 90) {
       
       intensity = alpha(peakCP.getColorValue()) / 255 * lightValues[i];
       cc = peakCP.getColorValue();     
       
     } else if (lightValues[i]/255*100 < 1) {
       
     } else {
       
       intensity = alpha(normalCP.getColorValue()) / 255 * lightValues[i];
       cc = normalCP.getColorValue();
       
     }
     setColor(red(cc), green(cc), blue(cc), i, intensity);   
  }
  
  for(int i = 0; i < group_num; i++)
  {
    if (slewSwitch) {
      lightValues[i] = lightValues[i] * (slew/100);
    } else {
     lightValues[i] = 0; 
    }
  }
  
}

void stop()
{
  // always close Minim audio classes when you are done with them
  in.close();
  minim.stop();  
  super.stop();
}

boolean overRect(int x, int y, int width, int height) {
  if (mouseX >= x && mouseX <= x+width && 
      mouseY >= y && mouseY <= y+height) {
    return true;
  } else {
    return false;
  }
}

boolean uiThresholdForceUpdate = false;

void updateThresholdInputs(int i) {
      
      uiThresholdForceUpdate = true;
      
      float m = sqrt(groupsMax[i] - groupsMin[i])/8;
      thresholdRanges[i].setLowValue(avgsMin[i]*m);
      thresholdRanges[i].setHighValue(avgsMax[i]*m);
}
