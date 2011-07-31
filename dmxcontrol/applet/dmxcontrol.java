import processing.core.*; 
import processing.xml.*; 

import ddf.minim.analysis.*; 
import ddf.minim.*; 
import processing.serial.*; 
import processing.opengl.*; 

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

  // Import Serial library to talk to Arduino 
 //  Import OpenGL to draw a gradient window

Serial myPort; 

int[] lampGroups = {1, 130};

// Send new DMX channel value to Arduino
public void setDmxChannel(int channel, int value) {
  // Convert the parameters into a message of the form: 123c45w where 123 is the channel and 45 is the value
  myPort.write( str(channel) + "c" + str(value) + "w" );
}

public void setColor(int r, int g, int b, int lampGroup) {
  int rgb[] = {r, g, b};
  for (int i = 0; i < 3; i++) {
    setDmxChannel(lampGroups[lampGroup] + i, rgb[i]);
  }
}

// Draw gradient window
public void drawGradient() {
  // Draw a colour gradient
  beginShape(QUADS);
  fill(0,0,255); vertex(0,0); // Top left BLUE
  fill(255,0,0); vertex(width,0); // Top right RED
  fill(255,255,0); vertex(width,height); // Bottom right RED + GREEN
  fill(0,255,255); vertex(0,height); // Bottom left BLUE + GREEN
  endShape(); 
}  

public void setup() {
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

public void draw() {
  
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
  
  int w = PApplet.parseInt(fft.specSize()/8);
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // draw a rectangle for each average, multiply the value by 5 so we can see it better
    
    rect(i*w, height, i*w + w, height - fft.getAvg(i)*4);
    
  }
  
  setColor(PApplet.parseInt(fft.getAvg(0)*4), 0, 0, 0);
  setColor(0, PApplet.parseInt(fft.getAvg(7)*5), 0, 1);
  
}

public void stop()
{
  // always close Minim audio classes when you are done with them
  in.close();
  minim.stop();  
  super.stop();
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
  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#FFFFFF", "dmxcontrol" });
  }
}
