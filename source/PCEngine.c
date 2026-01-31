#include <nds.h>

#include "PCEngine.h"
#include "Main.h"
#include "Gui.h"
#include "Cart.h"
#include "Gfx.h"
#include "Sound.h"
#include "ARMH6280/H6280.h"
#include "VDC.h"
#include "VCE.h"
#include "PCEPSG/pcepsg.h"

int packState(void *statePtr) {
	int size = 0;
	memcpy(statePtr+size, pceSRAM, sizeof(pceSRAM));
	size += sizeof(pceSRAM);
	memcpy(statePtr+size, pceRAM, sizeof(pceRAM));
	size += sizeof(pceRAM);
	memcpy(statePtr+size, pceVRAM, sizeof(pceVRAM));
	size += sizeof(pceVRAM);
	size += h6280SaveState(statePtr+size, &h6280OpTable);
	size += vdcSaveState(statePtr+size, &vdcState);
	size += vceSaveState(statePtr+size, &vceState);
	size += pcePSGSaveState(statePtr+size, &PSG_0);
	return size;
}

void unpackState(const void *statePtr) {
	int size = 0;
	memcpy(pceSRAM, statePtr+size, sizeof(pceSRAM));
	size += sizeof(pceSRAM);
	memcpy(pceRAM, statePtr+size, sizeof(pceRAM));
	size += sizeof(pceRAM);
	memcpy(pceVRAM, statePtr+size, sizeof(pceVRAM));
	size += sizeof(pceVRAM);
	size += h6280LoadState(&h6280OpTable, statePtr+size);
	size += vdcLoadState(&vdcState, statePtr+size);
	size += vceLoadState(&vceState, statePtr+size);
	size += pcePSGLoadState(&PSG_0, statePtr+size);
}

int getStateSize() {
	int size = 0;
	size += sizeof(pceRAM);
	size += sizeof(pceSRAM);
	size += sizeof(pceVRAM);
	size += h6280GetStateSize();
	size += vdcGetStateSize();
	size += vceGetStateSize();
	size += pcePSGGetStateSize();
	return size;
}
