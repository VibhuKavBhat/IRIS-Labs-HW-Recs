# IRIS Labs Hardware Recruitments - 2026

Name: Vibhu Kav Bhat  
Roll No: 241EC261  

## Submission :

### Abstract:

Yeah got stuck in debug hell without enough time. Hopefully OpenLane PD is better. 

I'll just write whatever I learnt on the go though. 

### Questions:  
Part A) Allowing multiple bits to change at the same time can cause issues because of lack of syncronization between the bits due to metastability. Converting to gray code and then implementing the 2-FF synchronizer is a much better option. Worst case, ur just slow and not incorrect. 

Once we've converted to graycode, we could use a couple of methods to try to fix metastability. One being the handshake method, the other being an async fifo. 


Part B) I actually started off pretty decently w this. Decided to go with a line buffer accelerator because of the specifications mentioned (embedded application, only 1024 pixels). The systolic array seemed too high performance for what was necessary and the serial folded architecture wouldnt work because there wasnt that big a difference between the frequencies of the sensor device and the processing device. 

Also had to implement an async fifo because of the two different clock frequencies. The RTL was mainly creating 2 line buffer registers, dividing the 1024 pixels into columns and rows, and multiplying and accumulating with the kernel. I got stuck in debugging when I tried to view my output in python and the padding (or lack thereof) screwed it over (I think). Might have been due to synchronization issues too, didnt get enough of time to really sit and deep dive. 

Part C) Didn't work on this, but have an idea on what the terms are due to TOPS







