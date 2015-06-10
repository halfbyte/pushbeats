var

var encoders = [0,0,0,0,0,0,0,0];
var playState = false;

function onMIDIMessage(event) {
  console.log(event.data);
  var data = event.data;

  if(data[0] == 176) { // cc
    if (data[1] >= 71 && data[1] <= 78) { // encoder
      var encoder = data[1] - 71;
      if (data[2] < 64) {
        encoders[encoder] += data[2];
        if (encoders[encoder] > 127) encoders[encoder] = 127;
      } else {
        encoders[encoder] -= 128 - data[2];
        if (encoders[encoder] < 0) encoders[encoder] = 0;
      }
      updateEncoderDisplay();
    }
  }
  if (data[1] == 85 && data[2] == 127) {
    playState = !playState;
    console.log("PS:", playState);
    updatePlayState();
  }

}

function buttonValue(color, intensity, blink, on) {
  return color * 6 + intensity * 3 + blink + on;
}

function updatePlayState() {
  var bV = 0;
  if (playState) {
    bV = buttonValue(1, 1, 2, 1);
  } else {
    bV = buttonValue(0, 0, 0, 1);
  }
  console.log(bV);
  userOutput.send([176, 40, bV]);
}

function updateEncoderDisplay() {
  console.log(encoders);
  encoders.forEach(function (encoderValue, i) {
    liveOutput.send(barSysEx(0,i, encoderValue, 127));
    liveOutput.send(slotValueSysEx(1,i, encoderValue));
  });
}

var liveOutput = null;
var userOutput = null;

function strToBytes(instring) {
  var bytes = [];
  var i,l;
  for(i=0,l=instring.length;i<l;i++) {
    var charcode = instring.charCodeAt(i);
    if (charcode < 127) {
      bytes.push(charcode);
    }
  }
  return bytes;
}

function displaySysEx(line, offset, strBytes) {
  var maxLen = 68 - offset;

  if(strBytes.length > maxLen) {
    strBytes = strBytes.slice(0,maxLen);
  }

  var message = [240, 71, 127, 21, line + 24, 0, strBytes.length + 1, offset];
  message = message.concat(strBytes);
  message.push(247);
  return message;
}

function clearLineSysEx(line) {
  return [240, 71, 127, 21, line + 28, 0, 0, 247];
}

function barSysEx(line, slot, val, max) {
  var offset = SLOTS[slot];
  var chars = [];
  var rel = Math.round((val / max) * 16);
  var full = Math.floor(rel / 2);
  var half = rel % 2;
  var i,l;
  for(i=0;i<full;i++) {
    chars.push(5);
  }
  if (half == 1) {
    chars.push(3);
  }
  for(i=0,l=8-chars.length;i<l;i++) {
    chars.push("-".charCodeAt(0));
  }

  return displaySysEx(0,offset, chars);
}

function slotValueSysEx(line, slot, val) {
  var offset = SLOTS[slot];
  var str = val.toString(10)
  var str = "        ".substr(0, 8 - str.length) + str;
  return displaySysEx(line, offset, strToBytes(str));


}

function setPad(x,y,no) {
    pad = 36 + ((7 - y) * 8) + x;
    console.log(pad, no);
    return [144,pad, no];

}

function initMIDI(info) {
  info.inputs.forEach(function(input, id) {
    input.onmidimessage = onMIDIMessage;
  });
  info.outputs.forEach(function(output, id) {
    if(output.name == 'Ableton Push Live Port') {
      liveOutput = output;
      output.send(clearLineSysEx(0));
      output.send(clearLineSysEx(1));
      output.send(clearLineSysEx(2));
      output.send(clearLineSysEx(3));
      updateEncoderDisplay();




    }
    if (output.name == 'Ableton Push User Port') {
      userOutput = output;
      var i,l;
      for(i=0,l=64;i<l;i++) {
        userOutput.send([128,36 + i, 0]);
      }
      userOutput.send(setPad(0,7,10));
      userOutput.send(setPad(1,7,11));
      userOutput.send(setPad(2,7,12));
      userOutput.send(setPad(3,7,13));

      updatePlayState();
    }
  })
}

// 240 71 127 21 {line} 0 69 0 {ASCII char1} {ASCII char2} … {ASCII char68} 247

function failMIDI(error) {
  console.log("ERR", error)
}
