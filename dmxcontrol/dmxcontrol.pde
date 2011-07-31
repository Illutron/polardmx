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

float[] lastAvgs = new float[group_num];
float[] avgs = new float[group_num];
float[] avgsMax = new float[group_num];
float[] avgsMin = new float[group_num];
float[] lightValues = new float[group_num];

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

  size(1100,700,OPENGL);  // Create a window
  frameRate(30);
  smooth();
  
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
  fft.logAverages(20, 3);
  rectMode(CORNERS);
  
  // set dim channel to full on all lamp groups
  for (int g = 0; g < lampGroups.length; g++) {
    setDmxChannel(lampGroups[g] + 3, 189);
  }
  
}

void draw() {
  
  int w;
  
  background(0);
  stroke(255);

  // perform a forward FFT on the samples in jingle's mix buffer
  // note that if jingle were a MONO file, this would be the same as using jingle.left or jingle.right
  fft.forward(in.mix);
  
  
  for(int i = 0; i < group_num; i++)
  {
    avgs[i] = fft.calcAvg(groupsMin[i], groupsMax[i]);
  }
 
   
  w = int(width/fft.avgSize());
  for(int i = 0; i < fft.avgSize(); i++)
  {
    fill(55);
    noStroke();
    rect(i*w, height, i*w + w, height - fft.getAvg(i)*2);
    
  }
  
  
  w = int((width/2)/group_num);
  for(int i = 0; i < group_num; i++)
  {
    fill(220, 220, 10);
    noStroke();
    
    float m = sqrt(groupsMax[i] - groupsMin[i])/4;
    
    if (autoCalibrate) {
      updateThresholdInputs(i);
    }
    
    rect(i*w, height-100, i*w + w, height - 100 - avgs[i]*m);
    
    stroke(10, 10, 240);
    float mx = height - 100 - avgsMax[i]*m;
    float mn = height - 100 - avgsMin[i]*m;
    line(i*w, mx, i*w + w, mx);
    line(i*w, mn, i*w + w, mn);
    
    fill(255);
    text(groupsMin[i] + "Hz - " + groupsMax[i] + "Hz", (i*w) + 10, height-180);
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
      
     lightValues[i] = map(avgs[i], avgsMin[i], avgsMax[i], 0, 255);     
     lastAvgs[i] = avgs[i];
  }
  
  w = int((width/2)/group_num);
  for(int i = 0; i < group_num; i++)
  {
    noStroke();
    fill(255);
    rect(i*w + width/2, height-100, i*w + w + width/2, height - 100 - lightValues[i]);
  } 
  
  //normalColor = normalCP.getColorValue();
  
  
  
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
  
  
  //for (int i = 0; i < lightValues.length; i++) {
  //    lightValues[i] = lightValues[i];
  //} 
  
  // draw the waveforms
  
  for(int i = 0; i < in.bufferSize() - 1; i++)
  {
    stroke(255, 0, 0);
    line(i, 50 + in.left.get(i)*50, i+1, 50 + in.left.get(i+1)*50);
    stroke(0, 255, 0);
    line(i, 150 + in.right.get(i)*50, i+1, 150 + in.right.get(i+1)*50);
  } 
}

void updateMouse(int x, int y)
{
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
