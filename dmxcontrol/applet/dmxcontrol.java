import processing.core.*; 
import processing.xml.*; 

import ddf.minim.analysis.*; 
import ddf.minim.*; 
import processing.serial.*; 
import processing.opengl.*; 
import controlP5.*; 

import java.applet.*; 
import java.awt.Dimension; 
import java.awt.Frame; 
import java.awt.event.MouseEvent; 
import java.awt.event.KeyEvent; 
import java.awt.event.FocusEvent; 
import java.awt.Image; 
import java.io.*; 
import java.net.*; 
import java.text.*; 
import java.util.*; 
import java.util.zip.*; 
import java.util.regex.*; 

public class dmxcontrol extends PApplet {

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




Minim minim;
AudioInput in;
FFT fft;

int[] peakColor = new int[3];
int[] normalColor = new int[3];

  // Import Serial library to talk to Arduino 
 //  Import OpenGL to draw a gradient window

Serial myPort; 

int group_num = 3; // number of lamp groups
int[] lampGroups = {1, 130, 20}; // DMX addresses for lamp groups
int[] groupsMin = {20,800,5000}; // minimum threshold for lamp groups in Hz
int[] groupsMax = {50,2500,8000}; // maximum threshold for lamp groups in Hz

float[] avgs = new float[group_num];
float[] avgsMax = new float[group_num];
float[] avgsMin = new float[group_num];
float[] lightValues = new float[group_num];

float slew = 94.999f;
boolean slewSwitch = true;

boolean autoCalibrate = true;

public void resetCalibration() {
  for(int i = 0; i < group_num; i++)
  {
    avgsMax[i] = 0.5f;
    avgsMin[i] = 0.1f;
    
    try {
      updateThresholdInputs(i);
    } catch (Exception e) {
    }
  }
}

public void setup() {
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
  
  for (int g = 0; g < lampGroups.length; g++) {
    setDmxChannel(lampGroups[g] + 3, 255);
  }
  
}

public void draw() {
  
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
 
   
  w = PApplet.parseInt(width/60);
  for(int i = 0; i < 60; i++)
  {
    fill(40);
    stroke(80);
    rect(i*w+2, height, i*w + w -2, height - 30 - fft.getAvg(i));
    
  }
  
  w = PApplet.parseInt((width/2)/group_num);
  
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
  
  w = PApplet.parseInt((width/2)/group_num);
  

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

public void stop()
{
  // always close Minim audio classes when you are done with them
  in.close();
  minim.stop();  
  super.stop();
}

public boolean overRect(int x, int y, int width, int height) {
  if (mouseX >= x && mouseX <= x+width && 
      mouseY >= y && mouseY <= y+height) {
    return true;
  } else {
    return false;
  }
}

boolean uiThresholdForceUpdate = false;

public void updateThresholdInputs(int i) {
      
      uiThresholdForceUpdate = true;
      
      float m = sqrt(groupsMax[i] - groupsMin[i])/8;
      thresholdRanges[i].setLowValue(avgsMin[i]*m);
      thresholdRanges[i].setHighValue(avgsMax[i]*m);
}
// This class is a very simple implementation of AudioListener. By implementing this interface, 
// you can add instances of this class to any class in Minim that implements Recordable and receive
// buffers of samples in a callback fashion. In other words, every time that a Recordable object has 
// a new buffer of samples, it will send a copy to all of its AudioListeners. You can add an instance of 
// an AudioListener to a Recordable by using the addListener method of the Recordable. If you want to 
// remove a listener that you previously added, you call the removeListener method of Recordable, passing 
// the listener you want to remove.
//
// Although possible, it is not advised that you add the same listener to more than one Recordable. 
// Your listener will be called any time any of the Recordables you've added it have new samples. This 
// means that the stream of samples the listener sees will likely be interleaved buffers of samples from 
// all of the Recordables it is listening to, which is probably not what you want.
//
// You'll notice that the three methods of this class are synchronized. This is because the samples methods 
// will be called from a different thread than the one instances of this class will be created in. That thread 
// might try to send samples to an instance of this class while the instance is in the middle of drawing the 
// waveform, which would result in a waveform made up of samples from two different buffers. Synchronizing 
// all the methods means that while the main thread of execution is inside draw, the thread that calls 
// samples will block until draw is complete. Likewise, a call to draw will block if the sample thread is inside 
// one of the samples methods. Hope that's not too confusing!

class WaveformRenderer implements AudioListener
{
  private float[] left;
  private float[] right;
  
  WaveformRenderer()
  {
    left = null; 
    right = null;
  }
  
  public synchronized void samples(float[] samp)
  {
    left = samp;
  }
  
  public synchronized void samples(float[] sampL, float[] sampR)
  {
    left = sampL;
    right = sampR;
  }
  
  public synchronized void draw()
  {
    // we've got a stereo signal if right or left are not null
    if ( left != null && right != null )
    {
      noFill();
      stroke(255);
      beginShape();
      for ( int i = 0; i < left.length; i++ )
      {
        vertex(i, height/4 + left[i]*50);
      }
      endShape();
      beginShape();
      for ( int i = 0; i < right.length; i++ )
      {
        vertex(i, 3*(height/4) + right[i]*50);
      }
      endShape();
    }
    else if ( left != null )
    {
      noFill();
      stroke(255);
      beginShape();
      for ( int i = 0; i < left.length; i++ )
      {
        vertex(i, height/2 + left[i]*50);
      }
      endShape();
    }
  }
}

ControlP5 controlP5;

Range[] thresholdRanges = new Range[group_num];

ColorPicker peakCP;
ColorPicker normalCP;

public void setupControlInterface() {
  controlP5 = new ControlP5(this);
  
  ControlGroup calibration = controlP5.addGroup("Calibration", 10, 20);
  controlP5.begin(0,10);
  
  Toggle autoCal = controlP5.addToggle("autoCalibrate");
  autoCal.setGroup(calibration);
  autoCal.setLabel("Auto");
  
  Button resetBtn = controlP5.addButton("resetCalibration");
  resetBtn.setGroup(calibration);
  resetBtn.setLabel("Reset");
  
  Toggle slewToggle = controlP5.addToggle("slewSwitch");
  slewToggle.setGroup(calibration);
  slewToggle.setLabel("Slew");
  
  Slider slewSlider = controlP5.addSlider("slew",60.0f,99.99f,slew,0,50,200,10);
  slewSlider.setGroup(calibration);
  
  controlP5.end();
  
  ControlGroup[] lampControlGroups = new ControlGroup[group_num];
  
  for(int i = 0; i < group_num; i++)
  {
     lampControlGroups[i] = controlP5.addGroup("Lamp group " + i, (width/(group_num+1))*(i+1), 20);
     controlP5.begin(0,10);
     
     Textfield lowInputField = controlP5.addTextfield("low " + i, 0,10,200,20);
     lowInputField.setGroup(lampControlGroups[i]);
     lowInputField.setId(i);
     
     Textfield highInputField = controlP5.addTextfield("high " + i, 0,50,200,20);
     highInputField.setGroup(lampControlGroups[i]);
     highInputField.setId(i);
     
     float m = sqrt(groupsMax[i] - groupsMin[i])/8;
     
     thresholdRanges[i] = controlP5.addRange("thresholds " + i, 0, 400, avgsMin[i]*m, avgsMax[i]*m, 0,90,200,20);
     thresholdRanges[i].setGroup(lampControlGroups[i]);
     thresholdRanges[i].setId(i);
     
     
     controlP5.end();
  }
  
  
  ControlGroup peakOut = controlP5.addGroup("Peak Output", 10, 110);
  controlP5.begin(0,10);
  
  peakCP = controlP5.addColorPicker("peak color",0,10,255,20);
  peakCP.setColorValue(color(0,0,255,255));
  peakCP.setGroup(peakOut);
  
  controlP5.end();
  
  ControlGroup normalOut = controlP5.addGroup("Normal Output", 10, 200);
  controlP5.begin(0,10);
  
  normalCP = controlP5.addColorPicker("normal color",0,10,255,20);
  normalCP.setColorValue(color(255,0,0,200));
  normalCP.setGroup(normalOut);
  
  controlP5.end();
  
}

public void controlEvent(ControlEvent theEvent) {
  int newVal;
  
  int id = theEvent.controller().id();
  
  if(theEvent.controller().name().equals("low " + id)) {
    
    try {
      
      newVal = Integer.parseInt(theEvent.controller().stringValue());
      groupsMin[id] =  newVal;
      
      if (newVal >= groupsMax[id]) {
        groupsMax[id] = newVal + 1;
      }
      
      
    } catch(Exception e) {
      e.printStackTrace();
    }
    
  } else if (theEvent.controller().name().equals("high " + id)) {
    
    try {
   
      newVal = Integer.parseInt(theEvent.controller().stringValue());
      groupsMax[id] = newVal;
      
      if (newVal <= groupsMin[id]) {
        groupsMin[id] = newVal - 1;
      }
      
    } catch(Exception e) {
      e.printStackTrace();
    }
    
  } else if (theEvent.controller().name().equals("thresholds " + id)) {
     
    if (!uiThresholdForceUpdate) {
      
       float m = sqrt(groupsMax[id] - groupsMin[id])/8;
       avgsMin[id] = theEvent.controller().arrayValue()[0]/m;
       avgsMax[id] = theEvent.controller().arrayValue()[1]/m;
    }
    
    uiThresholdForceUpdate = false;
  }
  
}
// Send new DMX channel value to Arduino
public void setDmxChannel(int channel, int value) {
  // Convert the parameters into a message of the form: 123c45w where 123 is the channel and 45 is the value
  myPort.write( str(channel) + "c" + str(value) + "w" );
}

public void setColor(float r, float g, float b, int lampGroup, float intensity) {
  float rgb[] = {r, g, b};
  for (int i = 0; i < 3; i++) {
    rgb[i] = rgb[i]/255*intensity;
    setDmxChannel(lampGroups[lampGroup] + i, PApplet.parseInt(rgb[i]));
  }
}
  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#FFFFFF", "dmxcontrol" });
  }
}
