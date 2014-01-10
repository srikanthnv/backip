configuration CC2420StatModC {
	provides {
		interface CC2420Stat;
	}
} implementation {
	components CC2420StatModP;
	CC2420Stat = CC2420StatModP;
}
