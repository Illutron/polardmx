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
