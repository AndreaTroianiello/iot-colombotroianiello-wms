Project: Waste Management System
Matteo Colombo     - 883114 - 10459278
Andrea Troianiello - 898113 - 10455250

In this directory you can find:
    - report.pdf  -> The 3 page report about the project
    - toplogy_2.png -> An image reprsenting the topology that we created.
    - simulation_output -> the output printed with debug
    - serial_output -> the output printed on the terminal with the serial device
    - meyer-heavy -> the noise trace used for the simulation(s)
    - source -> the folder with the source code

How to run:

1. Navigate to source

2. make micaz sim-sf

3. java net.tinyos.sf.SerialForwarder -comm sf@localhost:9001&

4. java TestSerial -comm sf@localhost:9002

5. python RunSimulationScript.py

The simulation takes 5-6 minutes because of the serial port simulation.


In the source folder, we edited/created the following files:
    - BinSensorAppC.nc
    - BinSensorC.nc
    - TestSerial.java
    - WMSMoteAppC.nc
    - WMSMoteC.nc
    - wmsMsg.h
    - RunSimulationScript.py
    - meyer-heavy-2.txt
    - topology_2.txt
