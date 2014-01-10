if [ -f "Msp430ClockC.nc" ]
then
mv Msp430ClockC.nc _Msp430ClockC.nc
mv Msp430ClockP.nc _Msp430ClockP.nc
mv TelosSerialP.nc _TelosSerialP.nc
cp Msp430DcoSpec_old.h $TOSROOT/tos/chips/msp430/timer/Msp430DcoSpec.h
else
mv _Msp430ClockC.nc Msp430ClockC.nc
mv _Msp430ClockP.nc Msp430ClockP.nc
mv _TelosSerialP.nc TelosSerialP.nc
cp Msp430DcoSpec_new.h $TOSROOT/tos/chips/msp430/timer/Msp430DcoSpec.h
fi
