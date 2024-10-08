#ifndef GUI_HEADER
#define GUI_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u8 gGammaValue;

void setupGUI(void);
void enterGUI(void);
void exitGUI(void);
void nullUINormal(int key);
void nullUIDebug(int key);

void uiNullNormal(void);
void uiFile(void);
void uiSettings(void);
void uiAbout(void);
void uiOptions(void);
void uiController(void);
void uiDisplay(void);
void uiMachine(void);
void uiBios(void);

void setupKeyboard(void);

void ejectGame(void);
void powerOnOff(void);
void resetGame(void);

void controllerSet(void);
void swapABSet(void);
void joypadButtonSet(void);
void rffSet(void);
void multiTapSet(void);

void scalingSet(void);
void gammaSet(void);
void colorSet(void);
void ycbcrSet(void);
void bgrLayerSet(void);
void sprLayerSet(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // GUI_HEADER
