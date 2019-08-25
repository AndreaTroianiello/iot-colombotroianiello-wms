print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;

from TOSSIM import *;

t = Tossim([]);
sf = SerialForwarder(9001);
throttle = Throttle(t,10);
sf_process = True;
sf_throttle = True;


topofile="topology_2.txt";
modelfile="meyer-heavy-2.txt";


print "Initializing mac....";
mac = t.mac();
print "Initializing radio channels....";
radio=t.radio();
print "    using topology file:",topofile;
print "    using noise file:",modelfile;
print "Initializing simulator....";
t.init();


simulation_outfile = "simulation2.txt";
print "Saving sensors simulation output to:", simulation_outfile;
simulation_out = open(simulation_outfile, "w");

out = open(simulation_outfile, "w");
#out = sys.stdout;

#Add debug channel
print "Activate debug message on channel init"
t.addChannel("init",out);
print "Activate debug message on channel boot"
t.addChannel("boot",out);
print "Activate debug message on channel bin"
t.addChannel("bin",out);
print "Activate debug message on channel truck"
t.addChannel("truck",out);
print "Activate debug message on channel radio"
t.addChannel("radio",out);

for i in range(0,8):
    print "Creating node",i,"...";
    n0 = t.getNode(i);
    t0 = i*t.ticksPerSecond();
    n0.bootAtTime(t0);
    print ">>>Will boot at time", t0/t.ticksPerSecond(), "[sec]";


print "Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#creation of channel model
print "Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print "Reading noise model data file:", modelfile;
print "Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(0,8):
            t.getNode(i).addNoiseTraceReading(val)
print "Done!";

for i in range(0,8):
    print ">>>Creating noise model for node:",i;
    t.getNode(i).createNoiseModel()

print "Start simulation with TOSSIM! \n\n\n";

if ( sf_process == True ):
	sf.process();
if ( sf_throttle == True ):
	throttle.initialize();

for i in range(0,23000):
	t.runNextEvent();
	if ( sf_throttle == True ):
		throttle.checkThrottle();
 	if ( sf_process == True ):
		sf.process();

print "Simulation finished!";

throttle.printStatistics()
