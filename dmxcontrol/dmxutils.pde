// Send new DMX channel value to Arduino
void setDmxChannel(int channel, int value) {
  // Convert the parameters into a message of the form: 123c45w where 123 is the channel and 45 is the value
  myPort.write(str(channel) + "c" + str(value) + "w");
  //println("sendin: " + str(channel) + "c" + str(value) + "w");
}

void setColor(float r, float g, float b, int lampGroup, float intensity) {
  float rgb[] = {r, g, b};
  for (int i = 0; i < 3; i++) {
    rgb[i] = rgb[i]/255*intensity;
    setDmxChannel(lampGroups[lampGroup] + i, int(rgb[i]));
  }
  
  // different lamps have different dimmer functionality some need this dimmer channel others just needs lower values as colors as above
  // probably a bad idea to do both
  setDmxChannel(lampGroups[lampGroup] + 3, int(intensity));
  
}
