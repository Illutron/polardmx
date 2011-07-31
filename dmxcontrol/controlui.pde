import controlP5.*;
ControlP5 controlP5;

Range[] thresholdRanges = new Range[group_num];

void setupControlInterface() {
  controlP5 = new ControlP5(this);
  
  ControlGroup calibration = controlP5.addGroup("Calibration", 10, 20);
  controlP5.begin(0,10);
  
  Toggle autoCal = controlP5.addToggle("autoCalibrate");
  autoCal.setGroup(calibration);
  autoCal.setLabel("Auto");
  
  Button resetBtn = controlP5.addButton("resetCalibration");
  resetBtn.setGroup(calibration);
  resetBtn.setLabel("Reset");
  
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
  
}

void controlEvent(ControlEvent theEvent) {
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
